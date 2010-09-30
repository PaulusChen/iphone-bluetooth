/*
 *  utilities.mm
 *  btserver-inject
 *
 *  Created by msftguy on 9/20/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#include "utilities.h"

int getOsRevision()
{
	static int osRevision = 0;
	if (osRevision == 0) {
		size_t len = sizeof(osRevision);
		sysctlbyname("kern.osrevision", &osRevision, &len, nil, 0);
	}
	return osRevision;
}

BOOL isOsVersion_4_2_OrHigher()
{
	return getOsRevision() >= osRev_4_2;
}