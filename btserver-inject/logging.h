/*
 *  logging.h
 *  bbinj
 *
 *  Created by msftguy on 6/16/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

void log_io(int fd, const char* comment, const void* bytes, size_t size, int result);

void log_at(const char* cmd);

void log_progress(const char* msg, ...);
