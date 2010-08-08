//
//  main.m
//  bbinj
//
//  Created by msftguy on 5/31/10.
//  Copyright __MyCompanyName__ 2010. All rights reserved.
//

#include "main.h"
#include <mach-o/dyld.h>


int dlInit()
{
	log_progress("Injection library initialized");
	const char* imageName = _dyld_get_image_name(0);
	if (nil == strcasestr(imageName, "BTServer")) {
		log_progress("Injection library loaded in %s, idle", imageName);
		return 0;
	}
	log_progress("dlInit/reportBoot"); 

	safe_reportBoot();
	
	log_progress("dlInit/1"); 
	
	if (!safe_canRun()) {
		log_progress("dlInit/SAFE MODE; BYE"); 
		NSLog(@"Safe mode is ON, bbye!");
		return 0;
	}
	
	log_progress("dlInit/safe is OK"); 

	setup_hooks();

	log_progress("dlInit/leaving"); 

	return 0;
}

