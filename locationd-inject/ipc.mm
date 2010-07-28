/*
 *  ipc.mm
 *  locationd-inject
 *
 *  Created by svp on 7/28/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#include "ipc.h"

#include "log.h"

#include "btGps.h"
#include "BtGpsDefs.h"

#include <mach/task.h>
#include <mach/mach.h>
#include <mach/mach_error.h>
#include "bootstrap.h"

#include <fcntl.h>
#include <sys/mman.h>
#include <stdio.h>

kern_return_t get_server_port(mach_port_t* serverPort) 
{
	*serverPort = 0;
	kern_return_t result;
	static mach_port_t bootstrap_port = MACH_PORT_NULL;
	mach_port_t server_port;
	if (bootstrap_port == MACH_PORT_NULL) {
		result = task_get_bootstrap_port(mach_task_self(), &bootstrap_port);
		if (result != KERN_SUCCESS) {
			LogMsg("task_get_bootstrap_port failed: %x\n", result);
			return result;
		}
	}
	result = bootstrap_look_up(bootstrap_port, BTGPS_MACH_PORT_NAME, &server_port);
	if (result != KERN_SUCCESS) {
		LogMsg("bootstrap_look_up failed: %x\n", result);
		return result;
	}
	*serverPort = server_port;
	return KERN_SUCCESS;
}

static gps_shared_mem_t* g_shm_info = NULL;


size_t shm_read_ringbuf(char *data, size_t* lastPos)
{
	size_t oldPos = *lastPos;
	size_t pos = *lastPos = g_shm_info->ringbufPos;
	if (pos == oldPos)
		return 0;
	
	if (oldPos < pos) {
		memcpy(data, g_shm_info->ringbuf + oldPos, pos - oldPos);
	} else {
		size_t endChunkSize = sizeof(g_shm_info->ringbuf) - oldPos;
		memcpy(data, g_shm_info->ringbuf + oldPos, endChunkSize);
		memcpy(data + endChunkSize, g_shm_info->ringbuf, pos);
	}
	return (pos - oldPos + sizeof(g_shm_info->ringbuf)) % sizeof(g_shm_info->ringbuf);
}

void gpsinfo_notification(
						  CFNotificationCenterRef center,
						  void *observer,
						  CFStringRef name,
						  const void *object,
						  CFDictionaryRef userInfo
						  )
{
	static int shmid = -1;
	static size_t lastRingbufPos = 0;
	if (shmid == -1)
		shmid = shm_open(BtGpsSharedMemSectionName, O_RDONLY);
	if (shmid != -1 && g_shm_info == NULL) {
		void* map = mmap(0, PAGE_SIZE, PROT_READ, MAP_SHARED, shmid, 0);
		if (map != MAP_FAILED) {
			g_shm_info = (gps_shared_mem_t*)map;
		}
	}
	if (g_shm_info != NULL) {
		char sentenceBuf[PAGE_SIZE];
		size_t cbRead = shm_read_ringbuf(sentenceBuf, &lastRingbufPos);
		if (cbRead != 0) {
			sentenceBuf[cbRead] = '\0';
			[(EALocationAccessory*)observer onNmea:[NSString stringWithUTF8String:sentenceBuf]];
		}
	}
}

void set_server_state(BtState state)
{
	mach_port_t serverPort = MACH_PORT_NULL;
	kern_return_t result = get_server_port(&serverPort);
	if (result != KERN_SUCCESS) {
		LogMsg("get_server_port() failed: 0x%x", result);
		return;
	}
	result = set_state(serverPort, state);
	if (result != KERN_SUCCESS) {
		LogMsg("set_state failed, 0x%x", result);
	}
	if (serverPort != MACH_PORT_NULL) {
		mach_port_destroy(mach_task_self(), serverPort);
	}
	
}

void gps_start(EALocationAccessory* accObj) 
{
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), 
									accObj, gpsinfo_notification, 
									BtGpsNotificationName, nil, 
									CFNotificationSuspensionBehaviorDrop);
	set_server_state(BtStateConnected);
}

void gps_stop(EALocationAccessory* accObj) 
{
	CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), accObj, BtGpsNotificationName, nil);
	set_server_state(BtStatePowerKeep);
}
