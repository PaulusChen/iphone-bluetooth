/*
 *  client_test.c
 *  btGpsClient
 *
 *  Created by msftguy on 6/26/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#include "client_test.h"

#include "api_wrappers.h"
#include "log.h"
#include "btGps.h"

#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


void usage(const char* progName) {
	printf("Usage: %s [-n <device name>][-p <pin code>][-a <mac address>]\n", progName);
	exit (1);
}

char g_pin[BUFSIZ] = "";
char g_devName[BUFSIZ] = "";
char g_macAddr[BUFSIZ] = "";

void parseOptions(int argc, char *argv[])
{
	char ch;
	while ((ch = getopt(argc, argv, "p:n:a:")) != -1) {
		switch (ch) {
			case 'p':
				strcpy(g_pin, optarg);
				break;
			case 'n':
				strcpy(g_devName, optarg);
				break;
			case 'a':
				strcpy(g_macAddr, optarg);
				break;
			default:
				usage(*argv);
		}
	}
}

void client_test(int argc, char *argv[])
{
	parseOptions(argc, argv);
	mach_port_t serverPort;
	kern_return_t result;
	result = get_server_port(&serverPort);
	if (result != KERN_SUCCESS) {
		LogMsg("get_server_port() failed: 0x%x", result);
		return;
	}
	int ver;
	result = get_version(serverPort, &ver);
	if (result != KERN_SUCCESS) {
		LogMsg("set_pin get_version, 0x%x", result);
	} else {
		LogMsg("get_version() = %u", ver);
	}
	
	if (*g_pin) {
		result = set_pin(serverPort, g_pin, strlen(g_pin) + 1);
		if (result != KERN_SUCCESS) {
			LogMsg("set_pin failed, 0x%x", result);
		}
	}
	if (*g_macAddr) {
		result = set_addr(serverPort, g_macAddr, strlen(g_macAddr) + 1);
		if (result != KERN_SUCCESS) {
			LogMsg("set_addr failed, 0x%x", result);
		}
	}
	if (*g_devName) {
		result = set_name(serverPort, g_devName, strlen(g_devName) + 1);
		if (result != KERN_SUCCESS) {
			LogMsg("set_name failed, 0x%x", result);
		}
	}
	result = set_need_gps(serverPort, TRUE);
	if (result != KERN_SUCCESS) {
		LogMsg("set_need_gps failed, 0x%x", result);
	}
	
	result = get_version(serverPort, &ver);
	if (result != KERN_SUCCESS) {
		LogMsg("set_pin get_version, 0x%x", result);
	} else {
		LogMsg("get_version() = %u", ver);
	}
}