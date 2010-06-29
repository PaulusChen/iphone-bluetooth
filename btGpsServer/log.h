/*
 *  log.h
 *  btTest
 *
 *  Created by msftguy on 6/25/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#ifndef _LOG_H
#define _LOG_H

#ifdef __cplusplus
extern "C" {
#endif

void LogOperation(const char* fmt,...);
void LogMsg(const char* fmt,...);

#ifdef __cplusplus
}
#endif
		
#endif	//_LOG_H
