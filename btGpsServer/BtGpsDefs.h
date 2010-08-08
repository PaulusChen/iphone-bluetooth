/*
 *  BtGpsDefs.h
 *  btGpsServer
 *
 *  Created by msftguy on 6/26/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */
#ifndef _BT_GPS_DEFS_H
#define _BT_GPS_DEFS_H

#include <CoreFoundation/CoreFoundation.h>
#include <nmea/nmea.h>

#define STATIC_ASSERT(x, msg) typedef char ASSERT_FAILED__##msg[(x) ? 1 : -1]

typedef enum {
	BtStateIdle,
	BtStatePowerOff,
	BtStatePowerOn,
	BtStateScan,
	BtStateConnecting,
	//	BtStatePairing,
	BtStateConnected,
} BtState;

#define BTGPS_MACH_PORT_NAME "com.msftguy.server.btgps"

#define BtGpsSharedMemSectionName "BtGpsSharedMemSection_v1"
#define BtGpsNotificationName CFSTR("com.msftguy.btgps.server_updated")
#define BtGpsScanNotificationName CFSTR("com.msftguy.btgps.scan_updated")

typedef char str80[80];

typedef struct {
	nmeaINFO nmeaInfo;
	size_t ringbufPos;
	char ringbuf[PAGE_SIZE - sizeof(nmeaINFO) - sizeof(size_t)];
} gps_shared_mem_t;

STATIC_ASSERT(sizeof(gps_shared_mem_t) == PAGE_SIZE, bad_structure_size);

#endif /* _BT_GPS_DEFS_H */