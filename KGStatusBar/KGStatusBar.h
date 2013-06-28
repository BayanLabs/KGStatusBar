//
//  KGStatusBar.h
//
//  Created by Kevin Gibbon on 2/27/13.
//  Copyright 2013 Kevin Gibbon. All rights reserved.
//  @kevingibbon
//

#import <UIKit/UIKit.h>

@interface KGStatusBar : UIView

+ (void)setEnabled:(BOOL)enabled;
+ (void)showWithStatus:(NSString*)status;
+ (void)showWithStatus:(NSString*)status dismissAfter:(NSTimeInterval)interval;
+ (void)showSuccessWithStatus:(NSString*)status;
+ (void)showErrorWithStatus:(NSString*)status;
+ (void)showSpinnerWithStatus:(NSString*)status progress:(float)progress;
+ (void)setProgress:(float)progress;
+ (void)dismiss;

@end
