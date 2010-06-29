/*
 *  srv_api.m
 *  btTest
 *
 *  Created by msftguy on 6/26/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#include "srv_api.h"
#include "bt_main.h"
#include "BluetoothContext.h"
#include "log.h"


/* get version */
kern_return_t srv_get_version(mach_port_t server, int32_t* pVersion)
{	
	LogMsg("srv_get_version called");
	*pVersion = 42;
	return KERN_SUCCESS;
}

/* set pin code */
kern_return_t srv_set_pin(mach_port_t server, str80 pin, mach_msg_type_number_t pinCnt)
{
	LogMsg("srv_set_pin(%s) called", pin);
	[BluetoothContext	 
	 postNotificationWithKey:BtPinKey
	 value:[NSString stringWithFormat:@"%.*s",pinCnt, pin]];
	return KERN_SUCCESS;
}

/* set device name */
kern_return_t srv_set_name(mach_port_t server, str80 name, mach_msg_type_number_t nameCnt)
{
	LogMsg("srv_set_name(%s) called", name);
	[BluetoothContext	 
	 postNotificationWithKey:BtNameKey
	 value:[NSString stringWithFormat:@"%.*s", nameCnt, name]];
	return KERN_SUCCESS;
}

/* set device address */
kern_return_t srv_set_addr(mach_port_t server, str80 addr, mach_msg_type_number_t addrCnt)
{
	LogMsg("srv_set_addr(%s) called", addr);
	[BluetoothContext	 
	 postNotificationWithKey:BtAddressKey
	 value:[NSString stringWithFormat:@"%.*s", addrCnt, addr]];
	return KERN_SUCCESS;
}

kern_return_t srv_set_need_gps(mach_port_t server, boolean_t needGps)
{
	LogMsg("srv_set_need_gps(%s)", needGps ? "TRUE" : "FALSE");
	BtState targetState = needGps ? BtStateConnected : BtStatePowerKeep; 
	[BluetoothContext	 postNotificationWithKey:BtTargetStateKey
										 value:[NSNumber 
												numberWithInt:targetState]];
	return KERN_SUCCESS;
}
