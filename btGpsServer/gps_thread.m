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
#include "shm_gpsinfo.h"

#include <nmea/nmea.h>

#include <pthread.h>
#include <fcntl.h>

#include <Foundation/NSAutoReleasePool.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSPort.h>

GpsThread* g_gpsThread = nil;

NSString* GpsConnectedNotification = @"GpsConnected";
NSString* GpsTty = @"Tty";

@implementation GpsThread

- (id) init
{
	//NMEA
	enableNmeaLog(true);
	nmea_zero_INFO(&nmeaInfo);
	nmea_parser_init(&nmeaParser);
	
	return self;
}

- (void) dealloc
{
	nmea_parser_destroy(&nmeaParser);

	[super dealloc];
}

- (void) processNmea:(NSData*)data
{	
	nmeaInfo.smask = 0;
	const char* dataBytes = [data bytes];
	size_t dataSize = [data length];
	int cParsedPackets = nmea_parse(&nmeaParser, dataBytes, dataSize, &nmeaInfo);
	
	LogMsg("processNmea: nmea_parse returned %u", cParsedPackets);

	shm_post_update(&nmeaInfo, dataBytes, dataSize);
	
	nmeaTIME* utc = &nmeaInfo.utc;
	LogMsg("processNmea: nmeaInfo: lat=%f, lon=%f, elev=%f; gmt=%02u:%02u:%02u", 
		   nmeaInfo.lat, nmeaInfo.lon, nmeaInfo.elv, utc->hour, utc->min, utc->sec); 
}

- (void) readCompletionNotification:(NSNotification*)notification
{
	NSFileHandle* handle = [notification object];
	NSDictionary* userInfo = [notification userInfo];

	NSData* readData = [userInfo valueForKey:NSFileHandleNotificationDataItem];
	NSNumber* error = [userInfo valueForKey:@"NSFileHandleError"];
	int errorCode = [error intValue];
	size_t cbRead = [readData length];
	
	LogMsg("readCompletionNotification: %li bytes, error: %u", cbRead, errorCode);
	
	if (errorCode == 0 && cbRead != 0) {
		[self processNmea:readData];
		[handle readInBackgroundAndNotify]; 
	} else {
		LogMsg("readCompletionNotification: closing tty!");
		NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
		[nc removeObserver:self name:NSFileHandleReadCompletionNotification object:handle];
		LogMsg("readCompletionNotification: handle retain count is %u", 
			   [handle retainCount]);
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
	int fd = open([ttyPath cStringUsingEncoding:NSASCIIStringEncoding], O_RDWR | O_NOCTTY);
	if (fd == -1) {
		LogMsg("openTty(%s): error 0x%x", [ttyPath cStringUsingEncoding:NSASCIIStringEncoding], errno);		
		return;
	}
	NSFileHandle* handle = [[NSFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:YES];
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
	[handle release];
}

- (void) timerProc:(NSTimer*)timer
{
	
}

- (void) threadProc:(void*) ctx
{
	LogMsg("gpsThreadProc STARTED");
	NSRunLoop* runLoop = [NSRunLoop currentRunLoop];
	
	assert(g_gpsThread == nil);
	g_gpsThread = self; 

	NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self 
		   selector:@selector(gpsConnected:)
			   name:@"GpsConnected"
			 object:nil];
	
	[runLoop addTimer:[[NSTimer alloc] initWithFireDate:[NSDate distantFuture] interval:0 target:self selector:@selector(timerProc:) userInfo:nil repeats:NO] forMode:NSRunLoopCommonModes];
	
	for (;;) {
		[runLoop run];
		LogMsg("gpsThreadProc RUNLOOP EXIT!!");
	}
}


@end


void nmea_trace_func(const char *str, int str_size)
{
	LogMsg("nmea_trace: %.*s", str_size, str);
}

void nmea_error_func(const char *str, int str_size)
{
	LogMsg("NMEA ERROR: %.*s", str_size, str);
}

void enableNmeaLog(bool enable)
{
	if (enable) {
		nmea_property()->trace_func = &nmea_trace_func;
		nmea_property()->error_func = &nmea_error_func;
	} else {
		nmea_property()->trace_func = nil;
		nmea_property()->error_func = nil;
	}
}

void gpsStartThreadOnce()
{
	[NSThread detachNewThreadSelector:@selector(threadProc:) toTarget:[[GpsThread alloc] init] withObject:nil];
}

static pthread_once_t s_gpsThreadOnce = PTHREAD_ONCE_INIT;

void gpsStartThread()
{
	pthread_once(&s_gpsThreadOnce, gpsStartThreadOnce);
}