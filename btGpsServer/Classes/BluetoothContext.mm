//
//  BluetoothContext.m
//  btTest
//
//  Created by msftguy on 6/25/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "BluetoothContext.h"
#include "bt_main.h"
#include "bt_helpers.h"
#include "gps_thread.h"
#include "log.h"

int sessionEventCallback(BTSESSION session, BTSessionEvent sessionEvent, BTResult result, void* ctx);

void localStatusEventCallback(BTLOCALDEVICE* localDevice, BT_LOCAL_DEVICE_EVENT event, void* unk1, void* ctx);

void serviceEventCallback(BTDEVICE device, BT_SERVICE_TYPE serviceType, SERVICE_EVENT_TYPE eventType, SERVICE_EVENT event, int result, void* ctx);

void discoveryStatusCallback(BTDISCOVERYAGENT agent, BT_DISCOVERY_STATUS status, BTDEVICE device, int result, void* ctx);
void discoveryEventCallback(BTDISCOVERYAGENT agent, BT_DISCOVERY_EVENT event, 
							BTDEVICE device, BTDeviceAttributes attr, void* ctx);

void pairingAgentStatusCallback(PAIRING_AGENT agent, BT_PAIRING_AGENT_STATUS status, BTDEVICE device, int PairingResult, void* ctx);
void pairingPincodeCallback(PAIRING_AGENT agent, BTDEVICE device, uint8_t unk1, void* ctx);
void pairingAuthorizationCallback(PAIRING_AGENT agent, BTDEVICE device, BTServiceMask serviceMask, void* ctx);
void pairingUserConfirmationCallback(PAIRING_AGENT agent, BTDEVICE device, uint32_t unk1, BTBool unk2, void* ctx);
void pairingPasskeyDisplayCallback(PAIRING_AGENT agent, BTDEVICE device, uint32_t unk1, void* ctx);


@implementation BluetoothContext

@synthesize session;
@synthesize device;
@synthesize discoveryAgent;
@synthesize pairingAgent;
@synthesize localDevice;
@synthesize targetName;
@synthesize targetAddr;
@synthesize targetPin;


@synthesize magic;

+ (void) postNotificationWithKey:(NSString*)key value:(id)value
{
	
	NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
	
	NSDictionary* userInfo = 
	[NSDictionary dictionaryWithObjectsAndKeys:value, key, nil];
	[nc postNotificationName:BluetoothConfigChangeNotification object:g_bc userInfo:userInfo];
}

- (id) init
{
	session = NULL;
	device = NULL;
	discoveryAgent = NULL;
	pairingAgent = NULL;
	localDevice = NULL;
	currentState = BtStatePowerKeep;
	targetState = BtStatePowerKeep;
	targetName = @"";
	targetAddr = @"";
	targetPin = @"";
	
	magic = 0xdeadbeef;
	
	NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
	[nc
		addObserver:self
			selector:@selector(BluetoothConfigChanged:) 
				name:BluetoothConfigChangeNotification
			  object:nil];
	return self;
}

- (void) BluetoothConfigChanged:(NSNotification*)notification
{
	NSDictionary* userInfo = [notification userInfo];
	NSNumber* newTsVal = [userInfo valueForKey:BtTargetStateKey];
	NSString* pin = [userInfo valueForKey:BtPinKey];
	NSString* name = [userInfo valueForKey:BtNameKey];
	NSString* addr = [userInfo valueForKey:BtAddressKey];
	if ([pin length] != 0) {
		self.targetPin = pin;
	}
	if ([name length] != 0) {
		self.targetName = name;
	}
	if ([addr length] != 0) {
		self.targetAddr = addr;
	}
	if (newTsVal != nil) {
		BtState newTargetState = (BtState)[newTsVal intValue];
		targetState = newTargetState;
		[self onStateChange];
	}	
}

- (void) onStateChange
{
	int direction = currentState > targetState ? -1 : currentState == targetState ? 0 : 1;
	switch (currentState) {
		case BtStatePowerKeep:
			break;
		case BtStatePowerOff:
			if (direction > 0) {
				[self fsmPowerOff2On];
			}
			break;
		case BtStatePowerOn:
			if (direction < 0) {
				[self fsmPowerOn2Off];
			} else if (direction > 0) {
				[self fsmPowerOn2Scan];
			}
			break;
		case BtStateScan:
			if (direction < 0) {
				[self fsmScan2PowerOn];
			} else if (direction > 0) {
				[self fsmScan2Connecting];
			}
			break;
		case BtStateConnecting:
			if (direction < 0) {
				[self fsmConnecting2Scan];
			} else if (direction > 0) {
				[self fsmConnecting2Connected];
			}
//		case BtStatePairing:
//			if (direction < 0) {
//				[self fsmPairing2Connecting];
//			} else if (direction > 0) {
//				[self fsmPairing2Connected];
//			}
//			break;
		case BtStateConnected:
			if (direction < 0) {
				[self fsmConnected2Connecting];
			}
			break;
		default:
			LogMsg("Invalid state: %u", currentState);
			assert(FALSE);
			break;
		}
}

- (void) fsmPowerOff2On
{
	[self setPowerState:YES];
}

- (void) fsmPowerOn2Off
{
	[self setPowerState:NO];
}

- (void) fsmPowerOn2Scan
{
	if (![self tryCreateTargetDevice]) {
		[self setScanEnabled:YES];
	}
}

- (void) fsmScan2PowerOn
{
	[self setScanEnabled:NO];	
}

- (void) fsmScan2Connecting
{
	[self connectDisconnect:YES];
}

- (void) fsmConnecting2Scan
{
	[self connectDisconnect:NO];
}

- (void) fsmConnecting2Connected
{
	[self connectDisconnect:YES];
}

- (void) fsmConnected2Connecting
{
	[self connectDisconnect:NO];
}

- (bool) getPowerState
{
	int currentPowerState = 0;

	int err = BTLocalDeviceGetModulePower(localDevice, 1, &currentPowerState);
	if (err !=  0) {
		LogMsg("getPowerState: BTLocalDeviceGetModulePower error: 0x%x", err);
		return NO;
	}
	return !!currentPowerState;
}

- (void) setPowerState:(BOOL)targetPowerState
{	
	bool currentPowerState = [self getPowerState];
	if (targetPowerState != currentPowerState) {
		int err = BTLocalDeviceSetModulePower(localDevice, targetPowerState ? 1 : 0);
		if (err !=  0) {
			LogMsg("setPowerState: BTLocalDeviceSetModulePower(%i->%i) error: 0x%x", 
				   currentPowerState, targetPowerState, err);
			return;
		}
	}
}

- (void) setScanEnabled:(BOOL)scanEnabled
{
	int err;
	if (scanEnabled) {
		err = BTDiscoveryAgentStartScan(discoveryAgent, 1, ~0x0);
		if (err != 0) {
			LogMsg("setScanEnabled: BTDiscoveryAgentStartScan error: 0x%x", err);
			return;
		}	
		LogMsg("setScanEnabled: BTDiscoveryAgentStartScan OK");
	} else {
		err = BTDiscoveryAgentStopScan(discoveryAgent);
		if (err != 0) {
			LogMsg("setScanEnabled: BTDiscoveryAgentStopScan error: 0x%x", err);
			return;
		}	
		LogMsg("setScanEnabled: BTDiscoveryAgentStartScan OK");
	}
}

- (void) startStopPairingAgent:(BOOL)start
{
	if (pairingAgent != nil) {
		LogMsg("startStopPairingAgent: %s", start ? "YES" : "NO");
		if (start) {
			int err = BTPairingAgentStart(pairingAgent);
			if (err != 0) {
				LogMsg("BTPairingAgentStart error: %X", err);
				return;
			}
			LogMsg("BTPairingAgentStart OK");
		} else {
			int err = BTPairingAgentStop(pairingAgent);
			if (err != 0) {
				LogMsg("BTPairingAgentStop error: %X", err);
				return;
			}
			LogMsg("BTPairingAgentStop OK");
		}
	}
}

- (void) connectDisconnect:(BOOL)fConnect
{
	if (fConnect) {
		[self connect];
	} else {
		int err = BTDeviceDisconnect(device);
		if (err != 0) {
			LogMsg("connectDisconnect: BTDeviceDisconnect error: %X", err);
		}
	}
}

- (void) connect 
{	
	int err; 
	
	err = BTDeviceSetAuthorizedServices(device, BT_SERVICE_BRAILLE);
	if (err != 0) {
		LogMsg("connect: BTDeviceSetAuthorizedServices error: 0x%x", err);
		return;
	}
	LogMsg("connect: BTDeviceSetAuthorizedServices OK");
	
	err = BTDeviceDisconnect(device);
	if (err != 0) {
		LogMsg("connect: BTDeviceDisconnect error: 0x%x", err);
	}
	
	if (pairingAgent != nil) {
		err = BTPairingAgentCancelPairing(pairingAgent);
		if (err != 0) {
			LogMsg("connect: BTPairingAgentCancelPairing error: 0x%x", err);
		}	
	}
	
	err = BTDeviceConnect(device);
	if (err != 0) {
		LogMsg("BTDeviceConnect error: %X", err);
		if (err == 0xA4 && pairingAgent != NULL) {
			BTPairingAgentCancelPairing(pairingAgent);
			
			err = BTDeviceConnect(device);
			if (err != 0)
			{
				LogMsg("BTDeviceConnect error: %X", err);
				return;
			}
		}
	}
	LogMsg("BTDeviceConnect OK");
	
	
	int svc;
	err = BTDeviceGetSupportedServices(device, &svc);
	if (err != 0) {
		LogMsg("BTDeviceGetSupportedServices error: %X", err);
		return;
	}	
	LogMsg("BTDeviceGetSupportedServices OK, svc=0x%X", svc);
}



- (BOOL) isTargetDeviceName:(NSString*)name addr:(NSString*)addr
{
	if ([targetName length] != 0) {
		if (0 == [targetName compare:name options:NSCaseInsensitiveSearch]) {
			return YES;
		}
	}
	if ([targetAddr length] != 0) {
		if (0 == [targetAddr compare:addr options:NSCaseInsensitiveSearch]) {
			return YES;
		}
	}
	return NO;
}

- (void) onSessionConnected:(BTSESSION)btSession
{	
	session = btSession;
	
	int err;
	
	BTLOCALDEVICE btLocalDevice;
	err = BTLocalDeviceGetDefault(session, &btLocalDevice);
	if (err != 0) {
		LogMsg("BTLocalDeviceGetDefault error: %X", err);
		return;
	}
	LogMsg("BTLocalDeviceGetDefault OK(%p)", btLocalDevice);	
	
	LOCAL_DEVICE_CALLBACKS localDeviceCallbacks = {localStatusEventCallback};
	err = BTLocalDeviceAddCallbacks(btLocalDevice, &localDeviceCallbacks, self);
	if (err != 0) {
		LogMsg("BTLocalDeviceAddCallbacks error: %X", err);
		return;
	}
	LogMsg("BTLocalDeviceAddCallbacks OK");
	
	localDevice = btLocalDevice;

	err = BTServiceAddCallbacks(session, serviceEventCallback, self);
	if (err != 0) {
		LogMsg("BTServiceAddCallbacks error: %X", err);
		return;
	}
	LogMsg("BTServiceAddCallbacks OK");	

	BTDISCOVERYAGENT btDiscoveryAgent;
	DISCOVERY_CALLBACKS discoveryCallbacks = {discoveryStatusCallback, discoveryEventCallback};

	err = BTDiscoveryAgentCreate(session, &discoveryCallbacks, self, &btDiscoveryAgent);
	if (err != 0) {
		LogMsg("BTDiscoveryAgentCreate error: %X", err);
		return;
	}
	LogMsg("BTDiscoveryAgentCreate OK (%p)", btDiscoveryAgent);
	
	discoveryAgent = btDiscoveryAgent;
	
	PAIRING_AGENT btPairingAgent;
	PAIRING_AGENT_CALLBACKS pairingAgentCallbacks = {pairingAgentStatusCallback, pairingPincodeCallback, pairingAuthorizationCallback, 
		pairingUserConfirmationCallback, pairingPasskeyDisplayCallback};
	
	err = BTPairingAgentCreate(session, &pairingAgentCallbacks, self, &btPairingAgent);
	if (err != 0) {
		LogMsg("BTPairingAgentCreate error: %X", err);
	} else {
		LogMsg("BTPairingAgentCreate OK (%p)", btPairingAgent);
		pairingAgent = btPairingAgent;
	}
	
	bool powerState = [self getPowerState];
	LogMsg("Power state: %s", powerState ? "ON" : "OFF");
	currentState = powerState ? BtStatePowerOn : BtStatePowerOff;
	
	if (currentState) {
		[self startStopPairingAgent:YES];
	}

	if (targetState == BtStatePowerKeep) {
		targetState = currentState;
	}
	[self onStateChange];
}

- (void) onSessionDisconnected
{
	int err;
	
	currentState = BtStatePowerKeep;
	device = nil;
	
	if (session == nil) {
		return;
	}
	
	if (pairingAgent != nil) {
		BTPairingAgentStop(pairingAgent);
		err = BTPairingAgentDestroy(pairingAgent);
		if (err != 0) {
			LogMsg("onSessionDisconnected: BTPairingAgentDestroy failed: 0x%x",  err);
		}
		pairingAgent = nil;
	}
	
	if (discoveryAgent != nil) {
		BTDiscoveryAgentStopScan(discoveryAgent);
		err = BTDiscoveryAgentDestroy(discoveryAgent);
		if (err != 0) {
			LogMsg("onSessionDisconnected: BTDiscoveryAgentDestroy failed: 0x%x",  err);
		}
		discoveryAgent = nil;
	}
	
	localDevice = nil;
	
	err = BTSessionDetachWithRunLoopAsync(CFRunLoopGetCurrent(), session);
	if (err != 0) {
		LogMsg("onSessionDisconnected: BTSessionDetachWithRunLoopAsync failed: 0x%x", err);
	}

	session = nil;
}

static const NSString* BtSessionKey = @"BtSessionKey";

- (void) reconnectSessionTimerProc:(NSTimer*)theTimer
{
	NSValue* nsVal = [[theTimer userInfo] valueForKey:BtSessionKey];
	BTSESSION btSession = (BTSESSION) [nsVal pointerValue];
	assert(btSession == session);
	[self reconnectSession];
}

- (bool) reconnectSession
{
	int err;
	if (session != nil) 
		[self onSessionDisconnected];

	BTSESSION ses;
	SESSION_CALLBACKS sessionCallbacks = {sessionEventCallback};
	err = BTSessionAttachWithRunLoopAsync(CFRunLoopGetCurrent(), "com.apple.something2", &sessionCallbacks, self, &ses);
	if (err != 0) {
		LogMsg("BTSessionAttachWithRunLoop error: 0x%x", err);
		return NO;
	}
	return YES;
}

- (void) onLocalPowerChanged
{
	bool newPowerState = [self getPowerState];
	if (newPowerState) {
		[self startStopPairingAgent:YES];
		if (currentState < BtStatePowerOn) {
			currentState = BtStatePowerOn;
		}
	} else {
		[self startStopPairingAgent:NO];
		currentState = BtStatePowerOff;
	}
	[self onStateChange];
}

- (BOOL) tryCreateTargetDevice
{
	if (0 == [targetAddr length]) 
		return NO;
	int err;
	char macAddr[6];
	err = BTDeviceAddressFromString(
									[targetAddr cStringUsingEncoding:NSASCIIStringEncoding],
									macAddr); 
	if (err != 0) {
		LogMsg("BTDeviceAddressFromString error: %X", err);
		return NO;
	}	
	LogMsg("BTDeviceAddressFromString OK");
	
	BTDEVICE btDevice;
	err = BTDeviceFromAddress(session, macAddr, &btDevice);
	if (err != 0) {
		LogMsg("BTDeviceFromAddress error: %X", err);
		return NO;
	} else {
		LogMsg("BTDeviceFromAddress OK: 0x%p", btDevice);
		device = btDevice;
		currentState = BtStateConnecting;
		[self onStateChange];
		return YES;
	}
}

- (void) onServiceConnected:(BT_SERVICE_TYPE)serviceType result:(int)result
{
	if (serviceType == BT_SERVICE_BRAILLE && result == 0) {
		char buf[0x100] = "";
		int err = BTDeviceGetComPortForService(device, BT_SERVICE_BRAILLE, buf, sizeof(buf));
		if (err != 0) {
			LogMsg("BTDeviceGetComPortForService error: 0x%x", err);
			return;
		}
		LogMsg("BTDeviceGetComPortForService OK: %s", buf);
		NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
		NSDictionary* userInfo = [NSDictionary 
								  dictionaryWithObject:[NSString stringWithFormat:@"%s", buf] 
								  forKey:GpsTty];
		[nc postNotificationName:GpsConnectedNotification object:g_gpsThread userInfo:userInfo];  
		currentState = BtStateConnected;
		[self onStateChange];
	} else if (result != 0 && 
			   (serviceType == BT_SERVICE_BRAILLE || serviceType == BT_SERVICE_ANY)) {
		currentState = BtStateConnecting;
		[self onStateChange];
	}
}

- (void) onServiceDisconnected:(BT_SERVICE_TYPE)serviceType result:(int)result
{
	if (serviceType == BT_SERVICE_BRAILLE) {
		currentState = BtStateConnecting;
		[self onStateChange];
	}
}

- (void) onDiscoveryStarted
{
	currentState = BtStateScan;
	[self onStateChange];
}

- (void) onDiscoveryStopped
{
	if (currentState == BtStateScan) {
		currentState = BtStatePowerOn; 
	}
	[self onStateChange];
}

- (void) onDiscoveryFoundDevice:(BTDEVICE)foundDevice event:(BT_DISCOVERY_EVENT)event attributes:(BTDeviceAttributes)attr
{
	int svc;
	char name[BUFSIZ] = "";
	int err = BTDeviceGetName(foundDevice, name);
	if (err != 0) {
		LogMsg("BTDeviceGetName error: %X", err);
	} else {
		LogMsg("BTDeviceGetName()=%s", name);	
	}
	
	char addr[BUFSIZ] = "";
	err = BTDeviceGetAddressString(foundDevice, addr, sizeof(addr));
	if (err != 0) {
		LogMsg("BTDeviceGetAddressString error: 0x%x", err);
	} else {
		LogMsg("BTDeviceGetAddressString()=%s", addr);	
	}
	
	if (![self isTargetDeviceName:[NSString stringWithCString:name encoding:NSASCIIStringEncoding]
						addr:[NSString stringWithCString:addr encoding:NSASCIIStringEncoding]]) {
		return;
	}

	device = foundDevice;
		
	err = BTDeviceGetSupportedServices(foundDevice, &svc);
	if (err != 0) {
		LogMsg("BTDeviceGetSupportedServices error: 0x%x", err);
	} else {
		LogMsg("BTDeviceGetSupportedServices(): 0x%x", svc);
	}
	
	currentState = BtStateConnecting;
	[self onStateChange];
}

- (void) onPairingStatus:(BT_PAIRING_AGENT_STATUS)status
{
	switch (status)
	{
		case BT_PAIRING_AGENT_STARTED:
			break;
		case BT_PAIRING_AGENT_STOPPED:
//			if (currentState == BtStatePairing) {
//				currentState = BtStateConnecting;
//			}
			break;
		case BT_PAIRING_ATTEMPT_COMPLETE:
			break;
		default:
			break;
	}
}

- (void) onPairingPincodeCallback
{
	const char* pin = [targetPin cStringUsingEncoding:NSASCIIStringEncoding];
	int err = BTPairingAgentSetPincode(pairingAgent, device, pin);
	if (err != 0) {
		LogMsg("BTPairingAgentSetPincode error: 0x%x", err);
		return;
	}
	LogMsg("onPairingPincodeCallback: BTPairingAgentSetPincode(%s) OK", pin);
}

@end


const static int SessionReconnectInterval = 10;

/// session callback ///

int sessionEventCallback(BTSESSION session, BTSessionEvent sessionEvent, BTResult result, void* ctx)
{
	BluetoothContext* bc = (BluetoothContext*)ctx;
	assert(bc == g_bc);
	
	LogMsg("sessionEventCallback( session:%p, BTSessionEvent:%x, BTResult:%x, magic:%x )",
		   session, sessionEvent, result, bc.magic);
	switch (sessionEvent) {
		case BTSessionEventConnectedSession:
			[bc onSessionConnected:session];
			break;
		case BTSessionEventDisconnectedSession:
			[NSTimer scheduledTimerWithTimeInterval:SessionReconnectInterval
											 target:bc
										   selector:@selector(reconnectSessionTimerProc:)
										   userInfo:[NSDictionary 
													 dictionaryWithObject:[NSValue valueWithPointer:session]
													 forKey:BtSessionKey]
											repeats:NO];
			 break;
		default:
			break;
	}
	
	return 0;
}

/// local device callback ///

void localStatusEventCallback(BTLOCALDEVICE* localDevice, BT_LOCAL_DEVICE_EVENT event, void* unk1, void* ctx)
{
	BluetoothContext* bc = (BluetoothContext*)ctx;
	assert(bc == g_bc);
	
	LogMsg("localStatusEventCallback(localdev:%p, event:%s, unk1:%p, ctx:%p)", 
		   localDevice, LocalEventString(event), unk1, ctx);
	if (event == BT_LOCAL_DEVICE_POWER_STATE_CHANGED) {
		[bc onLocalPowerChanged];
	}
}

/// service callback ///

void serviceEventCallback(BTDEVICE device, BT_SERVICE_TYPE serviceType, SERVICE_EVENT_TYPE eventType, SERVICE_EVENT event, int result, void* ctx)
{
	BluetoothContext* bc = (BluetoothContext*)ctx;
	assert(bc == g_bc);
	
	LogMsg("serviceEventCallback( device:%p, service:%X, eventType:%i, event:%s, result:%i, magic:%x )",
		   device, serviceType, eventType, ServiceEventString(event), result, bc.magic);

	if (device != [bc device]) {
		return;
	}
	if (eventType == SERVICE_EVENT_TYPE_CONNECTED && event == SERVICE_EVENT_CONNECTED) {
		[bc onServiceConnected:serviceType result:result];
	} else if (eventType == SERVICE_EVENT_TYPE_DISCONNECTED && event == SERVICE_EVENT_DISCONNECTION_RESULT) {
		[bc onServiceDisconnected:serviceType result:result];
	}

}

/// discovery callbacks ///

void discoveryStatusCallback(BTDISCOVERYAGENT agent, BT_DISCOVERY_STATUS status, BTDEVICE device, int result, void* ctx)
{
	BluetoothContext* bc = (BluetoothContext*)ctx;
	assert(bc == g_bc);
	
	LogMsg("discoveryStatusCallback( agent:%p, status:%s, magic: %x )", agent, DiscoveryStatusString(status), bc.magic);

	if (status == BT_DISCOVERY_STATUS_STARTED) {
		[bc onDiscoveryStarted];
	} else if (status == BT_DISCOVERY_STATUS_FINISHED) {
		[bc onDiscoveryStopped];	
	}

}

void discoveryEventCallback(BTDISCOVERYAGENT agent, BT_DISCOVERY_EVENT event, 
							BTDEVICE device, BTDeviceAttributes attr, void* ctx)
{
	BluetoothContext* bc = (BluetoothContext*)ctx;
	assert(bc == g_bc);

	LogMsg("discoveryEventCallback( agent:%p, event:%s, device:%p, attr:%x )", agent, DiscoveryEventString(event), device, attr);

	[bc onDiscoveryFoundDevice:device event:event attributes:attr];
}

/// pairing callbacks ///

void pairingAgentStatusCallback(PAIRING_AGENT agent, BT_PAIRING_AGENT_STATUS status, BTDEVICE device, int PairingResult, void* ctx) 
{
	BluetoothContext* bc = (BluetoothContext*) ctx;
	assert(bc == g_bc);
	
	LogMsg("pairingAgentStatusCallback( agent:%p, status:%s, device:%p, PairingResult:%i, magic:%x )", 
		   agent, PairingStatusString(status), device, PairingResult, bc.magic);
	
	[bc onPairingStatus:status];
	return;
}

void pairingPincodeCallback(PAIRING_AGENT agent, BTDEVICE device, uint8_t unk1, void* ctx) 
{
	BluetoothContext* bc = (BluetoothContext*) ctx;
	assert(bc == g_bc);
	LogMsg("pairingPincodeCallback( agent:%p, device:%p, unk1:%x, magic:%x )", agent, device, unk1, bc.magic);

	[bc onPairingPincodeCallback];
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
