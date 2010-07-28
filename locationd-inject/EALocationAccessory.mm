//
//  EALocationAccessory.m
//  locationd-inject
//
//  Created by svp on 7/28/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "EALocationAccessory.h"


@implementation EALocationAccessory

@synthesize	connectionID;
@synthesize manufacturer;
@synthesize	name;
@synthesize modelNumber;
@synthesize serialNumber;
@synthesize firmwareRevision;
@synthesize hardwareRevision;

// array of strings representing the protocols supported by the accessory
@synthesize protocolStrings;

@synthesize	delegate;

-(BOOL)isConnected
{
	return YES;
}

-(BOOL)accessoryHasNMEASentencesAvailable
{
	return YES;
}

-(void)getNMEASentence:(NSString**)outSentence
{
	*outSentence = [[[NSString alloc] initWithString:@"TEST"] autorelease];
}

-(void)setNMEASentencesToFilter:(NSArray*)nsstringArray
{
	
}

-(BOOL)setupEphemeris
{
	return YES;
}

-(BOOL)supportsLocation
{
	return YES;
}

@end
