//
//  reportMainController.h
//
//  Created by svp on 8/7/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#include "PostController.h"

@interface reportMainController : UIViewController<UITextViewDelegate> {
	PostController* postCt;
} 

- (BOOL)textViewShouldBeginEditing:(UITextView *)textView;

- (IBAction) onEditStepsButton:(id)sender;

- (IBAction) onStartLoggingButton:(id)sender;

- (IBAction) onSendReportButton:(id)sender;

@property (nonatomic, retain) IBOutlet UITextView* stepsTextView;

@end
