/*
 *  launchd.m
 *  btTest
 *
 *  Created by msftguy on 6/25/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#include "launchd.h"
#include "log.h"
#include "mach_srv.h"

#include <launch.h>

void launchd_register_mach_port(const launch_data_t portData, const char* portName, void * ctx)
{
	mach_port_t port = launch_data_get_machport(portData);
	LogOperation("Starting mach server for port %s", portName);
	start_mach_server(port);
}

void launchd_checkin(void)
{
	launch_data_t msg  = launch_data_new_string(LAUNCH_KEY_CHECKIN);
	launch_data_t resp = launch_msg(msg);
	launch_data_free(msg);
	if (!resp) { LogMsg("launch_msg returned NULL"); return; }
	
	if (launch_data_get_type(resp) == LAUNCH_DATA_ERRNO)
	{
		int err = launch_data_get_errno(resp);
		// When running on Tiger with "ServiceIPC = false", we get "err == EACCES" to tell us there's no launchdata to fetch
		if (err != EACCES) LogMsg("launch_msg returned %d", err);
		else LogOperation("Launchd provided no launchdata; will open Mach port and Unix Domain Socket explicitly...", err);
	}
	else
	{
		launch_data_t ports = launch_data_dict_lookup(resp, LAUNCH_JOBKEY_MACHSERVICES);
		if (!ports) LogMsg("launch_data_dict_lookup MachServices returned NULL");
		else
		{
			int numPorts = launch_data_dict_get_count(ports);
			if (numPorts != 1) {
				LogOperation("launch_data_dict_get_count(ports) returned %i != 1", numPorts);
			} else {
				launch_data_dict_iterate(ports, launchd_register_mach_port, NULL);
			}
		}
	}
	launch_data_free(resp);
}