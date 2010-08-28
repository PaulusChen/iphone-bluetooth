//
//  CmdRunner.h
//  ReportingUI
//
//  Created by svp on 8/24/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CmdRunner : NSObject {

}

+ (void) runCommandInBackground:(NSString*)command withArguments:(NSArray*)args completionObject:(id)obj andCallback:(SEL)completionCallback andContext:(id)context;

@property (nonatomic, retain) NSString* command;
@property (nonatomic, retain) NSArray* args;
@property (nonatomic, retain) id completionObject;
@property (nonatomic, assign) SEL completionCallback;
@property (nonatomic, assign) id completionContext;
@property (nonatomic, assign) int result;

@end
