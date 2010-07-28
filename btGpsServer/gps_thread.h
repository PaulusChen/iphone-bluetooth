/*
 *  gps_thread.h
 *  btGpsServer
 *
 *  Created by msftguy on 6/26/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#include <nmea/nmea.h>

@interface GpsThread : NSObject {
	nmeaPARSER nmeaParser;
	nmeaINFO nmeaInfo;
}
- (void) threadProc:(void*) ctx;
- (void) timerProc:(NSTimer*)timer;

- (id) init;
- (void) dealloc;
- (void) readCompletionNotification:(NSNotification*)notification;
- (void) gpsConnected:(NSNotification*)notification;
- (void) openTty:(NSString*)ttyPath;

@end

extern GpsThread* g_gpsThread;

extern NSString* GpsConnectedNotification;
extern NSString* GpsTty;

void enableNmeaLog(bool fEnable);

void gpsStartThread();