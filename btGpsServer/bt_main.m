/*
 *  bt_main.mm
 *  btTest
 *
 *  Created by msftguy on 6/25/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#include "bt_main.h"
#include "bt_helpers.h"
#include <pthread.h>
#include "log.h"

char g_pin[BUFSIZ] = "0000";
char g_macAddr[BUFSIZ] = "";
char g_devName[BUFSIZ] = "";
bool g_targetState = false;

BluetoothContext* g_bc = NULL;
//--------------------------------------------

int sessionEventCallback(BTSESSION session, BTSessionEvent sessionEvent, BTResult result, void* ctx)
{
	BluetoothContext* bc = (BluetoothContext*)ctx;
	assert(bc == g_bc);

	LogMsg("sessionEventCallback( session:%p, BTSessionEvent:%x, BTResult:%x, magic:%x )",
		   session, sessionEvent, result, bc.magic);
	btTest(session, bc);
	
	[NSTimer scheduledTimerWithTimeInterval:30 target:bc selector:@selector(timerProc:) userInfo:nil repeats:YES];
	return 0;
}

void pairingAgentStatusCallback(PAIRING_AGENT agent, BT_PAIRING_AGENT_STATUS status, BTDEVICE device, int PairingResult, void* ctx) 
{
	BluetoothContext* bc = (BluetoothContext*) ctx;
	assert(bc == g_bc);
	
	LogMsg("pairingAgentStatusCallback( agent:%p, status:%s, device:%p, PairingResult:%i, magic:%x )", 
		   agent, PairingStatusString(status), device, PairingResult, bc.magic);
	
	switch (status)
	{
		case BT_PAIRING_AGENT_STARTED:
			break;
		case BT_PAIRING_AGENT_STOPPED:
			break;
		case BT_PAIRING_ATTEMPT_COMPLETE:
			break;
		default:
			break;
	}
	return;
}

void pairingPincodeCallback(PAIRING_AGENT agent, BTDEVICE device, uint8_t unk1, void* ctx) 
{
	BluetoothContext* bc = (BluetoothContext*) ctx;
	assert(bc == g_bc);
	
	LogMsg("pairingPincodeCallback( agent:%p, device:%p, unk1:%x, magic:%x )", agent, device, unk1, bc.magic);
	
	int err = BTPairingAgentSetPincode(agent, device, g_pin);
	if (err != 0) {
		LogMsg("BTPairingAgentSetPincode error: %X", err);
		return;
	}
	LogMsg("BTPairingAgentSetPincode OK");
	
	return;
}

void pairingAuthorizationCallback(PAIRING_AGENT agent, BTDEVICE device, BTServiceMask serviceMask, void* ctx) 
{
	LogMsg("pairingAuthorizationCallback");
	return;
}

void pairingUserConfirmationCallback(PAIRING_AGENT agent, BTDEVICE device, uint32_t unk1, BTBool unk2, void* ctx) 
{
	LogMsg("pairingUserConfirmationCallback");
	return;
}

void pairingPasskeyDisplayCallback(PAIRING_AGENT agent, BTDEVICE device, uint32_t unk1, void* ctx) 
{
	LogMsg("pairingPasskeyDisplayCallback");
	return;
}

void serviceEventCallback(BTDEVICE device, BT_SERVICE_TYPE service, int eventType, SERVICE_EVENT event, int result, void* ctx)
{
	BluetoothContext* bc = (BluetoothContext*)ctx;
	assert(bc == g_bc);
	
	LogMsg("serviceEventCallback( device:%p, service:%X, eventType:%i, event:%s, result:%i, magic:%x )",
		   device, service, eventType, ServiceEventString(event), result, bc.magic);
	
	if (service == BT_SERVICE_BRAILLE) {
		if (eventType == SERVICE_EVENT_TYPE_CONNECTED && event == SERVICE_EVENT_CONNECTED) {
			char buf[0x100] = "";
			int err = BTDeviceGetComPortForService(bc.device, BT_SERVICE_BRAILLE, buf, sizeof(buf));
			if (err != 0) {
				LogMsg("BTDeviceGetComPortForService error: %X", err);
				return;
			}
			LogMsg("BTDeviceGetComPortForService OK: %s", buf);
			bc.connected = true;
		}
		if (eventType == SERVICE_EVENT_TYPE_DISCONNECTED && event == SERVICE_EVENT_DISCONNECTION_RESULT) {
			bc.connected = false;
		}
	}
}

void start_pairing(BluetoothContext* bc) 
{	
	if (!g_targetState) 
		return;
	int svc;
	int err; 
	
	BTDEVICE device = bc.device;
	
	err = BTDeviceSetAuthorizedServices(device, BT_SERVICE_BRAILLE);
	if (err != 0) {
		LogMsg("BTDeviceSetAuthorizedServices error: %X", err);
		return;
	}
	LogMsg("BTDeviceSetAuthorizedServices OK");
	
	err = BTDeviceDisconnect(device);
	if (err != 0) {
		LogMsg("BTDeviceDisconnect error: %X", err);
	}
	
	if (bc.pairingAgent != NULL) {
		err = BTPairingAgentCancelPairing(bc.pairingAgent);
		if (err != 0) {
			LogMsg("BTPairingAgentCancelPairing error: %X", err);
		}	
	}
	
	err = BTDeviceConnect(device);
	if (err != 0) {
		LogMsg("BTDeviceConnect error: %X", err);
		if (err == 0xA4 && bc.pairingAgent != NULL) {
			BTPairingAgentCancelPairing(bc.pairingAgent);
			
			err = BTDeviceConnect(device);
			if (err != 0)
			{
				LogMsg("BTDeviceConnect error: %X", err);
				return;
			}
		}
	}
	LogMsg("BTDeviceConnect OK");
	
	
	err = BTDeviceGetSupportedServices(device, &svc);
	if (err != 0) {
		LogMsg("BTDeviceGetSupportedServices error: %X", err);
		return;
	}	
	LogMsg("BTDeviceGetSupportedServices OK, svc=0x%X", svc);
}

bool is_target_device(const char* name, const char* addrString)
{
	if (strlen(g_macAddr) != 0 && strcasestr(addrString, g_macAddr) != nil)
		return true;
	if (strlen(g_devName) != 0 && strcasestr(name, g_devName) != nil)
		return true;
	return false;
}


void discoveryStatusCallback(BTDISCOVERYAGENT agent, BT_DISCOVERY_STATUS status, BTDEVICE device, int result, void* ctx)
{
	BluetoothContext* bc = (BluetoothContext*)ctx;
	assert(bc == g_bc);
	
	LogMsg("discoveryStatusCallback( agent:%p, status:%s, magic: %x )", agent, DiscoveryStatusString(status), bc.magic);
	if (status == BT_DISCOVERY_STATUS_FINISHED) 
	{
		bc.discoveryInProgress = false;
	} else if (status == BT_DISCOVERY_STATUS_STARTED) {
		bc.discoveryInProgress = true;
	}
	return;
}

void discoveryEventCallback(BTDISCOVERYAGENT agent, BT_DISCOVERY_EVENT event, 
							BTDEVICE device, BTDeviceAttributes attr, void* ctx)
{
	BluetoothContext* bc = (BluetoothContext*)ctx;
	assert(bc == g_bc);
	
	LogMsg("discoveryEventCallback( agent:%p, event:%s, device:%p, attr:%x )", agent, DiscoveryEventString(event), device, attr);
	int svc;
	char name[BUFSIZ] = "", addr[BUFSIZ] = "";
	int err = BTDeviceGetName(device, name);
	if (err != 0) {
		LogMsg("BTDeviceGetName error: %X", err);
	} else {
		LogMsg("BTDeviceGetName()=%s", name);	
	}
	
	err = BTDeviceGetAddressString(device, addr, sizeof(addr));
	if (err != 0) {
		LogMsg("BTDeviceGetAddressString error: %X", err);
	} else {
		LogMsg("BTDeviceGetAddressString()=%s", addr);	
	}
	
	
	err = BTDeviceSetAuthorizedServices(device, BT_SERVICE_BRAILLE);
	if (err != 0) {
		LogMsg("BTDeviceSetAuthorizedServices error: %X", err);
	}
	
	err = BTDeviceGetSupportedServices(device, &svc);
	if (err != 0) {
		LogMsg("BTDeviceGetSupportedServices error: %X", err);
	} else {
		LogMsg("BTDeviceGetSupportedServices(): %X", svc);
	}
	
	if (is_target_device(name, addr)) {
		bc.device = device;
		start_pairing(bc);
	}
}

void localStatusEventCallback(BTLOCALDEVICE* localDevice, BT_LOCAL_DEVICE_EVENT event, void* unk1, void* ctx)
{
	BluetoothContext* bc = (BluetoothContext*)ctx;
	assert(bc == g_bc);
	
	LogMsg("localStatusEventCallback(localdev:%p, event:%s, unk1:%p, ctx:%p)", 
		   localDevice, LocalEventString(event), unk1, ctx);
	if (event == BT_LOCAL_DEVICE_POWER_STATE_CHANGED) {
		onPowerOn(bc);
	}
}

void* btThreadProc(void* arg)
{
	NSAutoreleasePool* ap = [[NSAutoreleasePool alloc] init];
	NSRunLoop* rl = [NSRunLoop currentRunLoop]; 
	SESSION_CALLBACKS sessionCallbacks = {sessionEventCallback};
	BluetoothContext* bc = [[BluetoothContext alloc]init];
	LogMsg("BluetoothContext = %p", bc);
	g_bc = bc;

	BTSESSION ses;
	int err;
	err = BTSessionAttachWithRunLoopAsync(CFRunLoopGetCurrent(), "com.apple.something2", &sessionCallbacks, bc, &ses);
	if (err != 0) {
		LogMsg("BTSessionAttachWithRunLoop error: %X", err);
		return NULL;
	}
	[rl run];
	[ap release];
	return NULL;
}

void btStartThreadOnce()
{
	pthread_t pt;
	int result = pthread_create(&pt, NULL, btThreadProc, NULL);
	LogMsg("btStartThreadOnce: pthread_create() = %i", result);
}

void btStartThread()
{
	static pthread_once_t startBtThread = PTHREAD_ONCE_INIT;
	LogMsg("btStartThread()");
	pthread_once(&startBtThread, btStartThreadOnce);
}

void onPowerOn(BluetoothContext* bc) 
{
	int err;
	if (strlen(g_macAddr) != 0) {
		char macAddr[6];
		err = BTDeviceAddressFromString(g_macAddr, macAddr); 
		if (err != 0) {
			LogMsg("BTDeviceAddressFromString error: %X", err);
			return;
		}	
		LogMsg("BTDeviceAddressFromString OK");
		
		BTDEVICE device;
		err = BTDeviceFromAddress(bc.session, macAddr, &device);
		if (err != 0) {
			LogMsg("BTDeviceFromAddress error: %X", err);
		} else {
			LogMsg("BTDeviceFromAddress OK: 0x%p", device);
			bc.device = device;
		}
	}
	
	if (bc.device == NULL)
	{
		err = BTDiscoveryAgentStartScan(bc.discoveryAgent, 1, ~0x0);
		if (err != 0) {
			LogMsg("BTDiscoveryAgentStartScan error: %X", err);
			return;
		}	
		LogMsg("BTDiscoveryAgentStartScan OK");
	}
	
	if (bc.pairingAgent != NULL) {
		err = BTPairingAgentStart(bc.pairingAgent);
		if (err != 0) {
			LogMsg("BTPairingAgentStart error: %X", err);
			return;
		}
		LogMsg("BTPairingAgentStart OK");
	}
	
	if (bc.device) {
		start_pairing(bc);
	}	
}

void btTest(BTSESSION session, BluetoothContext* bc)
{
	BTDISCOVERYAGENT discoveryAgent;
	DISCOVERY_CALLBACKS discoveryCallbacks = {discoveryStatusCallback, discoveryEventCallback};
	PAIRING_AGENT_CALLBACKS pairingAgentCallbacks = {pairingAgentStatusCallback, pairingPincodeCallback, pairingAuthorizationCallback, 
		pairingUserConfirmationCallback, pairingPasskeyDisplayCallback};
	LOCAL_DEVICE_CALLBACKS localDeviceCallbacks = {localStatusEventCallback};
	PAIRING_AGENT pairingAgent;
	BTLOCALDEVICE localDevice;
	
	bc.session = session;
	int err;
	
	err = BTLocalDeviceGetDefault(bc.session, &localDevice);
	if (err != 0) {
		LogMsg("BTLocalDeviceGetDefault error: %X", err);
		return;
	}
	LogMsg("BTLocalDeviceGetDefault OK(%p)", localDevice);	
	
	err = BTLocalDeviceAddCallbacks(localDevice, &localDeviceCallbacks, bc);
	if (err != 0) {
		LogMsg("BTLocalDeviceAddCallbacks error: %X", err);
		return;
	}
	LogMsg("BTLocalDeviceAddCallbacks OK");
	
	bc.localDevice = localDevice;
	
	int powerStatus = 0;
	
	err = BTLocalDeviceGetModulePower(localDevice, 1, &powerStatus);
	if (err !=  0) {
		LogMsg("BTLocalDeviceGetModulePower error: %X", err);
		return;
	}
	LogMsg("Power status: %s", powerStatus ? "ON" : "OFF");
	
	if (powerStatus == 0) {
		err = BTLocalDeviceSetModulePower(localDevice, 1);
		if (err !=  0) {
			LogMsg("BTLocalDeviceSetModulePower error: %X", err);
			return;
		}
		LogMsg("Turned on BT!");
	}
	
	
	err = BTServiceAddCallbacks(session, serviceEventCallback, bc);
	if (err != 0) {
		LogMsg("BTServiceAddCallbacks error: %X", err);
		return;
	}
	LogMsg("BTServiceAddCallbacks OK");	
	
	err = BTDiscoveryAgentCreate(session, &discoveryCallbacks, bc, &discoveryAgent);
	if (err != 0) {
		LogMsg("BTDiscoveryAgentCreate error: %X", err);
		return;
	}
	LogMsg("BTDiscoveryAgentCreate OK (%p)", discoveryAgent);
	
	bc.discoveryAgent = discoveryAgent;
	
	err = BTPairingAgentCreate(session, &pairingAgentCallbacks, bc, &pairingAgent);
	if (err != 0) {
		LogMsg("BTPairingAgentCreate error: %X", err);
	} else {
		LogMsg("BTPairingAgentCreate OK (%p)", pairingAgent);
		bc.pairingAgent = pairingAgent;
	}
	
	if (powerStatus != 0) {
		onPowerOn(bc);
	}
}


