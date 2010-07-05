/*
 *  api_wrappers.h
 *  btGpsClient
 *
 *  Created by msftguy on 6/26/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#include <mach/mach.h>

kern_return_t get_server_port(mach_port_t* serverPort);

void print_scan_results(void* buf, size_t cbBuf);
