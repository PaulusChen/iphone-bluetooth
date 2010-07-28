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
	[self postNamedNotification:EAAccessoryDidConnectNotification];
	[timer setFireDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
}

+(void)stop
{
	[[EALocationAccessory instance] stop];	
}

-(void)stop
{
	NSLog(@"[EALocationAccessory stop]");
	[self postNamedNotification:EAAccessoryDidDisconnectNotification];
	[timer setFireDate:[NSDate distantFuture]];
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
	timer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(onTimer:) userInfo:nil repeats:YES];
	[timer setFireDate:[NSDate distantFuture]];

	NSString *info = [NSString stringWithContentsOfFile:@"/lib/nmea.txt"];
	currentIndex = 0;
	nmeaSentences = [[NSArray alloc] initWithArray:[info componentsSeparatedByString:@"\n"] copyItems:YES];
	NSLog(@"Loaded %i sentences", [nmeaSentences count]);
	return self;
}

-(void)dealloc
{
	[timer invalidate];
	[timer release];
	[nmeaSentences release];
	[super dealloc];
}

-(void)onTimer:(NSTimer*)theTimer
{
	NSLog(@"[EALocationAccessory onTimer]");
	dataLeft = currentIndex < [nmeaSentences count];
	[self postNamedNotification:EAAccessoryDidReceiveNMEASentenceNotification];
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
	NSLog(@"[EALocationAccessory accessoryHasNMEASentencesAvailable] returning %i", dataLeft);
	return dataLeft;
}

-(BOOL)getNMEASentence:(NSString**)outSentence
{
	*outSentence = [[[NSString alloc] initWithString:[nmeaSentences objectAtIndex:currentIndex++]] autorelease];
	NSLog(@"[EALocationAccessory getNMEASentence] %@", *outSentence);
	dataLeft = NO;
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
