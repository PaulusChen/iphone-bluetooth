/*
 *  filter.h
 *  btserver-inject
 *
 *  Created by msftguy on 9/11/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

BOOL filter_read_h5_inplace(int fd, char* buf, size_t cbRead);

BOOL filter_read_h4_inplace(int fd, char* buf, size_t cbRead);
