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

int best_sentence_in_smask(int smask)
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
	static nmeaINFO lastNmeaInfo;
	
	lastNmeaInfo.smask = nmeaInfo->smask;
	// Spam Filter 1: only post a notifiation if there are actual changes
	if (0 == memcmp(&lastNmeaInfo, nmeaInfo, offsetof(nmeaINFO, satinfo))) {
		return;
	}
	memcpy(&lastNmeaInfo, nmeaInfo, sizeof(nmeaINFO));
	
	static int best_sentence_ever = 0;

	int best_sentence = best_sentence_in_smask(nmeaInfo->smask);
	// Spam Filter 2: post after getting the best sentence available.
	if (best_sentence < best_sentence_ever) {
		return;
	} else if (best_sentence > best_sentence_ever) {
		best_sentence_ever = best_sentence;
	}
	
	memcpy(g_shm_info, nmeaInfo, sizeof(nmeaINFO));
	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), BtGpsNotificationName, nil, nil, TRUE);
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