//
//  CheckerCell.h
//  bg
//
//  Created by Leo on 9/10/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface CheckerCell : UITableViewCell
{
	UIImageView* imageView;
}

@property (nonatomic, retain) UIImageView* imageView;

- (void)setColor:(int)colorIndex;

@end
