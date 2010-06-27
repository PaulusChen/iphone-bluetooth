/*
 *  gps_thread.c
 *  btGpsServer
 *
 *  Created by msftguy on 6/26/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#include "gps_thread.h"

#include <pthread.h>

#include <Foundation/NSAutoReleasePool.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSPort.h>

@implementation GpsThread

- (void) threadProc:(NSObject*) ctx 
{
	
}

- (id) init
{
	return self;
}

- (void) readCompletionNotification:(NSFileHandle*)handle
{
	
}

- (void) openTty:(const char*)path 
{
	NSFileHandle* handle = [NSFileHandle fileHandleForReadingAtPath:[NSString stringWithCString:path encoding:NSASCIIStringEncoding]];
	if (handle == nil) {
		return;
	}
	NSNotificationCenter* nc = [NSNotificationCenter defaultNotificationCenter];
	[nc addObserver:self 
		   selector:@selector(readCompletionNotification:)
			   name:NSFileHandleReadCompletionNotification
			 object:handle];
	[handle readInBackgroundAndNotify];
}


@end

void* gpsThreadProc(void* ctx)
{
	NSAutoreleasePool* ap = [[NSAutoreleasePool alloc] init];
	NSRunLoop* rl = [NSRunLoop currentRunLoop];
	
	[rl run];
	[ap release];
	return NULL;
}

void startGpsThreadOnce()
{
	pthread_t pt;
	pthread_create(&pt, NULL, gpsThreadProc, NULL);
}

void startGpsThread()
{
	pthread_once_t gpsThreadOnce = PTHREAD_ONCE_INIT;
	pthread_once(&gpsThreadOnce, startGpsThreadOnce);
}