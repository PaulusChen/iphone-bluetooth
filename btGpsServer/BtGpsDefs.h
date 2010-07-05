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

typedef enum {
	BtStatePowerKeep,
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

#endif /* _BT_GPS_DEFS_H */