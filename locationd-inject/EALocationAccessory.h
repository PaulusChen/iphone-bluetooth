//
//  EALocationAccessory.h
//  locationd-inject
//
//  Created by svp on 7/28/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ExternalAccessory/ExternalAccessory.h>


EA_EXTERN NSString *const EAAccessoryDidReceiveNMEASentenceNotification __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_3_0);
EA_EXTERN NSString *const EAAccessoryDidReceiveLocationPointDataNotification __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_3_0);


@interface EALocationAccessory : NSObject {
@private
    EAAccessoryInternal *_internal;
	BOOL dataLeft;
	NSArray* nmeaSentences;
	int currentIndex;
	BOOL accessoryConnected;
}

- (void) postNamedNotification:(NSString*)notification;

- (void) onNmea:(NSString*)nmeaSentences;

- (void) ensureAccessoryConnected;

+ (EALocationAccessory*) instance;

+ (void) start;

+ (void) stop;

- (void) start;

- (void) stop;

- (EALocationAccessory*) init;

- (void) dealloc;

- (BOOL) accessoryHasNMEASentencesAvailable;

- (BOOL) getNMEASentence:(NSString**)outSentence;

- (BOOL) setNMEASentencesToFilter:(NSArray*)nsstringArray;

- (BOOL) setupEphemeris;

- (BOOL) supportsLocation;

- (BOOL) sendGpsWeek:(float) week gpsTOW:(double)tow;

- (BOOL) sendEphemerisPointDataGpsWeek:(float)week gpsTOW:(double)tow latitude:(double)lat longitude:(double)lon accuracy:(short)acc;

- (BOOL) getEphemerisURL:(NSString**)pUrl;

@property(nonatomic, readonly, getter=isConnected) BOOL connected __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_3_0);
@property(nonatomic, readonly) NSUInteger connectionID __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_3_0);
@property(nonatomic, readonly) NSString *manufacturer __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_3_0);
@property(nonatomic, readonly) NSString *name __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_3_0);
@property(nonatomic, readonly) NSString *modelNumber __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_3_0);
@property(nonatomic, readonly) NSString *serialNumber __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_3_0);
@property(nonatomic, readonly) NSString *firmwareRevision __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_3_0);
@property(nonatomic, readonly) NSString *hardwareRevision __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_3_0);

// array of strings representing the protocols supported by the accessory
@property(nonatomic, readonly) NSArray *protocolStrings __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_3_0);

@property(nonatomic, assign) id<EAAccessoryDelegate> delegate __OSX_AVAILABLE_STARTING(__MAC_NA,__IPHONE_3_0);


@end