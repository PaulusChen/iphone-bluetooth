//
//  OptionsPage.m
//  ReportingUI
//
//  Created by msftguy on 9/1/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "OptionsPage.h"


@implementation OptionsPage

@synthesize hciToggle;
@synthesize options = _options;

/*
 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
    }
    return self;
}
*/

- (void) viewDidLoad
{
	[super viewDidLoad];
	[self navigationItem].title = @"Options";
}

- (void) viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	self.hciToggle.on = [[self.options valueForKey:optionHciToggle] boolValue];
}
/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (IBAction) hciLoggingToggled:(id)sender
{
	[self.options setValue:[NSNumber numberWithBool:self.hciToggle.on] forKey:optionHciToggle];
	NSLog(@"options: %@", self.options);
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


- (void)dealloc {
    [super dealloc];
}


@end
