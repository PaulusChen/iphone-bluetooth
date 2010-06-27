//
//  btTestAppDelegate.m
//  btTest
//
//  Created by msftguy on 11/16/09.
//  Copyright __MyCompanyName__ 2009. All rights reserved.
//

#include "bt_main.h"
#include "launchd.h"

//--------------------------------------------

int main(int argc, char *argv[]) {
    printf("Server Started!\n");
	fflush(stdout);
	
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSRunLoop* runLooop = [NSRunLoop currentRunLoop]; 
	launchd_checkin();
	btStartThread();
	[runLooop run];
	[pool release];
    return 0;
}


