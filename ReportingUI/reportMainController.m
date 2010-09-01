//
//  reportMainController.m
//
//  Created by svp on 8/7/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "reportMainController.h"
#import "reportStepsController.h"
#import "ReportingUIAppDelegate.h"
#import "CmdRunner.h"

@implementation reportMainController

NSString* disableLoggingMessage = @"Disable logging?";
NSString* confirmLoglessReportMessage = @"Send report without logs?";

@synthesize steps = _steps;
@synthesize tableView = _tableView;
@synthesize uploadProgress;
@synthesize optionsNavBarButton;
@synthesize uploadResultShown = _uploadResultShown;
@synthesize uploadResultSuccess = _uploadResultSuccess;
@synthesize uploadResult = _uploadResult;
@synthesize uploadResultDetails = _uploadResultDetails;

- (void) viewDidLoad
{
	[super viewDidLoad];
	[self navigationItem].title = @"Report a Problem";
	//[self navigationItem].leftBarButtonItem = optionsNavBarButton;
	postCt = [[PostController alloc]init];
	self.steps = [NSMutableString stringWithString:
@"Describe the steps to reproduce the problem:\n\
1. \n\
2. \n\
3. \n\
\n\
What did you expect to happen: \n\
\n\
What actually happened: \n\
\n\
Additional details: \n\
"
				  ];
}

- (void) dealloc
{
	if (postCt != nil) {
		[postCt release];
	}
	self.uploadResult = nil;
	self.uploadResultDetails = nil;
	[super dealloc];
}

- (BOOL) loggingEnabled
{
	return [[NSFileManager defaultManager] fileExistsAtPath:self.loggingEnabledFile];
}

- (UITableViewCell*) tableCellAtIndex:(NSUInteger)index
{
	assert(index < [self.tableView numberOfSections]);
	return [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:index]];
}

- (UITableViewCell*) loggingCell
{
	return [self tableCellAtIndex:0];

}

- (UITableViewCell*) stepsCell
{
	return [self tableCellAtIndex:2];
	
}

- (UITableViewCell*) reportCell
{
	return [self tableCellAtIndex:3];
	
}

- (void) viewWillAppear:(BOOL)animated
{
	[self stepsCell].detailTextLabel.text = self.steps;
}


- (void)taskFinishedWithResult:(int)result context:(id)context
{
    NSLog(@"Task exited, code %u", result);
	if (result == 0) {
	}
	UITableViewCell* loggingCell = [self loggingCell];
	loggingCell.accessoryView = nil;
	[self loggingCell].accessoryType = self.loggingEnabled ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	if (section == 1) {
		return 0;
	} else if (section == 3 && self.uploadResultShown) {
		return 2;
	}
	return 1;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 4;
}


// Row display. Implementers should *always* try to reuse cells by setting each cell's reuseIdentifier and querying for available reusable cells with dequeueReusableCellWithIdentifier:
// Cell gets various attributes set automatically based on table (separators) and data source (accessory views, editing controls)

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSString* cellReuseId = @"MyCellStyleValue1";
	UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:cellReuseId];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc]
				 initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellReuseId] 
				autorelease];
	}
	switch (indexPath.section) {
		case 0:
			cell.textLabel.text = @"Start logging";
			if (self.loggingEnabled) {
				cell.accessoryType = UITableViewCellAccessoryCheckmark;
			}
			break;
		case 1:
			assert(false);
			break;
		case 2:
			cell.textLabel.text = @"Steps";
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			cell.detailTextLabel.text = self.steps;
			break;
		case 3:
			if (indexPath.row == 0) {
				cell.textLabel.text = @"Send report";
				if (self.uploadProgress == nil) {
					self.uploadProgress = [[[UIProgressView alloc] 
												initWithProgressViewStyle:UIProgressViewStyleDefault]
											   autorelease];
					self.uploadProgress.hidden = YES;
				}
				cell.accessoryView = self.uploadProgress;
			} else {
				NSString* cellReuseId2 = @"MyCellStyleSubtitle";
				UITableViewCell* cell2 = [tableView dequeueReusableCellWithIdentifier:cellReuseId2];
				if (cell2 == nil) {
					cell2 = [[[UITableViewCell alloc]
							 initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellReuseId2] 
							autorelease];
				}
				
				cell2.textLabel.textColor = self.uploadResultSuccess ? [UIColor darkTextColor] : [UIColor redColor];
				cell2.textLabel.text = self.uploadResult;
				cell2.detailTextLabel.text = self.uploadResultDetails;
				cell = cell2;
			}
			break;
		default:
			assert(false);
	}
	return cell;
}

- (NSString*)loggingScript
{
	return [NSString stringWithFormat:@"%@/toggle_logging.sh", [[NSBundle mainBundle] bundlePath]];
}

- (NSString*) loggingEnabledFile
{
	return [NSString stringWithFormat:@"%@/logging_enabled", [[NSBundle mainBundle] bundlePath]];
}

- (void) toggleLogging:(BOOL)enable
{
	NSLog(@"cmd test: running '%@'", self.loggingScript);
	[CmdRunner runCommandInBackground:@"/bin/bash" withArguments:[NSArray arrayWithObjects:self.loggingScript, enable ? @"1" : @"0", nil] 
					 completionObject:self andCallback:@selector(taskFinishedWithResult:context:) andContext:nil];
	
	UIActivityIndicatorView* ai = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray] autorelease];
	[ai startAnimating];
	[self loggingCell].accessoryView = ai;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex == alertView.cancelButtonIndex) {
		return;
	}
	
	if ([disableLoggingMessage isEqualToString:alertView.title]) {
		[self toggleLogging:NO];

	} else if ([confirmLoglessReportMessage isEqualToString:alertView.title]) {
		[self sendReportInternal];
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	switch (indexPath.section) {
		case 0:
			{
				if (!self.loggingEnabled) {
					[self toggleLogging:YES];
				} else {
					UIAlertView* av = 
					[[[UIAlertView alloc] initWithTitle:disableLoggingMessage message:nil delegate:self cancelButtonTitle:@"Keep on" otherButtonTitles:@"Disable", nil] autorelease];
					[av show];
				}
			}
			break;
		case 2:
			[self editSteps];
			break;
		case 3:
			[self sendReport];
			break;

		default:
			break;
	}
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	switch (section) {
		case 0:
			return @"1 Enable logging";
			break;
		case 1:
			return @"2 Try to reproduce the problem now";
			break;
		case 2:
			return @"3 Describe the problem";
			break;
		case 3:
			return @"4 Prepare and send the report";
			break;
		default:
			assert(false);
			return nil;
			break;
	}
}

- (void) showOrHideUploadStatus:(BOOL)show
{
	if (show != self.uploadResultShown) {
		NSArray* paths = [NSArray arrayWithObject:[NSIndexPath indexPathForRow:1 inSection:3]]; 
		[self.tableView beginUpdates];
		self.uploadResultShown = show;
		if (show) {
			[self.tableView insertRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationTop];
		} else {
			[self.tableView deleteRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationTop];
		}
		[self.tableView endUpdates];
	}
}

- (void) stoppedWithStatus:(NSString*)statusString response:(id)response
{
	self.uploadResultSuccess = NO;
	if (statusString == nil) {
		NSDictionary* responseDict = response;
		NSString* reportId = [responseDict valueForKey:@"reportId"];
		if (reportId != nil) {
			self.uploadResultSuccess = YES;
			self.uploadResult = [NSString stringWithFormat:@"Report id: %@", reportId];	
			self.uploadResultDetails = @"Include when contacting support";
		}
	}
	if (!self.uploadResultSuccess) {
		self.uploadResult = statusString;
		self.uploadResultDetails = @"Check your internet connection";
	}
	
	UITableViewCell* cell =	[self reportCell];
	cell.accessoryView = nil;
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;

	if (self.uploadResultSuccess) {
		cell.accessoryType = UITableViewCellAccessoryCheckmark;
		cell.detailTextLabel.textColor = [UIColor darkTextColor];
		cell.detailTextLabel.text = @"Success";
	} else {
		cell.accessoryType = UITableViewCellAccessoryNone;
		cell.detailTextLabel.textColor = [UIColor redColor];
		cell.detailTextLabel.text = @"Failed";
	}
	[self showOrHideUploadStatus:YES];
	if (self.loggingEnabled) {
		[self toggleLogging:NO];
	}
}

- (void)reportProgress:(float)progress forStep:(int)step
{
	self.uploadProgress.progress = (progress + step) / postCt.numSteps;
}

- (void) editSteps
{
	reportStepsController* stepsCt = [[[reportStepsController alloc] initWithNibName:@"reportSteps" bundle:nil] autorelease];
	stepsCt.steps = self.steps;
	[[test5AppDelegate navController] pushViewController:stepsCt animated:YES];
}

- (void) sendReportInternal
{	
	NSLog(@"sendReportInternal");
	NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
						  [[UIDevice currentDevice] uniqueIdentifier], @"uuid", 
						  self.steps, @"ReproSteps", 
						  nil];
	[postCt addFiles:[NSArray arrayWithObjects: dict, 
					  // syslog
					  @"/var/log/syslog",
					  // iphone-bluetooth stack logs
					  @"/tmp/BtGpsServer.log", 
					  @"/tmp/BtGpsServer.err", 
					  // v4 stack logs
					  @"/tmp/roqyBluetooth4d.log",
					  @"/tmp/roqyBluetooth4d.err",
					  // v0.9 stack logs
					  @"/var/log/roqyBT.log", 
					  @"/var/log/roqyBT.err", 
					  // v0.9 settings
					  @"/private/var/mobile/Documents/roqyBT/Autoconnect",
					  @"/private/var/mobile/Documents/roqyBT/Config",
					  @"/private/var/mobile/Documents/roqyBT/Licence",
					  // v4 settings
					  @"/private/var/mobile/Documents/roqyBT/Config4",
					  @"/private/var/mobile/Documents/roqyBT/License4",
					  // v0.9 logs
					  @"/private/var/mobile/Documents/roqyBT/nmea_log.txt",
					  // mobile crash logs, v0.9
					  @"/private/var/mobile/Library/Logs/CrashReporter/LatestCrash-roqyBT.plist",
					  // mobile crash logs, v4
					  @"/private/var/mobile/Library/Logs/CrashReporter/LatestCrash-roqyBT4.plist",
					  @"/private/var/mobile/Library/Logs/CrashReporter/LatestCrash-roqyBluetooth4d.plist",
					  // Stack log, v4
					  @"/private/var/mobile/Library/Logs/BTServer_stdout.log", 
					  // root crash logs, v0.9
					  @"/private/var/logs/CrashReporter/LatestCrash-roqyBluetooth.plist",
					  // self crash logs
					  @"/private/var/logs/CrashReporter/LatestCrash-ReportingUI.plist",
					  nil]];
	postCt.delegate = self;
	[postCt startUpload];
	UITableViewCell* cell =	[self reportCell];
	cell.accessoryView = self.uploadProgress;
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	self.uploadProgress.progress = 0.01;
	self.uploadProgress.hidden = NO;
	[self showOrHideUploadStatus:NO];
}

- (void) sendReport
{
	if ([postCt isSending]) {
		return;
	}
	if (!self.loggingEnabled) {
		UIAlertView* av = 
		[[[UIAlertView alloc] initWithTitle:confirmLoglessReportMessage message:nil delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Send", nil] autorelease];
		[av show];
		return;
	}
	[self sendReportInternal];
}

- (BOOL)textViewShouldBeginEditing:(UITextView *)textView
{
	[self editSteps];
	return NO;
}

- (IBAction) optionsButtonClicked:(id)sender
{
	
}

@end
