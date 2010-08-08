/*
 *  log.m
 *  btTest
 *
 *  Created by msftguy on 6/25/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#include <stdarg.h>
#include <sys/time.h>
#include "log.h"

void print_timestamp() 
{
	char buf[0x80];
	size_t size = sizeof(buf);
	struct timeval tv;
	struct timezone tz;
	struct tm *tm;
	gettimeofday(&tv, &tz);
	tm = localtime(&tv.tv_sec);
	size_t pos = strftime(buf, size, "%H:%M:%S", tm);
	snprintf(buf + pos, size - pos, ".%04.0Lf", 10000 * (long double)tv.tv_usec/1.0E+6);
	printf("[%s]", buf);
}

void LogOperation(const char* fmt,...)
{
	va_list valist;
	va_start(valist, fmt);
	print_timestamp();
	vprintf(fmt, valist);
	printf("\n");
	fflush(stdout);
	va_end(valist);
}

void LogMsg(const char* fmt,...)
{
	va_list valist;
	va_start(valist, fmt);
	print_timestamp();
	vprintf(fmt, valist);
	printf("\n");
	fflush(stdout);
	va_end(valist);	
}