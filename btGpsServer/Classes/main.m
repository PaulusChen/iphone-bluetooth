//
//  btTestAppDelegate.m
//  btTest
//
//  Created by msftguy on 11/16/09.
//  Copyright __MyCompanyName__ 2009. All rights reserved.
//

#include "bt_main.h"
#include "launchd.h"
#include "gps_thread.h"
#include "shm_gpsinfo.h"
#include "log.h"

//--------------------------------------------

int main(int argc, char *argv[]) {
    printf("Server Started!\n");
	fflush(stdout);
	
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSRunLoop* runLooop = [NSRunLoop currentRunLoop]; 
	launchd_checkin();
	if (!shm_ensure()) {
		LogMsg("FATAL: shm_ensure FAILED, bailing out!");
		return 0;
	}
	btStartThread();
	gpsStartThread();
	[runLooop run];
	[pool release];
    return 0;
}


