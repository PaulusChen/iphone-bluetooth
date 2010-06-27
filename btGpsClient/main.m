//
//  main.m
//  btGpsClient
//
//  Created by msftguy on 6/26/10.
//  Copyright __MyCompanyName__ 2010. All rights reserved.
//

#import <UIKit/UIKit.h>
#include "client_test.h"

int main(int argc, char *argv[]) {
    
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    client_test(argc, argv);
	[pool release];
    return 0;
}
