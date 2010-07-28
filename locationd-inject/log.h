/*
 *  log.h
 *  btTest
 *
 *  Created by msftguy on 6/25/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#ifdef __cplusplus
extern "C" {
#endif

void LogOperation(const char* fmt,...);
void LogMsg(const char* fmt,...);

#ifdef __cplusplus
}
#endif