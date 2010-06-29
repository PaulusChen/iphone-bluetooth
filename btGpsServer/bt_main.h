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

extern BluetoothContext* g_bc;

#ifdef __cplusplus
extern "C" {
#endif

	void btStartThread();
	void onPowerOn(BluetoothContext* bc);

#ifdef __cplusplus
}
#endif
