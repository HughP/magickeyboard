/*******************************************************************************************************************
 *                                     MagicKeyboard :: MKKeyboard                                                 *
 *******************************************************************************************************************
 * File:             MKController.m                                                                                *
 * Copyright:        (c) 2011 alimonda.com; Emanuele Alimonda                                                      *
 *                   This software is free software: you can redistribute it and/or modify it under the terms of   *
 *                       the GNU General Public License as published by the Free Software Foundation, either       *
 *                       version 3 of the License, or (at your option) any later version.                          *
 *                   This software is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;    *
 *                       without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. *
 *                   See the GNU General Public License for more details.                                          *
 *                   You should have received a copy of the GNU General Public License along with this program.    *
 *                       If not, see <http://www.gnu.org/licenses/>                                                *
 *******************************************************************************************************************/

#import "MKController.h"
#import <FeedbackReporter/FRFeedbackReporter.h>
#import "MKPreferencesController.h"
#import "AlphaAnimation.h"
#import "MKButton.h"
#import "MKLayout.h"
#import "MKDevice.h"
#import "MKFinger.h"
#import "MKKeyboard.h"

#pragma mark Global Variables
// FIXME: Eww, globals
id refToSelf;
dispatch_queue_t myQueue;

#pragma mark Constants
const double kSamplingInterval = 0.02;

#pragma mark -
#pragma mark Interface (private)
@interface MKController ()
#pragma mark Private methods and properties

- (void)animateImage:(NSImageView *)image;
- (void)processTouch:(Touch *)touch onDevice:(MKDevice *)device;
typedef void *MTDeviceRef;
typedef int (*MTContactCallbackFunction)(int, Touch *, int, double, int);

int callback( int device, Touch *data, int nTouches, double timestamp, int frame );

#pragma mark Apple Private Frameworks
MTDeviceRef MTDeviceCreateDefault();
void MTRegisterContactFrameCallback(MTDeviceRef, MTContactCallbackFunction);
void MTDeviceStart(MTDeviceRef, int); // thanks comex
CFMutableArrayRef MTDeviceCreateList(void); //returns a CFMutableArrayRef array of all multitouch devices

@end

#pragma mark -
#pragma mark Implementation
@implementation MKController

CGEventRef processEventTap(CGEventTapProxy tapProxy, CGEventType type, CGEventRef event, void *refcon) {
#pragma unused (tapProxy)
	MKController *controller = refcon;
	if (![controller isTracking]) {
		CGAssociateMouseAndMouseCursorPosition(true);
		return event;
	}
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if (![defaults boolForKey:kSettingIgnoreTrackpadInput] || ![defaults boolForKey:kSettingGlobalHotkeyEnabled])
		return event;

	NSEvent *myEvent = [NSEvent eventWithCGEvent:event];
	switch (type) {
	case kCGEventLeftMouseDown:
	case kCGEventLeftMouseUp:
		if ([myEvent subtype] == 3) {
			return NULL; // Ignore clicks
		}
		break;
	case kCGEventMouseMoved:
		if ([myEvent subtype] == 3) {
			CGAssociateMouseAndMouseCursorPosition(false);
//			if ([myEvent deltaX] == 0 || [myEvent deltaY] == 0)
//				break;
//			NSPoint mouseLocation = [NSEvent mouseLocation];
//			NSInteger x = CGEventGetIntegerValueField(event, kCGMouseEventDeltaX);
//			NSInteger y = CGEventGetIntegerValueField(event, kCGMouseEventDeltaY);
//			NSLog(@"%f,%f / %f,%f", mouseLocation.x, mouseLocation.y, [myEvent deltaX], [myEvent deltaY]);
//			CGWarpMouseCursorPosition(CGPointMake(mouseLocation.x/*+[myEvent deltaX]*/, mouseLocation.y/*-[myEvent deltaY]*/));
		} else
			CGAssociateMouseAndMouseCursorPosition(true);
		break;
	}
	return event;   // return the tapped event (might have been modified, or set to NULL)
	// returning NULL means the event isn't passed forward
}

#pragma mark Initialization
- (id)init {
	self = [super init];
	if (self) {
		NSImage *tapImageSrc = [NSImage imageNamed:@"Tap.png"];
		tapImage = [[NSImage alloc] initWithSize:[tapImageSrc size]];
		// Set tapImage's alpha opacity to 70%
		[tapImage lockFocus];
		[tapImageSrc drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:0.7];
		[tapImage unlockFocus];
		tracking = YES;
		holdingCorner = NO;
		currentLayout = nil;
		keyLabels = [[NSMutableArray alloc] init];
		refToSelf = self;
		tapSounds = [[NSMutableDictionary alloc] init];
		myQueue = dispatch_queue_create([[NSString stringWithFormat:@"%@.myqueue",
						  [[NSBundle mainBundle] bundleIdentifier]] cStringUsingEncoding:
						 NSASCIIStringEncoding], 0);
		devices = [[NSMutableArray alloc] init];
		keyboard = [[MKKeyboard alloc] init];
		layouts = [[NSMutableDictionary alloc] init];
		//MTDeviceRef dev = MTDeviceCreateDefault(1);
		//MTRegisterContactFrameCallback(dev, callback);
		//MTDeviceStart(dev, 0);
		eventTap = NULL;
	}
	return self;
}

- (void)loadLayouts {
	[layoutsMenu removeAllItems];
	[layouts removeAllObjects];
	NSArray *foundLayouts = [[NSBundle mainBundle] pathsForResourcesOfType:@"plist" inDirectory:kLayoutsDirectory];
	for (NSString *eachLayout in foundLayouts) {
		NSString *layoutName = [[eachLayout stringByDeletingPathExtension] lastPathComponent];
		MKLayout *thisLayout = [MKLayout layoutWithName:layoutName];
		if (thisLayout && [thisLayout isValid]) {
			[layouts setObject:thisLayout forKey:layoutName];
			[[layoutsMenu addItemWithTitle:[thisLayout layoutName] action:@selector(switchLayout:)
					 keyEquivalent:@""] setTarget:self];
		}
	}
}

- (void)loadSounds {
	[tapSounds removeAllObjects];
	NSArray *foundSounds = [[NSBundle mainBundle] pathsForResourcesOfType:@"aiff" inDirectory:kSoundsDirectory];
	for (NSString *eachSound in foundSounds) {
		NSSound *thisSound = [[[NSSound alloc] initWithContentsOfFile:eachSound byReference:YES] autorelease];
		NSString *soundName = [[eachSound stringByDeletingPathExtension] lastPathComponent];
		NSString *soundGroup = [soundName stringByDeletingPathExtension];
		if ([tapSounds objectForKey:soundGroup] == nil)
			[tapSounds setObject:[NSMutableArray arrayWithObject:thisSound] forKey:soundGroup];
		else
			[[tapSounds objectForKey:soundGroup] addObject:thisSound];
	}
}

- (void)awakeFromNib {
	[self loadSounds];
	[self loadLayouts];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults registerDefaults:[NSDictionary dictionaryWithContentsOfFile:
				    [[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"]]];
	NSString *layout = [defaults stringForKey:kSettingCurrentLayout];
	for (NSMenuItem *eachItem in [layoutsMenu itemArray]) {
		[eachItem setState:0];
	}
#ifdef __DEBUGGING__
	NSLog(@"Default layout is: %@", layout);
#endif // __DEBUGGING__
	[self switchToLayoutNamed:layout];

	NSMutableArray *deviceList = (NSMutableArray *)MTDeviceCreateList(); //grab our device list
	BOOL foundUsableDevice = NO;
	for (NSUInteger i = 0; i < [deviceList count]; i++) {
		MKDevice *thisDevice = [MKDevice deviceWithMTDeviceRef:(MTDeviceInfo *)[deviceList objectAtIndex:i] ID:i];
		if (!thisDevice)
			continue;
#ifdef __DEBUGGING__
		NSLog(@"Checking device: %@", [thisDevice getInfo]);
#endif // __DEBUGGING__
		NSLog(@"Detected %@ (#%lu).", [thisDevice deviceType], (unsigned long)i);
		if ([thisDevice  isUsable])
			[thisDevice setEnabled:YES];
		[[self devices] addObject:thisDevice];
		if (![thisDevice isValid]) {
			NSLog(@"Unrecognized device (#%lu), please report.\nDevice info: %@",
			      (unsigned long)i, [thisDevice getInfo]);
		}
		if (![thisDevice isUsable])
			continue;
		foundUsableDevice = YES;
		MTRegisterContactFrameCallback([deviceList objectAtIndex:i], callback); //assign callback for device
		MTDeviceStart([deviceList objectAtIndex:i], 0); //start sending events
	}
	CFRelease((CFMutableArrayRef)deviceList);

	eventTap = CGEventTapCreate(kCGHIDEventTap, kCGTailAppendEventTap, kCGEventTapOptionDefault,
					      CGEventMaskBit(kCGEventLeftMouseDown)
					      |CGEventMaskBit(kCGEventLeftMouseUp)
					      |CGEventMaskBit(kCGEventMouseMoved),
					      processEventTap, self);
	CFRunLoopSourceRef source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
	if (!source) {   // bail out if the run loop source couldn't be created
		NSLog(@"runloop source failed");
		[NSApp terminate:nil];
	}
//	CFRelease(eventTap);   // can release the tap here as the source will retain it; see below, however
	CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes);
	CFRelease(source);  // can release the source here as the run loop will retain it
	
	if (!foundUsableDevice) {
		NSInteger theResponse = NSRunAlertPanel(@"No supported devices detected",
				@"We couldn't detect any compatible multitouch device connected to your system.\n"
				"If a multitouch devie is connected but not detected, please inform us, so that it'll "
				"be supported soon.\n\n"
				"Do you want to send us feedback about an incompatible device?",
				@"Send Feedback", @"Cancel", nil);
		switch (theResponse) {
		case NSAlertDefaultReturn:    /* "Send Feedback" */
			[[FRFeedbackReporter sharedReporter] reportFeedback];
			break;
		case NSAlertAlternateReturn:  /* "Cancel" */
			break;
		case NSAlertErrorReturn:      /* an error occurred */
			break;
		}
	}
		
	[keyboardImage setAcceptsTouchEvents:NO];
	NSTrackingArea *trackingArea = [[[NSTrackingArea alloc]
					 initWithRect:[keyboardImage frame]
					 options:NSTrackingMouseMoved|NSTrackingActiveInKeyWindow
					 owner:keyboardImage userInfo:nil] autorelease];
	[keyboardImage addTrackingArea:trackingArea];
	[keyboardImage becomeFirstResponder];
}

- (void)dealloc {
	dispatch_release(myQueue);
	[layouts release];
	[tapSounds release];
	[tapImage release];
	[keyLabels release];
	[currentLayout release];
	[devices release];

	[super dealloc];
}

#pragma mark Touch handling
int callback( int device, Touch *data, int nTouches, double timestamp, int frame ) {
#pragma unused (timestamp, frame)
	// This is to avoid leaks
	NSAutoreleasePool *thePool = [[NSAutoreleasePool alloc] init];
	for( int i = 0; i < nTouches; i++ ) {
		Touch *t = &data[i];
		MKDevice *thisDevice = nil;
		NSUInteger j = 0;
		for (j = 0; j < [[refToSelf devices] count]; j++) {
			thisDevice = (MKDevice *)[[refToSelf devices] objectAtIndex:j];
			if ([thisDevice devPtr] == device)
				break;
		}
		if (j >= [[refToSelf devices] count]) {
			NSLog(@"Device (%x) not found.  Ignoring touch.", device);
			continue;
		}
		[refToSelf processTouch:t onDevice:thisDevice];
	}
	// Time to release... or drain now.
	[thePool drain];
	return 0;
}

- (void)processTouch:(Touch *)touch onDevice:(MKDevice *)device {
	if (![self isTracking])
		return;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:kSettingHoldFnToTrack]) {
		CGEventRef event = CGEventCreate(NULL);
		CGEventFlags modifiers = CGEventGetFlags(event);
		CFRelease(event);
		if (!(modifiers&kCGEventFlagMaskSecondaryFn))
			return;
	}

	if (touch->identifier > kMultitouchFingersMax || touch->identifier <= 0) // Sanity check
		return;
	
	// layout height * verticalMultiplier => (virtual) device height
	CGFloat layoutHeight = [currentLayout layoutSize].height;
	CGFloat verticalMultiplier = MAX(1.0, [currentLayout ratio] / [device ratio]);
	CGFloat deviceHeight = verticalMultiplier * layoutHeight;
	CGFloat verticalPosition = [defaults integerForKey:kSettingVerticalPosition] / 100.0;
	CGFloat verticalOrigin = MAX(0.0, deviceHeight * verticalPosition - 0.5 * layoutHeight);
	verticalOrigin = floor(MIN(deviceHeight-layoutHeight, verticalOrigin))+17;

	// layout height * horizontalMultiplier => (virtual) device height
	CGFloat layoutWidth = [currentLayout layoutSize].width;
	CGFloat horizontalMultiplier = MAX(1.0, [device ratio] / [currentLayout ratio]);
	CGFloat deviceWidth = horizontalMultiplier * layoutWidth;
	CGFloat horizontalPosition = [defaults integerForKey:kSettingHorizontalPosition] / 100.0;
	CGFloat horizontalOrigin = MAX(0.0, deviceWidth * horizontalPosition - 0.5 * layoutWidth);
	horizontalOrigin = floor(MIN(deviceWidth-layoutWidth, horizontalOrigin))+17;

	NSRect imgBox = NSMakeRect((CGFloat)(deviceWidth*touch->normalized.pos.x-horizontalOrigin),
				   (CGFloat)(deviceHeight*touch->normalized.pos.y-verticalOrigin),
				   33, 34);
	
	MKFinger *thisFinger = [[device fingers] objectAtIndex:touch->identifier-1]; // FIXME: Make sure it exists

	// Check for corner touch
	if ([defaults boolForKey:kSettingHoldCornerToTrack]) {
		NSInteger st = touch->state;
		if (st == 1 || st == 7 || touch->timestamp < [thisFinger last] + kSamplingInterval) {
			// Position is a bitmask where the 0x1 bit means "right" and the 0x2 bit means "top"
			NSInteger position = [defaults integerForKey:kSettingHoldCornerPosition];
			NSInteger positionX = (position&0x1) ? 1 : 0;
			NSInteger positionY = (position&0x2) ? 1 : 0;
			MKButton *corner = [MKButton buttonWithID:0
							   xStart:positionX*deviceWidth-horizontalOrigin
							     xEnd:positionX*deviceWidth-horizontalOrigin+40
							   yStart:positionY*deviceHeight-verticalOrigin
							     yEnd:positionY*deviceHeight-verticalOrigin+40
							  special:NO];
			if ([corner containsPoint:imgBox.origin size:imgBox.size]) {
				if (st == 7)
					[self setHoldingCorner:NO];
				else
					[self setHoldingCorner:YES];
				[thisFinger setLast:touch->timestamp];
				return;
			}
		}
	} else {
		[self setHoldingCorner:YES];
	}
	
	if (![self isHoldingCorner]) {
		return;
	}

	switch (touch->state) {
	case 1: // FIXME: Constants
		if ([thisFinger isActive])
			return;
		[thisFinger setLast:touch->timestamp];
		[thisFinger setActive:YES];
		NSImageView *tapView = [[[NSImageView alloc] initWithFrame:imgBox] autorelease];
		[tapView setImage:tapImage];
		[keyboardImage addSubview:tapView];
		[thisFinger setTapView:tapView];
		return;
	case 7:
		if (![thisFinger isActive])
			return;
		[thisFinger setActive:NO];
		[thisFinger setLast:touch->timestamp];
		[[thisFinger tapView] removeFromSuperview];
		[thisFinger setTapView:nil];
		break;
	default:
		if (touch->timestamp < [thisFinger last] + kSamplingInterval)
			return;
		[thisFinger setLast:touch->timestamp];
		[[thisFinger tapView] setFrame:imgBox];
		return;
	}
	for (NSUInteger i = 0; i < [[currentLayout currentButtons] count] ; i++) {
		MKButton *button = [[currentLayout currentButtons] objectAtIndex:i];
		if (![button containsPoint:imgBox.origin size:imgBox.size])
			continue;
		if ([button isSingleKeypress] || [button isModifier]) {
			[keyboard sendKeycodeForKey:[button value] type:[button type]];
		} else if ([button isLayoutSwitch]) {
			[self switchToLayoutNamed:[button value]];
		}
		[shiftChk setState:[keyboard isShiftDown]];
		[cmdChk setState:[keyboard isCmdDown]];
		[altChk setState:[keyboard isOptDown]];
		[ctrlChk setState:[keyboard isCtrlDown]];
		NSImageView *tapImageView = [[[NSImageView alloc] initWithFrame:imgBox] autorelease];
		[tapImageView setImage:tapImage];
		NSArray *sound = [tapSounds objectForKey:[defaults stringForKey:kSettingTapSound]];
		if (sound != nil && [sound count] > 0)
			[[sound objectAtIndex:arc4random()%[sound count]] play];
		dispatch_async(myQueue, ^{
			[self animateImage:tapImageView];
		});
		[keyboardImage addSubview:tapImageView];
		tapImageView = nil;
		break;
	}
}

#pragma mark window and layout
#if 0 // Unused
+ (CGFloat)titleBarHeight {
	NSRect frame = NSMakeRect (0, 0, 100, 100);
	NSRect contentRect = [NSWindow contentRectForFrameRect:frame styleMask:NSTitledWindowMask];

	return (frame.size.height - contentRect.size.height - contentRect.origin.y);
}
#endif // 0

- (void)resizeWindowOnSpotWithSize:(NSSize)newSize {
	NSRect originalWindow = [window frame];
	NSRect originalView = [keyboardImage frame];
	NSRect delta = NSMakeRect(originalView.size.width - newSize.width,
				  originalView.size.height - newSize.height,
				  newSize.width - originalView.size.width,
				  newSize.height - originalView.size.height);

	NSRect newRect = NSMakeRect(originalWindow.origin.x + delta.origin.x,
				    originalWindow.origin.y + delta.origin.y,
				    originalWindow.size.width + delta.size.width,
				    originalWindow.size.height + delta.size.height);
	[window setFrame:newRect display:YES animate:YES];
}

- (IBAction)switchLayout:(id)sender {
	if ([sender state])
		return;
	NSString *layoutName = [sender title];
	NSString *layoutIdentifier = nil;
	
	for (MKLayout *eachLayout in [layouts allValues]) {
		if ([[eachLayout layoutName] isEqualToString:layoutName]) {
			layoutIdentifier = [eachLayout layoutIdentifier];
		}
	}
	if (!layoutIdentifier)
		return;

	if (![self switchToLayoutNamed:layoutIdentifier])
		return;
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setValue:[[self currentLayout] layoutIdentifier] forKey:kSettingCurrentLayout];
	[defaults synchronize];
}

- (BOOL)switchToLayoutNamed:(NSString *)layoutName {
	MKLayout *layout = [layouts valueForKey:layoutName];
	if (layout) {
		[self setCurrentLayout:layout];
		for (NSMenuItem *eachItem in [layoutsMenu itemArray]) {
			if ([[eachItem title] isEqualToString:[layout layoutName]])
				[eachItem setState:1];
			else
				[eachItem setState:0];
		}
		return YES;
	}
	return NO;
}

- (void)setCurrentLayout:(MKLayout *)newLayout {
#ifdef __DEBUGGING__
	NSLog(@"Switching to layout: %@", [newLayout layoutName]);
#endif // __DEBUGGING__
	while ([keyLabels count] > 0) {
		NSTextField *thisLabel = [keyLabels objectAtIndex:0];
		[thisLabel removeFromSuperview];
		[keyLabels removeObject:thisLabel];
	}

	[currentLayout autorelease];
	currentLayout = [newLayout retain];
	[self resizeWindowOnSpotWithSize:[newLayout layoutSize]];
	[keyboardImage setImage:[newLayout keyboardImage]];
	
	NSArray *layoutLabels = [newLayout createLabelsUsingSymbolsForLayouts:layouts];
	for (NSTextField *eachLabel in layoutLabels) {
		[keyLabels addObject:eachLabel];
		[keyboardImage addSubview:eachLabel];
	}
}

- (void)animateImage:(NSImageView *)imageView {
	AlphaAnimation *animation = [[[AlphaAnimation alloc] initWithDuration:0.2 effect:AAFadeOut object:imageView]
				     autorelease];
	[animation setAnimationBlockingMode:NSAnimationBlocking];
	[animation startAnimation];
	[imageView removeFromSuperview];
}

- (BOOL)acceptsFirstResponder {
	return NO;
}

#pragma mark Utilities
- (NSArray *)deviceInfoList {
	NSMutableArray *devs = [NSMutableArray array];
	for (MKDevice *eachDevice in [self devices]) {
		NSDictionary *thisDeviceInfo = [NSDictionary dictionaryWithObjectsAndKeys:
						[NSNumber numberWithBool:[eachDevice isEnabled]], @"State",
						[eachDevice getInfo], @"Info",
						nil];
		[devs addObject:thisDeviceInfo];
	}
	return devs;
}

#pragma mark -
#pragma mark Properties
- (BOOL)isTracking {
	return tracking;
}

- (void)setTracking:(BOOL)trackingState {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	tracking = trackingState;
	BOOL tapState = (trackingState
			 && [defaults boolForKey:kSettingIgnoreTrackpadInput]
			 && [defaults boolForKey:kSettingGlobalHotkeyEnabled]);
	CGEventTapEnable(eventTap, tapState);
	CGAssociateMouseAndMouseCursorPosition(!tapState);
}

@synthesize holdingCorner;
@synthesize currentLayout;
@synthesize devices;
@synthesize keyboard;
@synthesize layouts;
@synthesize tapSounds;

@end
