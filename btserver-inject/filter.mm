/*
 *  filter.mm
 *  btserver-inject
 *
 *  Created by msftguy on 9/11/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#include "filter.h"
#include "logging.h"

static int hciFd = -1; 

typedef enum {
	HCI_COMMAND = 1,
	HCI_EVENT = 4,
	ACL_PACKET = 2,	
};

#pragma pack(1)
typedef struct {
	char type;
	char command;
	unsigned char size;
} HCI_HEADER;


typedef struct {
	char type;
	short command;
	unsigned short size;
} ACL_HEADER;

typedef struct {
	size_t cbMatch;
	const unsigned char* matchPattern;
	unsigned char wildcardChar;
	size_t cbPatch;
	const unsigned char* patchBytes;
	size_t patchOffset;
} HCI_PATCH;

//const unsigned char mbt1k_lmpFeatures[] = {HCI_EVENT, 0x0B, 0x0B, 0x00, '*', '*', 0xFF, 0xFF, 0x8D, 0xF8, 0x1B, 0x18, 0x00, 0x80};
//
//const unsigned char garmin_lmp_features[] = {0xFF, 0xFF, 0x8F, 0xFE, 0x9B, 0xF9, 0x00, 0x80}; 
//
//HCI_PATCH mbt1k_lmpFeaturesPatch = {sizeof(mbt1k_lmpFeatures), mbt1k_lmpFeatures, '*'/*0x2A*/, sizeof(garmin_lmp_features), garmin_lmp_features, -1};
//
unsigned char mbt1k_lmpExtFeatures[] = {HCI_EVENT, 0x23, 0x0D, 0x00, '*', '*',  '*', '*',  '*', '*', '*', '*',  '*', '*', '*', '*'};

unsigned char garmin_lmp_extfeat[]	=  {01, 00,   0x00, 0x00, 0x00, 0x00,  0x00, 0x00, 0x00, 0x00};

HCI_PATCH mbt1k_lmpExtFeaturesPatch = {sizeof(mbt1k_lmpExtFeatures), mbt1k_lmpExtFeatures, '*'/*0x2A*/, sizeof(garmin_lmp_extfeat), garmin_lmp_extfeat, -1};

typedef struct {
	HCI_PATCH* patch;
	BOOL matchState;
} MATCH_STATE;

typedef struct {
	int cMatches;
	MATCH_STATE* matches;
} MATCHES;

static MATCH_STATE match_states[] = {/*{&mbt1k_lmpFeaturesPatch, NO}, */{&mbt1k_lmpExtFeaturesPatch, NO}};

static MATCHES s_matches = {sizeof(match_states) / sizeof(MATCH_STATE), match_states};

void apply_patch(MATCH_STATE* state, size_t bufOffset, char* buf, size_t cbBuf)
{
	log_progress("apply_patch: ENTER"); 

	size_t patchPos = state->patch->patchOffset;
	if (patchPos == -1)
		patchPos = state->patch->cbMatch - state->patch->cbPatch;
	assert (patchPos >= bufOffset);
	size_t patchPosInBuf = patchPos - bufOffset;
	assert (patchPosInBuf + state->patch->cbPatch <= cbBuf);
	memcpy(buf + patchPosInBuf, state->patch->patchBytes, state->patch->cbPatch);
	state->matchState = NO;
	log_progress("apply_patch: EXIT"); 
}

BOOL update_match(MATCH_STATE* state, size_t bufOffset, char* buf, size_t cbBuf, BOOL verboseMatch) 
{
	BOOL matchOk = YES;
	BOOL matchComplete = NO;
	for (size_t i = 0; (i < cbBuf) && (i < (state->patch->cbMatch - bufOffset)); ++i) {
		size_t matchIndex = i + bufOffset;
		assert (matchIndex < state->patch->cbMatch);
		unsigned char m = state->patch->matchPattern[matchIndex];

		unsigned char b = (unsigned)buf[i];
		if (verboseMatch) {
			log_progress("update_match/verbose: matchIndex=%u, m=%02X, b=%02X", 
						 matchIndex, m, b);
		}		matchOk = (m == state->patch->wildcardChar) || (m == b);
		if (!matchOk)
			break;
		matchComplete = matchIndex == (state->patch->cbMatch - 1);
		if (matchComplete)
			break;
	}
	if (matchOk) {
		log_progress("update_match: %u bytes (of %u) match so far!", cbBuf + bufOffset, state->patch->cbMatch); 
	}
	state->matchState = matchOk;
	if (matchComplete) {
		apply_patch(state, bufOffset, buf, cbBuf);
	}
	return matchComplete;
}

BOOL update_matches(size_t bufOffset, char* buf, size_t cbBuf)
{
	BOOL dirty = NO;
	for (int i = 0; i < s_matches.cMatches; ++i) {
		MATCH_STATE* state = s_matches.matches + i;
		if (bufOffset != 0 && !state->matchState)
			continue;
		BOOL verboseMatch =  bufOffset != 0 && state->matchState;
		dirty = update_match(state, bufOffset, buf, cbBuf, verboseMatch);
		if (dirty) 
			break;
	}
	return dirty;
}

BOOL filter_read_inplace(int fd, char* buf, size_t cbRead)
{
	BOOL dirty = NO;
	static size_t fullBlockSize = 0;
	static size_t readPosition = 0;
	static union HEADER_BUF
	{
		HCI_HEADER hci;
		ACL_HEADER acl;
	} headerBuf;
	hciFd = fd;
		
	if (readPosition == fullBlockSize) {
		readPosition = 0;
	}
	if (readPosition < sizeof(headerBuf)) {
		memcpy (((char*)&headerBuf) + readPosition, buf, MIN(sizeof(headerBuf) - readPosition, cbRead));
	}

	switch(headerBuf.hci.type) {
		case HCI_EVENT: //event
			if (cbRead + readPosition < sizeof(HCI_HEADER)) {
				fullBlockSize = sizeof(HCI_HEADER);
				log_progress("filter_read_inplace: fragmented HCI_EVENT header: %u bytes so far (< %u)", cbRead + readPosition, sizeof(HCI_HEADER)); 
			} else {
				fullBlockSize = headerBuf.hci.size + sizeof(HCI_HEADER);
			}
			break;
		case ACL_PACKET: //ACL
			if (cbRead + readPosition < sizeof(ACL_HEADER)) {
				fullBlockSize = sizeof(ACL_HEADER);
				log_progress("filter_read_inplace: fragmented ACL_HEADER header: %u bytes so far (< %u)", cbRead + readPosition, sizeof(ACL_HEADER)); 
			} else {
				fullBlockSize = headerBuf.acl.size + sizeof(ACL_HEADER);
			}
			break;
		default:
			fullBlockSize = -1;
			assert(("Unknown HCI packet type", FALSE));
	}
	
	// process data..
	dirty = update_matches(readPosition, buf, cbRead);
	
	readPosition += cbRead;
	if (readPosition > fullBlockSize) {
		log_progress("filter_read_inplace: WARNING!! next block started in the same batch, possible math bug!!"); 
		assert (readPosition <= fullBlockSize);
		readPosition = fullBlockSize;
	}
	if (readPosition == fullBlockSize) {
		readPosition = fullBlockSize = 0;
	}
	return dirty;
}

BOOL filter_write_inplace(int fd, char* buf, size_t cbWrite)
{
	if (fd == hciFd) {
		
	}
	return FALSE;
}
