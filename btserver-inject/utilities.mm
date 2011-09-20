/*
 *  utilities.mm
 *  btserver-inject
 *
 *  Created by msftguy on 9/20/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */

#include "utilities.h"

extern "C" CFDictionaryRef _CFCopySystemVersionDictionary();
extern CFStringRef const _kCFSystemVersionProductVersionKey;

static NSString* const getIosVer()
{
    static NSString* iosVer = nil;
    if (iosVer == nil) {
        CFDictionaryRef verDict = _CFCopySystemVersionDictionary();
        if (verDict != nil) {
            CFStringRef verStr = (CFStringRef)CFDictionaryGetValue(verDict, _kCFSystemVersionProductVersionKey);
            if (verStr != nil) {
                iosVer = [[NSString alloc] initWithString:(NSString*)verStr];
            }
            CFRelease(verDict);
        }
    }
    return iosVer;
}

BOOL isOsVersion_4_2_OrHigher()
{
    return [getIosVer() compare:@"4.2"] != NSOrderedAscending;
}

BOOL isOsVersion_5_OrHigher()
{
    return [getIosVer() compare:@"5.0"] != NSOrderedAscending;
}