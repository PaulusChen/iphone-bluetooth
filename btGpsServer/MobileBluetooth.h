/*
 *  MobileBluetooth.h
 *  btTest
 *
 *  Created by msftguy on 6/20/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#ifndef __MOBILE_BLUETOOTH_H
#define __MOBILE_BLUETOOTH_H

#include <CoreFoundation/CoreFoundation.h>

#ifndef __cplusplus
typedef signed char BOOL; 
#endif

typedef int BTDeviceAttributes;
typedef int BTServiceMask;
typedef BOOL BTBool;
typedef int BTResult;
typedef enum {
	BTSessionEventConnectedSession = 0,
	BTSessionEventDisconnectedSession = 2
} BTSessionEvent;

typedef void *BTSESSION, **PBTSESSION;

typedef void *BTDISCOVERYAGENT, **PBTDISCOVERYAGENT;

typedef void *BTDEVICE, **PBTDEVICE;

typedef void *PAIRING_AGENT, **PPAIRING_AGENT;

//void (*)(BTSessionImpl*, BTSessionEvent, BTResult, void*)

typedef int (*SESSION_EVENT_CALLBACK)(BTSESSION session, BTSessionEvent sessionEvent, BTResult result, void* ctx);

typedef void* BTLOCALDEVICE;

typedef struct {
	SESSION_EVENT_CALLBACK eventCallback;
} SESSION_CALLBACKS, *PSESSION_CALLBACKS;

enum BT_DISCOVERY_STATUS
{
	BT_DISCOVERY_STATUS_STARTED = 0,
	BT_DISCOVERY_STATUS_FINISHED = 1,
};

typedef enum BT_DISCOVERY_STATUS BT_DISCOVERY_STATUS;


enum BT_DISCOVERY_EVENT
{
	BT_DISCOVERY_DEVICE_FOUND = 0,
	BT_DISCOVERY_DEVICE_LOST = 1,
	BT_DISCOVERY_DEVICE_CHANGED = 2,
};

typedef enum BT_DISCOVERY_EVENT BT_DISCOVERY_EVENT;

enum BT_PAIRING_AGENT_STATUS
{
	BT_PAIRING_AGENT_STARTED = 0,
	BT_PAIRING_AGENT_STOPPED = 1, 
	BT_PAIRING_ATTEMPT_STARTED = 2, 
	BT_PAIRING_ATTEMPT_COMPLETE = 3, 
};

typedef enum BT_PAIRING_AGENT_STATUS BT_PAIRING_AGENT_STATUS;

enum BT_SERVICE_TYPE
{
	BT_SERVICE_BRAILLE = 0x2000,
	BT_SERVICE_ANY = 0xFFFFffff,
};

typedef enum BT_SERVICE_TYPE BT_SERVICE_TYPE;

//void (*)(BTDiscoveryAgentImpl*, BTDiscoveryStatus, BTDeviceImpl*, BTResult, void*)

typedef void (*DISCOVERY_STATUS_CALLBACK)(
										  BTDISCOVERYAGENT agent, BT_DISCOVERY_STATUS status, 
										  BTDEVICE device, int result, void* ctx);

//void (*)(BTDiscoveryAgentImpl*, BTDiscoveryEvent, BTDeviceImpl*, BTDeviceAttributes, void*)

typedef void (*DISCOVERY_EVENT_CALLBACK)(
										 BTDISCOVERYAGENT agent, BT_DISCOVERY_EVENT event, 
										 BTDEVICE device, BTDeviceAttributes attr, void* ctx);

typedef struct _DiscoveryAgentCallbacks {
	DISCOVERY_STATUS_CALLBACK discoveryAgentStatusEventCallback;
	DISCOVERY_EVENT_CALLBACK discoveryAgentDiscoveryEventCallback;
} DISCOVERY_CALLBACKS, *PDISCOVERY_CALLBACKS;

//void (*)(BTPairingAgentImpl*, BTPairingEvent, BTDeviceImpl*, BTResult, void*)

typedef void (*PAIRING_AGENT_STATUS_CALLBACK)(PAIRING_AGENT agent, BT_PAIRING_AGENT_STATUS status, BTDEVICE device, int PairingResult, void* ctx);

//void (*)(BTPairingAgentImpl*, BTDeviceImpl*, uint8_t, void*)

typedef void (*PAIRING_PINCODE_CALLBACK)(PAIRING_AGENT agent, BTDEVICE device, uint8_t unk1, void* ctx);

//void (*)(BTPairingAgentImpl*, BTDeviceImpl*, BTServiceMask, void*)

typedef void (*PAIRING_AUTHORIZATION_CALLBACK)(PAIRING_AGENT agent, BTDEVICE device, BTServiceMask serviceMask, void* ctx);

//void (*)(BTPairingAgentImpl*, BTDeviceImpl*, uint32_t, BTBool, void*)

typedef void (*PAIRING_USER_CONFIRMATION_CALLBACK)(PAIRING_AGENT agent, BTDEVICE device, uint32_t unk1, BTBool unk2, void* ctx);

//void (*)(BTPairingAgentImpl*, BTDeviceImpl*, uint32_t, void*)

typedef void (*PAIRING_PASSKEY_DISPLAY_CALLBACK)(PAIRING_AGENT agent, BTDEVICE device, uint32_t unk1, void* ctx);


typedef struct _PairingAgentCallbacks {
	PAIRING_AGENT_STATUS_CALLBACK pairingAgentStatusCallback;
	PAIRING_PINCODE_CALLBACK pairingPincodeCallback;
	PAIRING_AUTHORIZATION_CALLBACK pairingAuthorizationCallback;
	PAIRING_USER_CONFIRMATION_CALLBACK pairingUserConfirmationCallback;
	PAIRING_PASSKEY_DISPLAY_CALLBACK pairingPasskeyDisplayCallback;
} PAIRING_AGENT_CALLBACKS, *PPAIRING_AGENT_CALLBACKS;


enum BT_LOCAL_DEVICE_EVENT
{
	BT_LOCAL_DEVICE_POWER_STATE_CHANGED = 0,
	BT_LOCAL_DEVICE_CONNECTION_STATUS_CHANGED = 5, 
};

typedef enum BT_LOCAL_DEVICE_EVENT BT_LOCAL_DEVICE_EVENT;

typedef void (*LOCAL_STATUS_EVENT_CALLBACK)(BTLOCALDEVICE* localDevice, BT_LOCAL_DEVICE_EVENT event, void* unk1, void* ctx);

typedef struct _LocalDeviceCallbacks {
	LOCAL_STATUS_EVENT_CALLBACK localStatusEventCallback;
} LOCAL_DEVICE_CALLBACKS, *PLOCAL_DEVICE_CALLBACKS;

enum SERVICE_EVENT_TYPE 
{
	SERVICE_EVENT_TYPE_CONNECTED = 0,
	SERVICE_EVENT_TYPE_DISCONNECTED = 1,
	SERVICE_EVENT_TYPE_SERVICE_DEPENDENT = 2,
};

typedef enum SERVICE_EVENT_TYPE SERVICE_EVENT_TYPE;

enum SERVICE_EVENT 
{
	SERVICE_EVENT_STARTED_CONNECTING = 0,
	SERVICE_EVENT_CONNECTING_SERVICE = 1,
	SERVICE_EVENT_CONNECTED = 11,
	SERVICE_EVENT_DISCONNECTION_RESULT = 12,
};

typedef enum SERVICE_EVENT SERVICE_EVENT;

typedef void (*SERVICE_EVENT_CALLBACK)(BTDEVICE device, BT_SERVICE_TYPE service, SERVICE_EVENT_TYPE eventType, SERVICE_EVENT event, int result ,void* ctx);

enum MODULE_POWER_STATE
{
	POWER_STATE_OFF = 0,
	POWER_STATE_ON = -1,
};

typedef enum MODULE_POWER_STATE MODULE_POWER_STATE;

#ifdef __cplusplus
extern "C" {
#endif
	
int BTLocalDeviceGetDefault(BTSESSION session, BTLOCALDEVICE* pLocalDevice);

int BTLocalDeviceAddCallbacks(BTLOCALDEVICE localDevice, PLOCAL_DEVICE_CALLBACKS pCallbacks, void* ctx);

int BTLocalDeviceSetModulePower(BTLOCALDEVICE localDevice, int unk_must_be_1, MODULE_POWER_STATE powerState);

int BTLocalDeviceGetModulePower(BTLOCALDEVICE localDevice, int unk_must_be_1, int* powerStatus);

int BTSessionAttachWithRunLoopAsync(CFRunLoopRef runLoop, const char* sessionName, PSESSION_CALLBACKS pCallbacks, void* ctx, PBTSESSION pSession);

int BTSessionDetachWithRunLoopAsync(CFRunLoopRef runLoop, BTSESSION session);
	
int BTDiscoveryAgentCreate(BTSESSION session, PDISCOVERY_CALLBACKS pCallbacks, void* ctx, PBTDISCOVERYAGENT pAgent);

int BTDiscoveryAgentStartScan(BTDISCOVERYAGENT agent, int magic1, int magic2);

int BTDiscoveryAgentStopScan(BTDISCOVERYAGENT agent);

int	BTDiscoveryAgentDestroy(BTDISCOVERYAGENT agent);
	
int BTDeviceGetSupportedServices(BTDEVICE device, int* svc);

int BTDeviceGetName(BTDEVICE device, char* nameBuf, size_t cbNameBuf);

int BTDeviceAddressFromString(const char* addrString, char macAddr[0x6]);

int BTDeviceFromAddress(BTSESSION session, char macAddr[6], PBTDEVICE pDeviceOut);

int BTDeviceSetVirtualType(BTDEVICE device, int type);

int BTDeviceConnect(BTDEVICE device);

int BTDeviceDisconnect(BTDEVICE device);

int BTDeviceDetect(BTDEVICE device, int unk1, int* outUnk2);

int BTDeviceGetAddressString(BTDEVICE device, char* buf, size_t bufSize);

int BTDeviceSetAuthorizedServices(BTDEVICE device, int services);

int BTDeviceGetComPortForService(BTDEVICE device, int svcIdOrSmth, char*buf, int cbBuf/*0x40*/);


int BTPairingAgentCreate(BTSESSION session, PPAIRING_AGENT_CALLBACKS PairingAgentCallbacks, void* ctx, PPAIRING_AGENT pPairingAgent);

int BTPairingAgentStart(PAIRING_AGENT pairingAgent);

int BTPairingAgentStop(PAIRING_AGENT pairingAgent);

int BTPairingAgentDestroy(PAIRING_AGENT pairingAgent);

int BTPairingAgentSetPincode(PAIRING_AGENT pairingAgent, BTDEVICE device, const char* pinUtf8);

int BTPairingAgentCancelPairing(PAIRING_AGENT pairingAgent);

int BTServiceAddCallbacks(BTSESSION session, SERVICE_EVENT_CALLBACK callback, void* ctx);

int BTFrameworkIsServerUp(); //0, 1, 9 ...
	
#ifdef __cplusplus
}
#endif


#endif // __MOBILE_BLUETOOTH_H
