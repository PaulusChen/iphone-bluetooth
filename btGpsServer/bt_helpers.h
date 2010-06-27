/*
 *  bt_helpers.h
 *  btTest
 *
 *  Created by msftguy on 6/26/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#ifndef _BT_HELPERS_H
#define _BT_HELPERS_H

#include "MobileBluetooth.h"

#ifdef __cplusplus
extern "C" {
#endif
	
	const char* ServiceEventString(SERVICE_EVENT event);
	const char* LocalEventString(BT_LOCAL_DEVICE_EVENT event);
	const char* PairingStatusString(BT_PAIRING_AGENT_STATUS status);
	const char* DiscoveryStatusString(BT_DISCOVERY_STATUS status);
	const char* DiscoveryEventString(BT_DISCOVERY_EVENT event);
	
#ifdef __cplusplus
}
#endif

#endif //_BT_HELPERS_H
