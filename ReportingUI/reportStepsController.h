//
//  reportStepsController.h
//
//  Created by svp on 8/7/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface reportStepsController : UIViewController {
}

- (IBAction) rightNavbarButtonClicked:(id)sender;

- (void) keyboardWillResize:(NSNotification *)aNotification;

@property (nonatomic, retain) IBOutlet UIBarButtonItem* rightNavBarButton;
@property (nonatomic, retain) IBOutlet UITextView* textView;
@property (nonatomic, retain) UITextView* otherTextView;


@end
