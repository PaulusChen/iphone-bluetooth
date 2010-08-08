//
//  EALocationAccessory.m
//  locationd-inject
//
//  Created by svp on 7/28/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "EALocationAccessory.h"
#include "ipc.h"

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

+(EALocationAccessory*)instance
{
	static EALocationAccessory* s_instance = nil;
	if (s_instance == nil) {
		s_instance = [[EALocationAccessory alloc] init];
	}
	return s_instance;
}

+(void)start
{
	[[EALocationAccessory instance] start];
}

-(void)start
{
	NSLog(@"[EALocationAccessory start]");
	gps_start(self);
}

+(void)stop
{
	[[EALocationAccessory instance] stop];	
}

-(void)stop
{
	NSLog(@"[EALocationAccessory stop]");
	if (accessoryConnected) {
		[self postNamedNotification:EAAccessoryDidDisconnectNotification];
		accessoryConnected = NO;
	}
	gps_stop(self);
}

-(EALocationAccessory*)init
{
	connectionID = 0;
	manufacturer = @"GPS_Manufacturer";
	name = @"GPS_AccessoryName";
	modelNumber = @"GPS_ModelNumber";
	serialNumber = @"GPS_SerialNumber";
	firmwareRevision = @"GPS_FirmwareRevision";
	hardwareRevision = @"GPS_HardwareRevision";
	return self;
}


- (void) ensureAccessoryConnected
{
	if (!accessoryConnected) {
		[self postNamedNotification:EAAccessoryDidConnectNotification];
		accessoryConnected = YES;
	}
}


-(void)onNmea:(NSString*)data
{
	currentIndex = 0;
	[nmeaSentences release];
	nmeaSentences = [[NSArray alloc] initWithArray:[data componentsSeparatedByString:@"\n"] copyItems:YES];
	NSLog(@"Added %i sentences", [nmeaSentences count]);	
	[self postNamedNotification:EAAccessoryDidReceiveNMEASentenceNotification];
}

-(void)dealloc
{
	[nmeaSentences release];
	[super dealloc];
}

-(void)postNamedNotification:(NSString*)notification
{
	[[NSNotificationCenter defaultCenter] postNotificationName:notification object:self userInfo:[NSDictionary dictionaryWithObject:self forKey:EAAccessoryKey]];
}

-(BOOL)isConnected
{
	return YES;
}

-(BOOL)accessoryHasNMEASentencesAvailable
{
	dataLeft = currentIndex < [nmeaSentences count];
	NSLog(@"[EALocationAccessory accessoryHasNMEASentencesAvailable] returning %i", dataLeft);
	return dataLeft;
}

-(BOOL)getNMEASentence:(NSString**)outSentence
{
	if (![self accessoryHasNMEASentencesAvailable])
		return NO;
	*outSentence = [[[NSString alloc] initWithString:[nmeaSentences objectAtIndex:currentIndex++]] autorelease];
	NSLog(@"[EALocationAccessory getNMEASentence] %@", *outSentence);
	return YES;
}

-(BOOL)setNMEASentencesToFilter:(NSArray*)nsstringArray
{
	NSLog(@"[EALocationAccessory setNMEASentencesToFilter:%@]", nsstringArray);
	return YES;
}

-(BOOL)setupEphemeris
{
	NSLog(@"[EALocationAccessory setupEphemeris]");
	return YES;
}

-(BOOL)supportsLocation
{
	NSLog(@"[EALocationAccessory supportsLocation]");
	return YES;
}

-(BOOL)sendGpsWeek:(float) week gpsTOW:(double)tow
{
	NSLog(@"[EALocationAccessory sendGpsWeek:%f gpsTOW:%f]", week, tow);
	return YES;
}

-(BOOL)sendEphemerisPointDataGpsWeek:(float)week gpsTOW:(double)tow latitude:(double)lat longitude:(double)lon accuracy:(short)acc
{
	NSLog(@"[EALocationAccessory sendEphemerisPointDataGpsWeek:%f gpsTOW:%f latitude:%f longitude:%f accuracy:%i]", week, tow, lat, lon, acc);
	return YES;
}

-(BOOL)getEphemerisURL:(NSString**)pUrl
{
	*pUrl = nil;
	return NO;
}

@end
