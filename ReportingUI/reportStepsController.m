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
	CGRect keyboardRectBegin = [[[aNotification userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
	CGRect keyboardRectEnd = [[[aNotification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
	NSTimeInterval animationDuration;
	[[[aNotification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&animationDuration];
    
	CGRect frame = self.view.frame;
    frame.size.height += keyboardRectEnd.origin.y - keyboardRectBegin.origin.y;

    [UIView animateWithDuration:animationDuration delay:0 options:UIViewAnimationOptionLayoutSubviews|UIViewAnimationOptionBeginFromCurrentState 
					 animations:^{self.view.frame = frame;} completion:nil];
}


- (void) viewDidLoad
{
	[super viewDidLoad];
	[self navigationItem].title = @"Steps";
	[self navigationItem].rightBarButtonItem = rightNavBarButton;
}

@end
