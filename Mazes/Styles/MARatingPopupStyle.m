//
//  MARatingPopupStyle.m
//  Mazes
//
//  Created by Andre Muis on 4/28/12.
//  Copyright (c) 2012 Andre Muis. All rights reserved.
//

#import "MARatingPopupStyle.h"

#import "MAColors.h"

@implementation MARatingPopupStyle

- (id)initWithColors: (MAColors *)colors
{
    self = [super init];
	
    if (self)
	{
        _backgroundColor = colors.lightYellow2Color;
    }
  
    return self;
}

@end
