//
//  KGStatusBar.m
//
//  Created by Kevin Gibbon on 2/27/13.
//  Copyright 2013 Kevin Gibbon. All rights reserved.
//  @kevingibbon
//

#import "KGStatusBar.h"

#define kStatusbarHeight 20.0

@interface KGStatusBarWindow : UIWindow
@end

@implementation KGStatusBarWindow

- (UIViewController *)rootViewController {
	UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
	if (keyWindow != self) {
		return keyWindow.rootViewController;
	}
	
	NSArray *windows = [UIApplication sharedApplication].windows;
	for (NSInteger i = [windows count] - 1; i >= 0; i--) {
		UIWindow *window = windows[i];
		if ([window isKindOfClass:[UIWindow class]] && window.windowLevel == UIWindowLevelNormal && window.rootViewController != nil) {
			return window.rootViewController;
		}
	}
	
	return nil;
}

@end

@interface KGStatusBar () {
	UIWindow *overlayWindow;
	UIView *topBar;
	UIView *progressBar;
	UILabel *stringLabel;
	UIActivityIndicatorView *progressIndicator;
	UIColor *defaultTextColor;
}

@property (nonatomic) float progress;
@property (nonatomic) BOOL enabled;
@property (nonatomic) BOOL topBarPinned;
@property (nonatomic, strong) UIColor *topBarDefaultBackgroundColor;

@end

@implementation KGStatusBar

+ (KGStatusBar*)sharedView {
    static dispatch_once_t once;
    static KGStatusBar *sharedView;
    dispatch_once(&once, ^ {
		sharedView = [[KGStatusBar alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	});
	
    return sharedView;
}

+ (void)setEnabled:(BOOL)enabled {
	[KGStatusBar sharedView].enabled = enabled;
}

+ (void)setTopBarPinned:(BOOL)pinned {
	[KGStatusBar sharedView].topBarPinned = pinned;
}

+ (void)setTopBarDefaultBackgroundColor:(UIColor *)color {
	[KGStatusBar sharedView].topBarDefaultBackgroundColor = color;
}

+ (void)showWithStatus:(NSString*)status {
	[self cancelPreviousPerformRequestsWithTarget:self selector:@selector(dismiss) object:self];
	
    [[KGStatusBar sharedView] showWithStatus:status barColor:nil textColor:nil showSpinner:NO];
}

+ (void)showWithStatus:(NSString*)status dismissAfter:(NSTimeInterval)interval {
	[self cancelPreviousPerformRequestsWithTarget:self selector:@selector(dismiss) object:self];
	
    [self showWithStatus:status];
	[self performSelector:@selector(dismiss) withObject:self afterDelay:interval];
}

+ (void)showSuccessWithStatus:(NSString*)status {
	[self cancelPreviousPerformRequestsWithTarget:self selector:@selector(dismiss) object:self];
	
    [KGStatusBar showWithStatus:status];
    [self performSelector:@selector(dismiss) withObject:self afterDelay:2.0];
}

+ (void)showErrorWithStatus:(NSString*)status {
	[self cancelPreviousPerformRequestsWithTarget:self selector:@selector(dismiss) object:self];
	
	UIColor *errorBarColor = [UIColor colorWithRed:97.0/255.0 green:4.0/255.0 blue:4.0/255.0 alpha:1.0];
    [[KGStatusBar sharedView] showWithStatus:status barColor:errorBarColor textColor:nil showSpinner:NO];
	[self performSelector:@selector(dismiss) withObject:self afterDelay:2.0];
}

+ (void)showSpinnerWithStatus:(NSString *)status progress:(float)progress {
	[self cancelPreviousPerformRequestsWithTarget:self selector:@selector(dismiss) object:self];
	
    [[KGStatusBar sharedView] showWithStatus:status barColor:nil textColor:nil showSpinner:YES];
	[[KGStatusBar sharedView] setProgress:progress];
}

+ (void)setProgress:(float)progress {
	[KGStatusBar sharedView].progress = progress;
}

+ (void)dismiss {
    [[KGStatusBar sharedView] dismiss];
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
		self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
		self.alpha = 0;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		
		_enabled = YES;
		defaultTextColor = [UIColor whiteColor];
		_topBarDefaultBackgroundColor = [UIColor blackColor];
		
		[self initializeView];
		
		// Register for orientation changes
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleRoration:)
                                                     name:UIApplicationDidChangeStatusBarOrientationNotification
                                                   object:nil];
    }
    return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	
	topBar.frame = CGRectMake(0.f, 0.f, [self screenSize].width, kStatusbarHeight);
	progressBar.frame = CGRectMake(0.f, 0.f, [self screenSize].width * self.progress, kStatusbarHeight - 1);
	
	NSString *labelText = stringLabel.text;
    CGRect labelRect = CGRectZero;
    CGFloat stringWidth = 0;
    CGFloat stringHeight = 0;
    if(labelText) {
		CGSize stringSize = [labelText boundingRectWithSize:CGSizeMake(topBar.frame.size.width, topBar.frame.size.height)
													options:0
												 attributes:@{ NSFontAttributeName: stringLabel.font }
													context:nil].size;
		
        stringWidth = stringSize.width;
        stringHeight = stringSize.height;
        
        labelRect = CGRectMake(roundf((topBar.frame.size.width / 2) - (stringWidth / 2)), roundf((topBar.frame.size.height / 2) - (stringHeight / 2)), stringWidth, stringHeight);
    }
    stringLabel.frame = labelRect;
	
	progressIndicator.center = CGPointMake(labelRect.origin.x - progressIndicator.frame.size.width, kStatusbarHeight / 2.0);
}

- (void)initializeView {
	[self createOverlayWindow];
	[self createTopBar];
	[self createStringLabel];
	[self createProgressBar];
	[self createProgressIndicator];
}

- (void)setEnabled:(BOOL)newEnabled {
	_enabled = newEnabled;
	
	if (!self.enabled) {
		[self dismiss];
	}
}

- (void)setTopBarPinned:(BOOL)newTopBarPinned {
	_topBarPinned = newTopBarPinned;
	
	if (self.topBarPinned) {
		[self showWithStatus:@"" barColor:nil textColor:nil showSpinner:NO];
	} else {
		[self dismiss];
	}
}

- (void)setProgress:(float)newProgress {
	_progress = newProgress;
	NSTimeInterval animationDuration = (self.progress == 0 ? 0 : 0.35);
	
	[UIView animateWithDuration:animationDuration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
		progressBar.frame = CGRectMake(0.f, 0.f, [self screenSize].width * self.progress, kStatusbarHeight);
	} completion:NULL];
}

- (void)showWithStatus:(NSString *)status barColor:(UIColor*)barColor textColor:(UIColor*)textColor showSpinner:(BOOL)showSpinner {
	if (!self.enabled) {
		return;
	}
	
    if (self.superview == nil) {
        [overlayWindow addSubview:self];
	}
	
	if (barColor == nil) {
		barColor = _topBarDefaultBackgroundColor;
	}
	
	if (textColor == nil) {
		textColor = defaultTextColor;
	}
	
    topBar.backgroundColor = barColor;
    topBar.hidden = NO;
    overlayWindow.hidden = NO;
    
	if (![stringLabel.text isEqualToString:status]) {
		stringLabel.alpha = 0.0;
	}
    stringLabel.hidden = NO;
    stringLabel.text = status;
    stringLabel.textColor = textColor;
	
	if (showSpinner) {
		[progressIndicator startAnimating];
	} else {
		[progressIndicator stopAnimating];
	}
	progressIndicator.hidden = !showSpinner;
	
	[UIView animateWithDuration:0.4 animations:^{
		topBar.alpha = 0.75;
        stringLabel.alpha = 1.0;
    }];
	
	[self setNeedsLayout];
    [self setNeedsDisplay];
}

- (void)dismiss {
    [UIView animateWithDuration:0.4 animations:^{
		topBar.alpha = 0.0;
        stringLabel.alpha = 0.0;
    }];
}

- (void)createOverlayWindow {
    if (overlayWindow != nil) {
		return;
	}
	
	overlayWindow = [[KGStatusBarWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
	overlayWindow.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	overlayWindow.backgroundColor = [UIColor clearColor];
	overlayWindow.userInteractionEnabled = NO;
	overlayWindow.windowLevel = UIWindowLevelStatusBar;
	
	// Transform depending on interafce orientation
	CGAffineTransform rotationTransform = CGAffineTransformMakeRotation([self rotation]);
	overlayWindow.transform = rotationTransform;
	overlayWindow.bounds = CGRectMake(0.f, 0.f, [self screenSize].width, [self screenSize].height);
}

- (void)createTopBar {
    if (topBar != nil) {
		return;
	}
	
	topBar = [[UIView alloc] initWithFrame:CGRectMake(0.f, 0.f, [self screenSize].width, kStatusbarHeight)];
	topBar.alpha = 0;
	[overlayWindow addSubview:topBar];
}

- (void)createProgressBar {
    if (progressBar != nil) {
		return;
	}
	
	progressBar = [[UIView alloc] initWithFrame:CGRectMake(0.f, 0.f, 0.f, kStatusbarHeight - 1)];
	progressBar.backgroundColor = [UIColor colorWithRed:75.0/255.0 green:200.0/255.0 blue:0.0/255.0 alpha:0.45];
	
	[topBar addSubview:progressBar];
	[topBar sendSubviewToBack:progressBar];
}

- (void)createProgressIndicator {
    if (progressIndicator != nil) {
		return;
	}
	
	progressIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
	progressIndicator.center = CGPointMake(0, kStatusbarHeight / 2.0);
	progressIndicator.transform = CGAffineTransformMakeScale(0.7, 0.7);
	progressIndicator.hidden = YES;
	
	[topBar addSubview:progressIndicator];
	[topBar bringSubviewToFront:progressIndicator];
}

- (void)createStringLabel {
    if (stringLabel != nil) {
		return;
	}
	
	stringLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	stringLabel.textColor = [UIColor whiteColor];
	stringLabel.backgroundColor = [UIColor clearColor];
	stringLabel.adjustsFontSizeToFitWidth = YES;
	stringLabel.textAlignment = NSTextAlignmentCenter;
	stringLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
	stringLabel.font = [UIFont boldSystemFontOfSize:13.0];
	stringLabel.numberOfLines = 0;
	stringLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    
	[topBar addSubview:stringLabel];
	[topBar bringSubviewToFront:stringLabel];
}

#pragma mark - Handle Rotation

- (CGFloat)rotation {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    CGFloat rotation = 0.f;
    switch (interfaceOrientation) {
        case UIInterfaceOrientationLandscapeLeft:
			rotation = -M_PI_2;
			break;
			
        case UIInterfaceOrientationLandscapeRight:
			rotation = M_PI_2;
			break;
			
        case UIInterfaceOrientationPortraitUpsideDown:
			rotation = M_PI;
			break;
			
        case UIInterfaceOrientationPortrait:
        default:
			break;
    }
    return rotation;
}

- (CGSize)screenSize {
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    CGSize screenSize = [[UIScreen mainScreen] bounds].size;
	
	if (UIInterfaceOrientationIsLandscape(interfaceOrientation)) {
		screenSize = CGSizeMake(screenSize.height, screenSize.width);
	}
    
    return screenSize;
}

- (void)handleRoration:(id)sender {
    // Based on http://stackoverflow.com/questions/8774495/view-on-top-of-everything-uiwindow-subview-vs-uiviewcontroller-subview
    
    CGAffineTransform rotationTransform = CGAffineTransformMakeRotation([self rotation]);
    [UIView animateWithDuration:[[UIApplication sharedApplication] statusBarOrientationAnimationDuration] animations:^{
		overlayWindow.transform = rotationTransform;
		// Transform invalidates the frame, so use bounds/center
		overlayWindow.bounds = CGRectMake(0.f, 0.f, [self screenSize].width, [self screenSize].height);
	}];
}

@end
