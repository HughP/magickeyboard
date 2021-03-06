/*******************************************************************************************************************
 *                                     MagicKeyboard :: MKLayoutDefinition                                         *
 *******************************************************************************************************************
 * File:             MKLayoutDefinition.m                                                                          *
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

#import "MKLayoutDefinition.h"
#import "MKButton.h"

#pragma mark Constants
NSString * const kUntitledLayoutDefinition = @"Untitled Layout Definition";

NSString * const kDefinitionDefinitionName = @"DefinitionName";
NSString * const kDefinitionStyle          = @"Style";
NSString * const kDefinitionBackground     = @"Background";
NSString * const kDefinitionFileName       = @"FileName";
NSString * const kDefinitionHeight         = @"Height";
NSString * const kDefinitionWidth          = @"Width";
NSString * const kDefinitionButtons        = @"Buttons";
NSString * const kDefinitionButtonID       = @"ID";
NSString * const kDefinitionXStart         = @"xStart";
NSString * const kDefinitionYStart         = @"yStart";
NSString * const kDefinitionXEnd           = @"xEnd";
NSString * const kDefinitionYEnd           = @"yEnd";
NSString * const kDefinitionSpecialButton  = @"SpecialButton";
NSString * const kDefinitionsDirectory     = @"Definitions";

NSString * const kStyleDefault             = @"Default";
NSString * const kStyleIOs                 = @"iOS";
NSString * const kStyleAluminium           = @"Aluminium";

#pragma mark -
#pragma mark Implementation
@implementation MKLayoutDefinition

#pragma mark Initialization
- (id)init {
	self = [super init];
	if (self) {
		layoutDefinitionName = [[NSString alloc] initWithString:kUntitledLayoutDefinition];
		layoutSize = NSMakeSize(0, 0);
		keyboardImage = nil;
		currentButtons = [[NSMutableArray alloc] init];
		style = [[NSString alloc] initWithString:@"Default"];
		valid = NO;
	}
	return self;
}

- (id)initWithName:(NSString *)loadName {
	self = [self init];
	if (self) {
		[self loadPlist:loadName];
	}
	return self;
}

- (void)dealloc {
	[layoutDefinitionName release];
	[keyboardImage release];
	[currentButtons release];
	[style release];

	[super dealloc];
}

+ (id)layoutDefinition {
	return [[[[self class] alloc] init] autorelease];
}

+ (id)layoutDefinitionWithName:(NSString *)loadName {
	return [[[[self class] alloc] initWithName:loadName] autorelease];
}

- (void)loadPlist:(NSString *)fileName {
#ifdef __DEBUGGING__
	NSLog(@"Loading: %@", fileName);
#endif // __DEBUGGING__
	NSDictionary *definition = [[NSDictionary alloc] initWithContentsOfFile:
				    [[NSBundle mainBundle] pathForResource:fileName ofType:@"plist"
							       inDirectory:kDefinitionsDirectory]];
	if (definition)
		[self setValid:YES];

	[self setLayoutDefinitionName:[definition valueForKey:kDefinitionDefinitionName]];
	[self setStyle:[definition valueForKey:kDefinitionStyle]];
	
	NSDictionary *background = [definition valueForKey:kDefinitionBackground];
	if (background) {
		NSString *imageName = [background valueForKey:kDefinitionFileName];
		[self setKeyboardImage:[[[NSImage alloc] initWithData:
					 [NSData dataWithContentsOfFile:
					  [[NSBundle mainBundle] pathForResource:imageName ofType:@"png"
								     inDirectory:kDefinitionsDirectory]]] autorelease]];
		[self setLayoutSize:NSMakeSize([[background valueForKey:kDefinitionWidth] integerValue],
					       [[background valueForKey:kDefinitionHeight] integerValue])];
	}
	
	NSDictionary *buttons = [definition valueForKey:kDefinitionButtons];
	if (buttons) {
		for (NSDictionary *eachButton in buttons) {
			NSInteger buttonID = [[eachButton valueForKey:kDefinitionButtonID] integerValue];
			if (buttonID < 1) {
				NSLog(@"Invalid button definition ID: %ld", (unsigned long)buttonID);
				continue;
			}
			for (MKButton *eachExistingButton in currentButtons) {
				if ([eachExistingButton buttonID] == buttonID) {
					NSLog(@"Duplicate button definition ID: %ld", (unsigned long)buttonID);
				}
			}
			NSInteger xStart = [[eachButton valueForKey:kDefinitionXStart] integerValue];
			NSInteger xEnd = [[eachButton valueForKey:kDefinitionXEnd] integerValue];
			NSInteger yStart = [[eachButton valueForKey:kDefinitionYStart] integerValue];
			NSInteger yEnd = [[eachButton valueForKey:kDefinitionYEnd] integerValue];
			BOOL specialButton = [[eachButton valueForKey:kDefinitionSpecialButton] boolValue];
			MKButton *newButton = [MKButton buttonWithID:buttonID xStart:xStart xEnd:xEnd yStart:yStart
								yEnd:yEnd special:specialButton];
			[currentButtons addObject:newButton];
		}
	}
	
	if (![self layoutDefinitionName])
		[self setLayoutDefinitionName:kUntitledLayoutDefinition];
	if (![self style])
		[self setStyle:kStyleDefault];
	if (![self keyboardImage])
		[self setValid:NO];
	NSSize size = [self layoutSize];
	if (size.height <= 0 || size.width <= 0)
		[self setValid:NO];
}

#pragma mark Special accessors
- (MKButton *)buttonWithID:(NSInteger)buttonID {
	for (MKButton *eachButton in currentButtons) {
		if ([eachButton buttonID] == buttonID)
			return eachButton;
	}
	return nil;
}

#pragma mark -
#pragma mark Properties
@synthesize layoutDefinitionName;
@synthesize layoutSize;
@synthesize keyboardImage;
@synthesize currentButtons;
@synthesize style;
@synthesize valid;

@end
