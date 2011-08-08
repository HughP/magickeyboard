/*******************************************************************************************************************
 *                                     MagicKeyboard :: MKButton                                                   *
 *******************************************************************************************************************
 * File:             MKButton.m                                                                                    *
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

#import "MKButton.h"

#pragma mark Implementation
@implementation MKButton

#pragma mark Initialization
- (id)init {
	self = [super init];
	if (self) {
		letter = nil;
		keycode = nil;
		xStart = 0;
		xEnd = 0;
		yStart = 0;
		yEnd = 0;
	}
	return self;
}

- (id)initWithID:(NSInteger)aButtonID xStart:(NSInteger)aXStart xEnd:(NSInteger)aXEnd yStart:(NSInteger)aYStart
	    yEnd:(NSInteger)aYEnd {
	self = [self init];
	if (self) {
		letter = nil;
		keycode = nil;
		buttonID = aButtonID;
		xStart = aXStart;
		xEnd = aXEnd;
		yStart = aYStart;
		yEnd = aYEnd;
	}
	return self;
}

- (void)dealloc {
	[letter release];
	[keycode release];
	[super dealloc];
}

+ (id)button {
	return [[[[self class] alloc] init] autorelease];
}

+ (id)buttonWithID:(NSInteger)aButtonID xStart:(NSInteger)aXStart xEnd:(NSInteger)aXEnd yStart:(NSInteger)aYStart
	      yEnd:(NSInteger)aYEnd {
	return [[[[self class] alloc] initWithID:aButtonID xStart:aXStart xEnd:aXEnd yStart:aYStart yEnd:aYEnd]
		autorelease];
}

+ (id)buttonWithButton:(MKButton *)aButton letter:(NSString *)aLetter keycode:(NSString *)aKeycode {
	MKButton *thisButton = [aButton copy];
	[thisButton assignLetter:aLetter keycode:aKeycode];
	return [thisButton autorelease];
}

#pragma mark Special setters
- (id)assignLetter:(NSString *)aLetter keycode:(NSString *)aKeyCode {
	[self setLetter:aLetter];
	[self setKeycode:aKeyCode];
	return self;
}

#pragma mark Utilities
- (BOOL)containsPoint:(NSPoint)aPoint size:(NSSize)circleSize {
	if (aPoint.x >= (xStart - (circleSize.width/2))
	    && (aPoint.x + (circleSize.width /2)) <= xEnd
	    && aPoint.y >= (yStart - (circleSize.height/2))
	    && (aPoint.y+(circleSize.height/2)) <=yEnd) {
		return YES;
	}
	return NO;
}

#pragma mark NSCopying
- (id)copyWithZone:(NSZone *)zone {
	return [[[self class] allocWithZone:zone] initWithID:[self buttonID] xStart:[self xStart] xEnd:[self xEnd]
						      yStart:[self yStart] yEnd:[self yEnd]];
}

#pragma mark -
#pragma mark Properties
@synthesize buttonID;
@synthesize xStart;
@synthesize xEnd;
@synthesize yStart;
@synthesize yEnd;
@synthesize keycode;
@synthesize letter;

@end