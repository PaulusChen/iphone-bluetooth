/*
 *  gps_thread.h
 *  btGpsServer
 *
 *  Created by msftguy on 6/26/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

@interface GpsThread : NSObject {
}

- (void) threadProc:(NSObject*) ctx;
- (id) init;

@end