//
//  main.m
//  locationd-inject
//
//  Created by svp on 7/28/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#include <Foundation/NSNotification.h>
#include "substrate.h"
#include "EALocationAccessory.h"

@interface EAAccessoryManager(Prefix)
-(void)BTGPS_setAreLocationAccessoriesEnabled:(bool)enable;
@end;


extern "C" void dlinit();

static const char* MESSAGE_PREFIX = "BTGPS_";

static void $EAAccessoryManager$setAreLocationAccessoriesEnabled$(EAAccessoryManager *self, SEL sel, bool enable)
{
	NSLog(@"-[EAAccessoryManager setAreLocationAccessoriesEnabled:%i]", enable);
	[self BTGPS_setAreLocationAccessoriesEnabled:enable];
	if (enable) {
		[EALocationAccessory start];
	} else {
		[EALocationAccessory stop];	
	}
}


void dlinit() {
	NSLog(@"GPS injection library loaded into locationd!");
	Class eaAccessoryManagerClass = objc_getClass("EAAccessoryManager");
	if (eaAccessoryManagerClass == nil) {
		NSLog(@"EAAccessoryManager class not found, bailing!");
		return;
	}
	MSHookMessage(eaAccessoryManagerClass, @selector(setAreLocationAccessoriesEnabled:), $EAAccessoryManager$setAreLocationAccessoriesEnabled$, MESSAGE_PREFIX);
}
