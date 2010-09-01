/*
 *  logging.mm
 *  bbinj
 *
 *  Created by msftguy on 6/16/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#include "logging.h"
#include <stdio.h>
#include <unistd.h>
#include <sys/time.h>

static FILE* hLog = NULL;

void set_timestamp(char* buf, size_t size) 
{
	struct timeval tv;
	struct timezone tz;
	struct tm *tm;
	gettimeofday(&tv, &tz);
	tm = localtime(&tv.tv_sec);
	size_t pos = strftime(buf, size, "%H:%M:%S", tm);
	snprintf(buf + pos, size - pos, ".%04.0Lf", 10000 * (long double)tv.tv_usec/1.0E+6);
}

bool log_open() {
	if (hLog == NULL) {
		char pathBuffer[BUFSIZ];
		snprintf(pathBuffer, sizeof(pathBuffer), "%s/Library/Logs/btsrvinj.log", getenv("HOME"));
		hLog = fopen(pathBuffer, "a");
	}
	return hLog != NULL;
}

char* hexdump_nb(char* buf, size_t off, char* data, size_t lineSize, size_t size)
{
	buf += sprintf(buf, "%04lX: ", off);
	for (size_t i = 0; i < lineSize; ++i) {
		buf += sprintf(buf, i < size ? "%s%02X" : "%s  ", i == 0 ? "" : " ", (unsigned char)data[i]);
	}
	buf += sprintf(buf, " | ");
	for (size_t i = 0; i < size; ++i) {
		unsigned char b = (unsigned char)data[i];
		b = b < ' ' ? '.' : b;
		buf += sprintf(buf, "%c", b); 			
	}
	buf += sprintf(buf, "\n");
	return buf;
}

char* hexdump(char* bytes, size_t size)
{
	char* buf = (char*)malloc(size * 6 + 0x100);
	if (buf == NULL)
		return NULL;
	char* p = buf;
	const size_t lineSize = 0x10;
	for (size_t i = 0; i < size; i += lineSize) {
		p = hexdump_nb(p, i, bytes + i, lineSize, MIN(lineSize, size - i));
	}
	return buf;
}

void log_io(int fd, const char* comment, const void* bytes, size_t size, int result)
{
	if (!log_open())
		return;
	char* hd = hexdump((char*)bytes, size);
	if (hd != NULL) {
		char tsbuf[0x80];
		set_timestamp(tsbuf, sizeof(tsbuf));
		fprintf(hLog, "[%s] IO(%i): %s, %li (0x%lx)bytes:\n%s\n", tsbuf, fd, comment, size, size, hd);
		fflush(hLog);
		fsync(fileno(hLog));
		free(hd);
	}
}

void log_progress(const char* msg, ...) 
{
	va_list varargs;
	va_start(varargs, msg);
	if (log_open()) {
		char tsbuf[0x80];
		set_timestamp(tsbuf, sizeof(tsbuf));
		char msgbuf[0x1000];
		vsnprintf(msgbuf, sizeof(msgbuf), msg, varargs);
		fprintf(hLog, "[%s] TRACE %s\n", tsbuf, msgbuf);
		fflush(hLog);	
		fsync(fileno(hLog));
	}
	va_end(varargs);
}

void log_at(const char* cmd) 
{
	if (!log_open())
		return;
	char tsbuf[0x80];
	set_timestamp(tsbuf, sizeof(tsbuf));
	fprintf(hLog, "[%s] AT %s\n", tsbuf, cmd);
	fflush(hLog);
	fsync(fileno(hLog));
}
