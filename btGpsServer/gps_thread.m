/*
 *  gps_thread.c
 *  btGpsServer
 *
 *  Created by msftguy on 6/26/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#include "gps_thread.h"
#include "log.h"

#include <pthread.h>

#include <Foundation/NSAutoReleasePool.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSPort.h>

GpsThread* g_gpsThread;

NSString* GpsConnectedNotification = @"GpsConnected";
NSString* GpsTty = @"Tty";

@implementation GpsThread

- (id) init
{
	assert(g_gpsThread == nil);
	g_gpsThread = self;
	
	NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self 
		   selector:@selector(gpsConnected:)
			   name:@"GpsConnected"
			 object:nil];
	
	return self;
}

- (void) readCompletionNotification:(NSNotification*)notification
{
	NSFileHandle* handle = [notification object];
	NSDictionary* userInfo = [notification userInfo];

	NSData* readData = [userInfo valueForKey:NSFileHandleNotificationDataItem];
	NSNumber* error = [userInfo valueForKey:@"NSFileHandleError"];

	NSString* logMessage = [NSString stringWithFormat:@"Data: %@", readData];
	LogMsg("readCompletionNotification: %s, error: %u", [logMessage cStringUsingEncoding:NSASCIIStringEncoding], [error intValue]);
	if (error == 0) {
		//read more data
		[handle readInBackgroundAndNotify]; 
	} else {
		NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
		[nc removeObserver:self name:NSFileHandleReadCompletionNotification object:handle];
		[handle release];
	}

}


- (void) gpsConnected:(NSNotification*)notification
{
	NSDictionary* userInfo = [notification userInfo];
	NSString* tty = [userInfo valueForKey:GpsTty];
	NSString* logMessage = [NSString stringWithFormat:@"Tty: %@", tty];
	
	LogMsg("gpsConnected: %s", [logMessage cStringUsingEncoding:NSASCIIStringEncoding]);
	[self openTty:tty];
}

- (void) openTty:(NSString*)ttyPath 
{
	NSFileHandle* handle = [NSFileHandle fileHandleForReadingAtPath:ttyPath];
	if (handle == nil) {
		NSString* logMessage = [NSString stringWithFormat:@"fileHandleForReadingAtPath(%@) failed", ttyPath];
		LogMsg("openTty: %s", [logMessage cStringUsingEncoding:NSASCIIStringEncoding]);
		return;
	}
	NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
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
	[[GpsThread alloc] init]; 

	[rl run];
	[ap release];
	return NULL;
}

void gpsStartThreadOnce()
{
	pthread_t pt;
	pthread_create(&pt, NULL, gpsThreadProc, NULL);
}

void gpsStartThread()
{
	pthread_once_t gpsThreadOnce = PTHREAD_ONCE_INIT;
	pthread_once(&gpsThreadOnce, gpsStartThreadOnce);
}