/*******************************************************************************************************************
 *                                     MagicKeyboard :: MKButton                                                   *
 *******************************************************************************************************************
 * File:             MKButton.h                                                                                    *
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

#pragma mark Interface
@interface MKButton : NSObject <NSCopying> {
	NSInteger buttonID;
	NSInteger xStart;
	NSInteger xEnd;
	NSInteger yStart;
	NSInteger yEnd;
	NSString *keycode;
	NSString *letter;
}

#pragma mark Methods
- (id)initWithID:(NSInteger)aButtonID xStart:(NSInteger)aXStart xEnd:(NSInteger)aXEnd yStart:(NSInteger)aYStart
	    yEnd:(NSInteger)aYEnd;

+ (id)button;
+ (id)buttonWithID:(NSInteger)aButtonID xStart:(NSInteger)aXStart xEnd:(NSInteger)aXEnd yStart:(NSInteger)aYStart
	      yEnd:(NSInteger)aYEnd;
+ (id)buttonWithButton:(MKButton *)aButton letter:(NSString *)aLetter keycode:(NSString *)aKeycode;

- (id)assignLetter:(NSString *)aLetter keycode:(NSString *)aKeyCode;

- (BOOL)containsPoint:(NSPoint)aPoint size:(NSSize)circleSize;

#pragma mark Properties
@property (assign) NSInteger buttonID;
@property (assign) NSInteger xStart;
@property (assign) NSInteger xEnd;
@property (assign) NSInteger yStart;
@property (assign) NSInteger yEnd;
@property (retain) NSString *keycode;
@property (retain) NSString *letter;

@end