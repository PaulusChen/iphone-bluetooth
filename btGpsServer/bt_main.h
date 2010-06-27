/*
 *  bt_main.h
 *  btTest
 *
 *  Created by msftguy on 6/25/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#include "MobileBluetooth.h"
#import "BluetoothContext.h"


extern char g_pin[BUFSIZ];
extern char g_macAddr[BUFSIZ];
extern char g_devName[BUFSIZ];
extern bool g_targetState;

#ifdef __cplusplus
extern "C" {
#endif

	void btStartThread();
	void start_pairing(BluetoothContext* bc);
	void btTest(BTSESSION session, BluetoothContext* bc);
	void onPowerOn(BluetoothContext* bc);

#ifdef __cplusplus
}
#endif
