//
//  BluetoothContext.h
//  btTest
//
//  Created by msftguy on 6/25/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "MobileBluetooth.h"


@interface BluetoothContext : NSObject {
	@private BTSESSION session;
	@private BTDEVICE device;
	@private BTDISCOVERYAGENT discoveryAgent;
	@private PAIRING_AGENT pairingAgent;
	@private BTLOCALDEVICE localDevice;
	@private bool discoveryInProgress;
	@private bool connected;
		
	@private int magic;
}

- (void) timerProc:(NSObject*) ctx;
- (id) init;

@property (readwrite, assign) BTSESSION session;
@property (readwrite, assign) BTDEVICE device;
@property (readwrite, assign) BTDISCOVERYAGENT discoveryAgent;
@property (readwrite, assign) PAIRING_AGENT pairingAgent;
@property (readwrite, assign) BTLOCALDEVICE localDevice;
@property (readwrite, assign) bool discoveryInProgress;
@property (readwrite, assign) bool connected;

@property (readwrite, assign) int magic;

@end