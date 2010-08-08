/*
 *  client_test.c
 *  btGpsClient
 *
 *  Created by msftguy on 6/26/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#include "client_test.h"

#include "client_helper.h"
#include "log.h"
#include "btGps.h"

#include <nmea/nmea.h>
#include <nmea/time.h>

#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <sys/mman.h>

#include <CoreFoundation/CoreFoundation.h>


void usage(const char* progName) {
	printf("Usage: %s [-n <device name>][-p <pin code>][-a <mac address>][-w][-c][-d]\n", progName);
	exit (1);
}

char g_pin[BUFSIZ] = "";
char g_devName[BUFSIZ] = "";
char g_macAddr[BUFSIZ] = "";

mach_port_t g_serverPort;

boolean_t g_wait = FALSE;
BtState g_targetState = BtStateIdle;

void parseOptions(int argc, char *argv[])
{
	char ch;
	while ((ch = getopt(argc, argv, "p:n:a:wcds")) != -1) {
		switch (ch) {
			case 'p':
				strcpy(g_pin, optarg);
				break;
			case 'n':
				strcpy(g_devName, optarg);
				break;
			case 'a':
				strcpy(g_macAddr, optarg);
				break;
			case 'w':
				g_wait = TRUE;
				break;
			case 'd':
				g_targetState = BtStatePowerOff;
				break;
			case 'c':
				g_targetState = BtStateConnected;
				break;
			case 's':
				g_targetState = BtStateScan;
				break;			
			default:
				usage(*argv);
		}
	}
}

void gpsscan_notification(
						   CFNotificationCenterRef center,
						   void *observer,
						   CFStringRef name,
						   const void *object,
						   CFDictionaryRef userInfo
						   )
{
	vm_address_t addr; 
	mach_msg_type_number_t size;
	kern_return_t result = get_scan_results(g_serverPort, &addr, &size);
	if (result == KERN_SUCCESS) {
		printf("Scan results:\n");
		print_scan_results((void*)addr, size);
		vm_deallocate(mach_task_self(), addr, size);
	}
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
	static void* p_shm = MAP_FAILED;
	if (shmid == -1)
		shmid = shm_open(BtGpsSharedMemSectionName, O_RDONLY);
	if (shmid != -1 && p_shm == MAP_FAILED) {
		p_shm = mmap(0, PAGE_SIZE, PROT_READ, MAP_SHARED, shmid, 0);
	}
	if (p_shm != MAP_FAILED) {	
		nmeaINFO* nmeaInfo = p_shm;
		nmeaTIME* utc = &nmeaInfo->utc;
		printf("nmeaInfo: fl: %x;lat=%f, lon=%f, elev=%f; spd=%f, dir=%f; gmt=%02u:%02u:%02u\n", 
			   nmeaInfo->smask,
			   nmeaInfo->lat, nmeaInfo->lon, nmeaInfo->elv, 
			   nmeaInfo->speed, nmeaInfo->direction,
			   utc->hour, utc->min, utc->sec); 
	}
}

void wait_for_notifications()
{
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), 
									NULL, gpsscan_notification, 
									BtGpsScanNotificationName, nil, 
									CFNotificationSuspensionBehaviorDrop);
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), 
									NULL, gpsinfo_notification, 
									BtGpsNotificationName, nil, 
									CFNotificationSuspensionBehaviorDrop);
	CFRunLoopRef runLoop = CFRunLoopGetCurrent();
	runLoop;
	CFRunLoopRun();
}

void client_test(int argc, char *argv[])
{
	parseOptions(argc, argv);
	kern_return_t result;
	result = get_server_port(&g_serverPort);
	if (result != KERN_SUCCESS) {
		LogMsg("get_server_port() failed: 0x%x", result);
		return;
	}
	
	if (*g_pin) {
		result = set_pin(g_serverPort, g_pin, strlen(g_pin) + 1);
		if (result != KERN_SUCCESS) {
			LogMsg("set_pin failed, 0x%x", result);
		}
	}
	if (*g_macAddr) {
		result = set_addr(g_serverPort, g_macAddr, strlen(g_macAddr) + 1);
		if (result != KERN_SUCCESS) {
			LogMsg("set_addr failed, 0x%x", result);
		}
	}
	if (*g_devName) {
		result = set_name(g_serverPort, g_devName, strlen(g_devName) + 1);
		if (result != KERN_SUCCESS) {
			LogMsg("set_name failed, 0x%x", result);
		}
	}
	if (g_targetState != BtStateIdle) {
		result = set_state(g_serverPort, g_targetState);
		if (result != KERN_SUCCESS) {
			LogMsg("set_state failed, 0x%x", result);
		}
	}
	
	if (g_wait || g_targetState == BtStateScan) {
		wait_for_notifications();
	}
}