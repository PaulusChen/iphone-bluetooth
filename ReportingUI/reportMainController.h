//
//  reportMainController.h
//
//  Created by svp on 8/7/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#include "PostController.h"

@interface reportMainController : UITableViewController<UITextViewDelegate, UploadProgressDelegate> {
	PostController* postCt;
	NSMutableString* _steps;
	UITableView* _tableView;
} 

//table view delegate & data source  methods
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section;

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;

// upload delegates
- (void)stoppedWithStatus:(NSString*)statusString;
- (void)reportProgress:(float)progress forStep:(int)step;


- (void) editSteps;

- (void) sendReportInternal;

- (void) sendReport;

- (BOOL)textViewShouldBeginEditing:(UITextView *)textView;

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;

- (NSString*) loggingEnabledFile;


@property (nonatomic, retain) NSMutableString* steps;
@property (nonatomic, retain) UIProgressView* uploadProgress;
@property (nonatomic, retain) IBOutlet UITableView* tableView;
@property (nonatomic, assign, readonly) BOOL loggingEnabled;


@end
