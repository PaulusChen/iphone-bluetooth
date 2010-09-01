//
//  OptionsPage.h
//  ReportingUI
//
//  Created by msftguy on 9/1/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

static NSString* optionHciToggle = @"optionHciToggle";

@interface OptionsPage : UIViewController {

}

- (IBAction) hciLoggingToggled:(id)sender;

@property (nonatomic, retain) IBOutlet UISwitch* hciToggle;
@property (nonatomic, retain) NSMutableDictionary* options;

@end
