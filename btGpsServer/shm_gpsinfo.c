/*
 *  shm_gpsinfo.c
 *  btGpsServer
 *
 *  Created by msftguy on 6/28/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#include "shm_gpsinfo.h"

#include "log.h"

#include <nmea/nmea.h>
#include <nmea/sentence.h>

#include <CoreFoundation/CoreFoundation.h>

#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>

int smask_rating(int smask)
{
	if (smask & GPRMC)
		return 2;
	if (smask & GPGGA)
		return 1;
	return 0;
}

static void* g_shm_info = NULL;

void shm_post_update(nmeaINFO* nmeaInfo)
{	
	const int bestRatingResetTimeout = 3;
	
	static int lastSeenBestRatedSentence = 0;

	int currentRating = smask_rating(nmeaInfo->smask);
	
	static nmeaTIME lastTimestamp;
	
	// only do this for position sentences because 
	// sentences without embedded UTC get local device time
	// which will vary with each sentence
	
	if (currentRating > 0 && 
		0 != memcmp(&lastTimestamp, &nmeaInfo->utc, sizeof(nmeaTIME))) {
		lastTimestamp = nmeaInfo->utc;
		++lastSeenBestRatedSentence;
#ifdef DEBUG
		LogMsg("shm_post_update DEBUG: incrementing lastSeenBestRatedSentence to %u, current rating %u", 
			   lastSeenBestRatedSentence, currentRating);

#endif
	}

	static int bestRating = 0;

	if (lastSeenBestRatedSentence > bestRatingResetTimeout) {
		LogMsg("shm_post_update: resetting best rating (%u)", bestRating);
		bestRating = 0;
	}
	
	
	if (currentRating > bestRating) {
		bestRating = currentRating;
		LogMsg("shm_post_update: best rating set to (%u)", bestRating);
	}
	
	// always update shared mem to make it possible to show satellite positions before fix is available
	memcpy(g_shm_info, nmeaInfo, sizeof(nmeaINFO));
	if (currentRating == bestRating && lastSeenBestRatedSentence != 0) {
		lastSeenBestRatedSentence = 0;
		CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), BtGpsNotificationName, nil, nil, TRUE);
	}
}

boolean_t shm_ensure()
{
	if (g_shm_info != NULL) {
		return TRUE;
	}
	int shmid = shm_open(BtGpsSharedMemSectionName, O_CREAT | O_RDWR, 0644);
	if (shmid == -1) {
		LogMsg("shm_ensure: shm_open(%s) FAILED, error=0x%x", BtGpsSharedMemSectionName, errno);
		return FALSE;
	}
	struct stat statInfo;
	int ret = fstat(shmid, &statInfo);
	if (ret != 0) {
		LogMsg("shm_ensure: fstat FAILED, error=0x%x", errno);
		return FALSE;	
	}
	if (statInfo.st_size != PAGE_SIZE) {
		LogMsg("shm_ensure: resizing shm: %lu -> %u", statInfo.st_size, PAGE_SIZE);
		ret = ftruncate(shmid, PAGE_SIZE);
		if (ret != 0) {
			LogMsg("shm_ensure: ftruncate FAILED, error=0x%x", errno);
			return FALSE;	
		}
	}
	g_shm_info = mmap(0, PAGE_SIZE, PROT_WRITE|PROT_READ, MAP_SHARED, shmid, 0);
	if (g_shm_info == MAP_FAILED) {
		g_shm_info = NULL;
		LogMsg("shm_ensure: mmap FAILED, error=0x%x", errno);
		return FALSE;	
	}
	return TRUE;
}