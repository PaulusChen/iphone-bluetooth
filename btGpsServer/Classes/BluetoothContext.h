//
//  BluetoothContext.h
//  btTest
//
//  Created by msftguy on 6/25/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "MobileBluetooth.h"

typedef enum {
	BtStatePowerKeep,
	BtStatePowerOff,
	BtStatePowerOn,
	BtStateScan,
	BtStateConnecting,
//	BtStatePairing,
	BtStateConnected,
} BtState;

#define BluetoothConfigChangeNotification @"BluetoothConfigChangeNotification"

#define BtTargetStateKey @"BtTargetStateKey"
#define BtPinKey @"BtPinKey"
#define	BtNameKey @"BtNameKey"
#define	BtAddressKey @"BtAddressKey"


@interface BluetoothContext : NSObject {
	@private BTSESSION session;
	@private BTDEVICE device;
	@private BTDISCOVERYAGENT discoveryAgent;
	@private PAIRING_AGENT pairingAgent;
	@private BTLOCALDEVICE localDevice;
	@private BtState targetState;
	@private BtState currentState;
	@private NSString* targetName;
	@private NSString* targetAddr;
	@private NSString* targetPin;
	
	@private int magic;
}

+ (void) postNotificationWithKey:(NSString*)key value:(id)value;
- (id) init;
- (void) BluetoothConfigChanged:(NSNotification*)notification;

- (void) onSessionConnected:(BTSESSION)btSession;
- (void) onSessionDisconnected;
- (void) reconnectSessionTimerProc:(NSTimer*)theTimer;
- (bool) reconnectSession;
- (void) onPairingStatus:(BT_PAIRING_AGENT_STATUS)status;
- (void) onPairingPincodeCallback;



- (void) onStateChange;

- (void) fsmPowerOff2On;
- (void) fsmPowerOn2Off;
- (void) fsmPowerOn2Scan;
- (void) fsmScan2PowerOn;
- (void) fsmScan2Connecting;
- (void) fsmConnecting2Scan;
- (void) fsmConnecting2Connected;
//- (void) fsmPairing2Connecting;
//- (void) fsmPairing2Connected;
- (void) fsmConnected2Connecting;

- (void) setPowerState:(BOOL)targetPowerState;
- (void) setScanEnabled:(BOOL)scanEnabled;
- (BOOL) tryCreateTargetDevice;
- (void) connectDisconnect:(BOOL)fConnect;
- (void) startStopPairingAgent:(BOOL)start;


- (void) connect;

- (BOOL) isTargetDeviceName:(NSString*)name addr:(NSString*)addr;

@property (readwrite, assign) BTSESSION session;
@property (readwrite, assign) BTDEVICE device;
@property (readwrite, assign) BTDISCOVERYAGENT discoveryAgent;
@property (readwrite, assign) PAIRING_AGENT pairingAgent;
@property (readwrite, assign) BTLOCALDEVICE localDevice;
@property (readwrite, retain) NSString* targetName;
@property (readwrite, retain) NSString* targetAddr;
@property (readwrite, retain) NSString* targetPin;

@property (readwrite, assign) int magic;

@end