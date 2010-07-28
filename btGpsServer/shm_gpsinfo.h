/*
 *  shm_gpsinfo.h
 *  btGpsServer
 *
 *  Created by msftguy on 6/28/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */
#include <CoreFoundation/CoreFoundation.h>
#include <nmea/nmea.h>

void shm_post_update(nmeaINFO* nmeaInfo, const char *buff, int buff_sz);

boolean_t shm_ensure();