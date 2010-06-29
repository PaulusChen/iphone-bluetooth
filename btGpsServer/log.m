/*
 *  log.m
 *  btTest
 *
 *  Created by msftguy on 6/25/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#include <stdarg.h>
#include "log.h"

void LogOperation(const char* fmt,...)
{
	va_list valist;
	va_start(valist, fmt);
	vprintf(fmt, valist);
	printf("\n");
	fflush(stdout);
	va_end(valist);
}

void LogMsg(const char* fmt,...)
{
	va_list valist;
	va_start(valist, fmt);
	vprintf(fmt, valist);
	printf("\n");
	fflush(stdout);
	va_end(valist);	
}