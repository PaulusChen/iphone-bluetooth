/*
 *  bt_helpers.c
 *  btTest
 *
 *  Created by msftguy on 6/26/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#include "bt_helpers.h"
#include <stdio.h>

#define BUFSIZ 1024

inline const char* ServiceEventString(SERVICE_EVENT event)
{
	static char buf[BUFSIZ];
	switch (event) {
		case SERVICE_EVENT_STARTED_CONNECTING:
			return "SERVICE_EVENT_STARTED_CONNECTING";
			break;
		case SERVICE_EVENT_CONNECTING_SERVICE:
			return "SERVICE_EVENT_CONNECTING_SERVICE";
			break;
		case SERVICE_EVENT_CONNECTED:
			return "SERVICE_EVENT_CONNECTED";
			break;
		case SERVICE_EVENT_DISCONNECTION_RESULT:
			return "SERVICE_EVENT_DISCONNECTION_RESULT";
			break;
		default:
			snprintf(buf, sizeof(buf), "Unknown service event: %i", event);
			return buf;
			break;
	}
}

inline const char* LocalEventString(BT_LOCAL_DEVICE_EVENT event) 
{
	static char buf[BUFSIZ];
	switch (event) {
		case BT_LOCAL_DEVICE_POWER_STATE_CHANGED:
			return "BT_LOCAL_DEVICE_POWER_STATE_CHANGED";
			break;
		case BT_LOCAL_DEVICE_CONNECTION_STATUS_CHANGED:
			return "BT_LOCAL_DEVICE_CONNECTION_STATUS_CHANGED";
			break;
		default:
			snprintf(buf, sizeof(buf), "Unknown local event: %i", event);
			return buf;
			break;
	}
}


inline const char* PairingStatusString(BT_PAIRING_AGENT_STATUS status) 
{
	static char buf[BUFSIZ];
	switch (status) {
		case BT_PAIRING_AGENT_STARTED:
			return "BT_PAIRING_AGENT_STARTED";
			break;
		case BT_PAIRING_AGENT_STOPPED:
			return "BT_PAIRING_AGENT_STOPPED";
			break;
		case BT_PAIRING_ATTEMPT_STARTED:
			return "BT_PAIRING_ATTEMPT_STARTED";
			break;
		case BT_PAIRING_ATTEMPT_COMPLETE:
			return "BT_PAIRING_ATTEMPT_COMPLETE";
			break;
		default:
			snprintf(buf, sizeof(buf), "Unknown pairing status: %i", status);
			return buf;
			break;
	}
}


inline const char* DiscoveryStatusString(BT_DISCOVERY_STATUS status) 
{
	static char buf[BUFSIZ];
	switch (status) {
		case BT_DISCOVERY_STATUS_STARTED:
			return "BT_DISCOVERY_STATUS_STARTED";
			break;
		case BT_DISCOVERY_STATUS_FINISHED:
			return "BT_DISCOVERY_STATUS_FINISHED";
			break;
		default:
			snprintf(buf, sizeof(buf), "Unknown discovery status: %i", status);
			return buf;
			break;
	}
}

inline const char* DiscoveryEventString(BT_DISCOVERY_EVENT event) 
{
	static char buf[BUFSIZ];
	switch (event) {
		case BT_DISCOVERY_DEVICE_FOUND:
			return "BT_DISCOVERY_DEVICE_FOUND";
			break;
		case BT_DISCOVERY_DEVICE_LOST:
			return "BT_DISCOVERY_DEVICE_LOST";
			break;
		case BT_DISCOVERY_DEVICE_CHANGED:
			return "BT_DISCOVERY_DEVICE_CHANGED";
			break;
		default:
			snprintf(buf, sizeof(buf), "Unknown discovery event: %i", event);
			return buf;
			break;
	}
}
