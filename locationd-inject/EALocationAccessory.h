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
		
}

-(BOOL)accessoryHasNMEASentencesAvailable;

-(void)getNMEASentence:(NSString**)outSentence;

-(void)setNMEASentencesToFilter:(NSArray*)nsstringArray;

-(BOOL)setupEphemeris; // true = OK

-(BOOL)supportsLocation;

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