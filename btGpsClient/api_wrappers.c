/*
 *  api_wrappers.c
 *  btGpsClient
 *
 *  Created by msftguy on 6/26/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#include "api_wrappers.h"
#include "btGps.h"
#include "BtGpsDefs.h"
#include "log.h"

#include <mach/task.h>
#include <mach/mach.h>
#include <mach/mach_error.h>
#include "bootstrap.h"

#include <stdio.h>

kern_return_t get_server_port(mach_port_t* serverPort) 
{
	*serverPort = 0;
	kern_return_t result;
	mach_port_t bootstrap_port, server_port;
	result = task_get_bootstrap_port(mach_task_self(), &bootstrap_port);
	if (result != KERN_SUCCESS) {
		LogMsg("task_get_bootstrap_port failed: %x\n", result);
		return result;
	}
	result = bootstrap_look_up(bootstrap_port, BTGPS_MACH_PORT_NAME, &server_port);
	if (result != KERN_SUCCESS) {
		LogMsg("bootstrap_look_up failed: %x\n", result);
		return result;
	}
	*serverPort = server_port;
	return KERN_SUCCESS;
}
