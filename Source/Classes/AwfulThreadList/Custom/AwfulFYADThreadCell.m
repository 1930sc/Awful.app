//
//  AwfulFYADThreadCell.m
//  Awful
//
//  Created by me on 5/17/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulFYADThreadCell.h"

@implementation AwfulFYADThreadCell


-(void)configureForThread:(AwfulThread *)thread {
    [super configureForThread:thread];

    self.badgeColor = [UIColor purpleColor];
}


+(UIColor*) textColor { return [UIColor blackColor]; }
+(UIColor*) backgroundColor { return  [UIColor colorWithRed:1 green:.8 blue:1 alpha:1]; }
+(UIFont*) textLabelFont { return [UIFont fontWithName:@"MarkerFelt-Wide" size:18]; }
+(UIFont*) detailLabelFont { return [UIFont fontWithName:@"Marker Felt" size:12]; }

@end
