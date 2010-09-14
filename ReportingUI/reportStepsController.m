//
//  reportStepsController.m
//
//  Created by svp on 8/7/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "reportStepsController.h"
#import "ReportingUIAppDelegate.h"

@implementation reportStepsController

@synthesize rightNavBarButton;
@synthesize textView;
@synthesize steps = _steps;

- (IBAction) rightNavbarButtonClicked:(id)sender
{
	[[ReportingUIAppDelegate navController] popToRootViewControllerAnimated:YES];
}

- (void) viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	self.textView.text = self.steps;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillResize:) name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillResize:) name:UIKeyboardWillHideNotification object:nil];
}

- (void) viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	[self.steps setString:textView.text];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

- (void) keyboardWillResize:(NSNotification *)aNotification 
{
	CGRect frame = self.view.frame;

	NSTimeInterval animationDuration;
	[[[aNotification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&animationDuration];

	id keyboardRectBeginObj = [[aNotification userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey];
	if (nil != keyboardRectBeginObj) {
		CGRect keyboardRectBegin = [keyboardRectBeginObj CGRectValue];
		CGRect keyboardRectEnd = [[[aNotification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
		
		frame.size.height += keyboardRectEnd.origin.y - keyboardRectBegin.origin.y;

		if ([[[UIDevice currentDevice] systemVersion] compare:@"4.0"] >= 0) {
			[UIView animateWithDuration:animationDuration delay:0 options:UIViewAnimationOptionLayoutSubviews|UIViewAnimationOptionBeginFromCurrentState 
						 animations:^{self.view.frame = frame;} completion:nil];
		} else {
			self.view.frame = frame;
		}
	} else {
		CGRect keyboardRect = [[[aNotification userInfo] objectForKey:UIKeyboardBoundsUserInfoKey] CGRectValue];
		frame.size.height = self.view.superview.frame.size.height - keyboardRect.size.height;
		
		self.view.frame = frame;
	}
}


- (void) viewDidLoad
{
	[super viewDidLoad];
	[self navigationItem].title = @"Steps";
	[self navigationItem].rightBarButtonItem = rightNavBarButton;
}

@end
