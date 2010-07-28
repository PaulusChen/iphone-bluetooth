/*
 *  ipc.h
 *  locationd-inject
 *
 *  Created by svp on 7/28/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#ifndef __IPC_H
#define __IPC_H

#include "EALocationAccessory.h"

#ifdef __cplusplus
extern "C" {
#endif

	void gps_start(EALocationAccessory* accObj);

	void gps_stop(EALocationAccessory* accObj);

#ifdef __cplusplus
}
#endif

#endif // __IPC_H