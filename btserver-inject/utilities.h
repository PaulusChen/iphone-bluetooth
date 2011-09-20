/*
 *  utilities.h
 *  btserver-inject
 *
 *  Created by msftguy on 9/20/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#include <sys/types.h>
#include <sys/sysctl.h>


#ifdef __cplusplus
extern "C" {
#endif

BOOL isOsVersion_4_2_OrHigher();

BOOL isOsVersion_5_OrHigher();

#ifdef __cplusplus
}
#endif
