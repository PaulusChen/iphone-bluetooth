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
#include "log.h"
#include "gps_thread.h"
#include <pthread.h>
//
//char g_pin[BUFSIZ] = "0000";
//char g_macAddr[BUFSIZ] = "";
//char g_devName[BUFSIZ] = "";
//bool g_targetState = false;

BluetoothContext* g_bc = NULL;
//--------------------------------------------

void* btThreadProc(void* arg)
{
	NSAutoreleasePool* ap = [[NSAutoreleasePool alloc] init];
	NSRunLoop* rl = [NSRunLoop currentRunLoop]; 
	BluetoothContext* bc = [[BluetoothContext alloc]init];
	LogMsg("BluetoothContext = %p", bc);
	g_bc = bc;
	if (![bc reconnectSession])  {
		LogMsg("btThreadProc: FAILED to connect to BT server session, bailing!");
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


