//
//  reportMainController.m
//
//  Created by svp on 8/7/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "reportMainController.h"
#import "reportStepsController.h"
#import "ReportingUIAppDelegate.h"

@implementation reportMainController

@synthesize stepsTextView;

- (void) viewDidLoad
{
	[super viewDidLoad];
	[self navigationItem].title = @"Report a Problem";
	postCt = [[PostController alloc]init];
}

- (void) dealloc
{
	if (postCt != nil) {
		[postCt release];
	}
	[super dealloc];
}

- (void) editSteps
{
	reportStepsController* stepsCt = [[reportStepsController alloc] initWithNibName:@"reportSteps" bundle:nil];
	stepsCt.otherTextView = stepsTextView;
	[[test5AppDelegate navController] pushViewController:stepsCt animated:YES];
}

- (IBAction) onEditStepsButton:(id)sender
{
	[self editSteps];
}


- (IBAction) onStartLoggingButton:(id)sender
{
	// [CoreReportingLogic startLogging];
}

- (IBAction) onSendReportButton:(id)sender
{
	// [CoreReportingLogic submitReportWithRepro:(NSString*)stepsTextView.text];
	NSLog(@"onSendReportButton");
	NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
								[[UIDevice currentDevice] uniqueIdentifier], @"uuid", 
								stepsTextView.text, @"ReproSteps", 
								nil];
	[postCt addFiles:[NSArray arrayWithObjects: dict, 
					  @"/tmp/BtGpsServer.log", 
					  @"/tmp/BtGpsServer.err", 
					  @"/var/log/roqyBT.log", 
					  @"/var/log/roqyBT.err", 
					  @"/private/var/mobile/Documents/roqyBT/Autoconnect",
					  @"/private/var/mobile/Documents/roqyBT/Config",
					  @"/private/var/mobile/Documents/roqyBT/Licence",
					  @"/private/var/mobile/Documents/roqyBT/nmea_log.txt",					  
					  @"/private/var/mobile/Library/Logs/BTServer_stdout.log", 
					  @"/private/var/logs/CrashReporter/LatestCrash-roqyBluetooth.plist",
					  nil]];
	[postCt startUpload];
}

- (BOOL)textViewShouldBeginEditing:(UITextView *)textView
{
	[self editSteps];
	return NO;
}

@end
