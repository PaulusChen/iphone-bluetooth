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
	char hciType;
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
unsigned char mbt1k_lmpExtFeaturesEvent[] = {0x23, 0x0D, 0x00, '*', '*',  '*', '*',  '*', '*', '*', '*',  '*', '*', '*', '*'};

unsigned char garmin_lmp_extfeat[]	=  {01, 00,   0x00, 0x00, 0x00, 0x00,  0x00, 0x00, 0x00, 0x00};

HCI_PATCH mbt1k_lmpExtFeaturesPatch = {HCI_EVENT, sizeof(mbt1k_lmpExtFeaturesEvent), mbt1k_lmpExtFeaturesEvent, '*'/*0x2A*/, sizeof(garmin_lmp_extfeat), garmin_lmp_extfeat, -1};

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

typedef enum {
	MATCH_SEARCHING,
	MATCH_NONE,
	MATCH_FOUND,
} MATCH_RESULT;

MATCH_RESULT update_matches(char hciType, size_t bufOffset, char* buf, size_t cbBuf)
{
	BOOL matchFound = NO;
	BOOL matchesPossible = NO;
	for (int i = 0; i < s_matches.cMatches; ++i) {
		MATCH_STATE* state = s_matches.matches + i;
		if (bufOffset == 0) {
			state->matchState = (hciType == state->patch->hciType);
		}
		if (!state->matchState)
			continue;
		BOOL verboseMatch =  bufOffset != 0 && state->matchState;
		matchFound = update_match(state, bufOffset, buf, cbBuf, verboseMatch);
		if (state->matchState) {
			matchesPossible = YES;
		}
		if (matchFound) 
			break;
	}
	return matchFound ? MATCH_FOUND : matchesPossible ? MATCH_SEARCHING : MATCH_NONE;
}

const char slip_boundary = (char)0xC0;
const char slip_escape = (char)0xDB;
const char slip_escaped_boundary = (char)0xDC;
const char slip_escaped_escape = (char)0xDD;
 
typedef struct {
	BOOL boundary;
	BOOL escape;
} SLIP_STATE;

size_t slip_decode_data(char* inputBuf, size_t cbInput, char* outputBuf, size_t* cbOutput)
{
	size_t cbWritten = 0;
	BOOL escape = FALSE;
	size_t i;
	for (i = 0; i < cbInput && cbWritten < *cbOutput; ++i) {
		char inByte = inputBuf[i], outByte;
		if (escape) {
			switch (inByte) {
				case slip_escaped_boundary:
					outByte = slip_boundary;
					break;
				case slip_escaped_escape:
					outByte = slip_escape;
					break;
				default:
					assert(("Unrecognized SLIP escape sequence!", FALSE));
					outByte = inByte;
					break;
			}
		} else {
			if (inByte == slip_boundary)
				break;
			else if (inByte == slip_escape) {
				escape = TRUE;
				continue;
			} else {
				outByte = inByte;
			}
		}
		outputBuf[cbWritten++] = outByte;
	}
	*cbOutput = cbWritten;
	return i;
}

typedef	union {
	struct { 
		unsigned int seqNumber:3;
		unsigned int ackNumber:3;
		unsigned int integrityCheck:1;
		unsigned int reliablePacket:1;
		unsigned int type:4;
		unsigned int payloadLength:12;
		unsigned int checksum:8;
	};
	char bytes[4];
} SLIP_HEADER;

BOOL filter_read_h5_inplace(int fd, char* buf, size_t cbRead)
{
	SLIP_HEADER slipHeader;
	static char s_matchBuf[sizeof(mbt1k_lmpExtFeaturesEvent)]; // FIXME: don't hardcode sizes plz
	BOOL valid = NO;
	size_t cbDecoded = 0;
	for (size_t i = 0; i < cbRead; i += cbDecoded) {
		if (buf[i] == slip_boundary) {
			valid = TRUE;
			cbDecoded = 1;
			continue;
		}
		if (!valid) {
			char* pNextBlock = (char*)memchr(buf + i, '\xC0', cbRead - i);
			if (pNextBlock == nil) {
				log_progress("filter_read_h5_inplace: SYNC ERROR: could not resync after the previous fuckup ;(");
				return FALSE;
			}
			cbDecoded = pNextBlock - buf - i;
			valid = YES;
			continue;
		}
		size_t cbWritten = sizeof(slipHeader);
		cbDecoded = slip_decode_data(buf + i, cbRead - i, slipHeader.bytes, &cbWritten);
		if (cbWritten != sizeof(slipHeader)) {
			log_progress("filter_read_h5_inplace: SLIP header fuckup: could only decode %u bytes", cbWritten);
			valid = FALSE;
			continue;
		}
		// process header..
		MATCH_RESULT matchResult = update_matches(slipHeader.type, 0, nil, 0);
		if (matchResult == MATCH_NONE) {
			valid = NO;
			continue;
		}

		i += cbDecoded;
		cbWritten = sizeof(s_matchBuf);
		cbDecoded = slip_decode_data(buf + i, cbRead - i, s_matchBuf, &cbWritten);

		// process data..
		matchResult = update_matches(slipHeader.type, 0, nil, cbWritten);
		if (matchResult == MATCH_NONE) {
			valid = NO;
			continue;
		}
		// TODO: reencode; fix checksum; resize the output buffer if necessary
		
	}
	//FIXME
	return FALSE;
}

BOOL filter_read_h4_inplace(int fd, char* buf, size_t cbRead)
{
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
	char* adjBuf = buf;
	size_t adjCbRead = cbRead;
	size_t adjReadPosition = readPosition;
	if (readPosition == 0) { //skip packet type byte 
		adjBuf++;
		adjCbRead--;
	} else {
		adjReadPosition--;
	}
#ifdef DEBUG
	log_progress("filter_read_inplace DEBUG: update_matches(%u, %u, %p vs %p, %u)", 
				 headerBuf.hci.type, adjReadPosition, adjBuf, buf, adjCbRead);
#endif
	MATCH_RESULT matchResult = update_matches(headerBuf.hci.type, adjReadPosition, adjBuf, adjCbRead);
	
	readPosition += cbRead;
	if (readPosition > fullBlockSize) {
		log_progress("filter_read_inplace: WARNING!! next block started in the same batch, possible math bug!!"); 
		assert (readPosition <= fullBlockSize);
		readPosition = fullBlockSize;
	}
	if (readPosition == fullBlockSize) {
		readPosition = fullBlockSize = 0;
	}
	return matchResult == MATCH_FOUND;
}

BOOL filter_write_inplace(int fd, char* buf, size_t cbWrite)
{
	if (fd == hciFd) {
		
	}
	return FALSE;
}
