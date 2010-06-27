//
//  BluetoothContext.m
//  btTest
//
//  Created by msftguy on 6/25/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "BluetoothContext.h"
#include "bt_main.h"


@implementation BluetoothContext

@synthesize session;
@synthesize device;
@synthesize discoveryAgent;
@synthesize pairingAgent;
@synthesize localDevice;
@synthesize discoveryInProgress;
@synthesize connected;

@synthesize magic;

-(id) init
{
	session = NULL;
	device = NULL;
	discoveryAgent = NULL;
	pairingAgent = NULL;
	localDevice = NULL;
	discoveryInProgress = false;
	connected = false;	
	
	magic = 0xdeadbeef;
	return self;
}


- (void) timerProc:(NSObject*) ctx
{
	if (!connected && g_targetState) {
		int err;
		if (device == NULL && discoveryAgent && !discoveryInProgress) {
			err = BTDiscoveryAgentStartScan(discoveryAgent, 1, ~0x0);
			if (err != 0) {
				printf("[timer]BTDiscoveryAgentStartScan error: %X\n", err);
				return;
			}	
			printf("[timer]BTDiscoveryAgentStartScan OK\n");
		} else if (device != NULL) {
			start_pairing(self);
		}
	}
}

@end

