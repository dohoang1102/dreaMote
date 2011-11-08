//
//  MainTableViewCell.m
//  dreaMote
//
//  Created by Moritz Venn on 08.03.08.
//  Copyright 2008-2011 Moritz Venn. All rights reserved.
//

#import "MainTableViewCell.h"
#import "Constants.h"

/*!
 @brief Cell identifier for this cell.
 */
NSString *kMainCell_ID = @"MainCell_ID";

@implementation MainTableViewCell

@synthesize dataDictionary = _dataDictionary;

/* initialize */
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
	if((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]))
	{
		// you can do this here specifically or at the table level for all cells
		self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

		// Create label views to contain the various pieces of text that make up the cell.
		// Add these as subviews.
		_nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];	// layoutSubViews will decide the final frame
		_nameLabel.backgroundColor = [UIColor clearColor];
		_nameLabel.opaque = NO;
		_nameLabel.textColor = [DreamoteConfiguration singleton].textColor;
		_nameLabel.highlightedTextColor = [DreamoteConfiguration singleton].highlightedTextColor;
		_nameLabel.font = [UIFont boldSystemFontOfSize:kMainTextSize];
		[self.contentView addSubview:_nameLabel];

		// Explanation label
		_explainLabel = [[UILabel alloc] initWithFrame:CGRectZero];	// layoutSubViews will decide the final frame
		_explainLabel.backgroundColor = [UIColor clearColor];
		_explainLabel.opaque = NO;
		_explainLabel.textColor = [DreamoteConfiguration singleton].detailsTextColor;
		_explainLabel.highlightedTextColor = [DreamoteConfiguration singleton].highlightedDetailsTextColor;
		_explainLabel.font = [UIFont systemFontOfSize:kMainDetailsSize];
		_explainLabel.adjustsFontSizeToFitWidth = YES;
		[self.contentView addSubview:_explainLabel];
	}
	
	return self;
}

/* layout */
- (void)layoutSubviews
{
	CGRect frame;

	[super layoutSubviews];
	const CGRect contentRect = [self.contentView bounds];
	CGFloat offset = (IS_IPAD()) ? 3 : 0;

	frame = CGRectMake(contentRect.origin.x + kLeftMargin, offset, contentRect.size.width - kRightMargin, 26);
	_nameLabel.frame = frame;

	offset = (IS_IPAD()) ? 28 : 21;
	frame = CGRectMake(contentRect.origin.x + kLeftMargin, offset, contentRect.size.width - kRightMargin, 22);
	_explainLabel.frame = frame;
}

/* (de)select */
- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
	[super setSelected:selected animated:animated];
	
	// when the selected state changes, set the highlighted state of the lables accordingly
	_nameLabel.highlighted = selected;
}

/* assign item */
- (void)setDataDictionary:(NSDictionary *)newDictionary
{
	// Abort if same item assigned
	if (_dataDictionary == newDictionary) return;
	_dataDictionary = newDictionary;
	
	// update value in subviews
	_nameLabel.text = [_dataDictionary objectForKey:@"title"];
	_explainLabel.text = [_dataDictionary objectForKey:@"explainText"];

	// Redraw
	[self setNeedsDisplay];
}

@end
