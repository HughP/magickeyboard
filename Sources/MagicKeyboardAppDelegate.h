/*******************************************************************************************************************
 *                                     MagicKeyboard :: MagicKeyboardAppDelegate                                   *
 *******************************************************************************************************************
 * File:             MagicKeyboardAppDelegate.h                                                                    *
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

#import <Cocoa/Cocoa.h>
#import <FeedbackReporter/FRFeedbackReporter.h>
#import "MKController.h"

@class MKPreferencesController;

#pragma mark Interface
@interface MagicKeyboardAppDelegate : NSObject <NSApplicationDelegate, FRFeedbackReporterDelegate> {
	MKPreferencesController *prefsController;
	IBOutlet NSWindow *window;
	IBOutlet NSMenu *statusMenu;
	IBOutlet MKController *magicKeyboardController;
	IBOutlet NSMenuItem *disableTrackingMenuItem;
	NSStatusItem *statusBarItem;
}

#pragma mark Methods
- (IBAction)toggleTrackingSelector:(id)sender;
- (void)enableTrackingSelector:(BOOL)state;
- (IBAction)quitSelector:(id)sender;
- (IBAction)submitFeedback:(id)sender;
- (IBAction)setHotkey;

#pragma mark Properties
@property (retain,readonly) MKController *controller;

@end
