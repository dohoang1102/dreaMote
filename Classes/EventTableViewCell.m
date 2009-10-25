//
//  EventTableViewCell.m
//  dreaMote
//
//  Created by Moritz Venn on 09.03.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "Constants.h"
#import "EventTableViewCell.h"

/*!
 @brief Cell identifier for this cell.
 */
NSString *kEventCell_ID = @"EventCell_ID";

/*!
 @brief Private functions of EventTableViewCell.
 */
@interface EventTableViewCell()
/*!
 @brief Private helper to create a label.
 */
- (UILabel *)newLabelWithPrimaryColor:(UIColor *) primaryColor selectedColor:(UIColor *) selectedColor fontSize:(CGFloat) fontSize bold:(BOOL) bold;
@end

@implementation EventTableViewCell

@synthesize eventNameLabel = _eventNameLabel;
@synthesize eventTimeLabel = _eventTimeLabel;
@synthesize eventServiceLabel = _eventServiceLabel;
@synthesize formatter = _formatter;
@synthesize showService = _showService;


/* deallocate */
- (void)dealloc
{
	[_eventNameLabel release];
	[_eventTimeLabel release];
	[_eventServiceLabel release];
	[_formatter release];
	[_event release];

	[super dealloc];
}

/* initialize */
- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier
{
#ifdef __IPHONE_3_0
	if(self = [super initWithStyle: UITableViewCellStyleDefault reuseIdentifier: reuseIdentifier])
#else
	if(self = [super initWithFrame: frame reuseIdentifier: reuseIdentifier])
#endif
	{
		const UIView *myContentView = self.contentView;

		// you can do this here specifically or at the table level for all cells
		self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

		// A label that displays the Eventname.
		_eventNameLabel = [self newLabelWithPrimaryColor: [UIColor blackColor]
										   selectedColor: [UIColor whiteColor]
												fontSize: 14.0
													bold: YES];
		_eventNameLabel.textAlignment = UITextAlignmentLeft; // default
		[myContentView addSubview: _eventNameLabel];
		
		// A label that displays the Eventtime.
		_eventTimeLabel = [self newLabelWithPrimaryColor: [UIColor blackColor]
										   selectedColor: [UIColor whiteColor]
												fontSize: 10.0
													bold: NO];
		_eventTimeLabel.textAlignment = UITextAlignmentLeft; // default
		[myContentView addSubview: _eventTimeLabel];
		
		// A label that displays the Service name.
		_eventServiceLabel = [self newLabelWithPrimaryColor: [UIColor blackColor]
										   selectedColor: [UIColor whiteColor]
												fontSize: 10.0
													bold: NO];
		_eventServiceLabel.textAlignment = UITextAlignmentRight; // default
		[myContentView addSubview: _eventServiceLabel];
	}

	return self;
}

/* getter for event property */
- (NSObject<EventProtocol> *)event
{
	return _event;
}

/* setter for event property */
- (void)setEvent:(NSObject<EventProtocol> *)newEvent
{
	// Same event, no need to change anything
	if(_event == newEvent) return;

	// Free old event, keep new one
	[_event release];
	_event = [newEvent retain];

	// Check if cache already generated
	if(newEvent.timeString == nil)
	{
		// Not generated, do so...
		[_formatter setDateStyle:NSDateFormatterMediumStyle];
		NSString *begin = [_formatter stringFromDate: newEvent.begin];
		[_formatter setDateStyle:NSDateFormatterNoStyle];
		NSString *end = [_formatter stringFromDate: newEvent.end];
		if(begin && end)
			newEvent.timeString = [NSString stringWithFormat: @"%@ - %@", begin, end];
	}

	// Set Labels
	_eventNameLabel.text = newEvent.title;
	_eventTimeLabel.text = newEvent.timeString;
	if(_showService)
	{
		@try{
			_eventServiceLabel.text = newEvent.service.sname;
		}
		@catch(NSException * e){
			_eventServiceLabel.text = @"";
		}
	}
	else
		_eventServiceLabel.text = @"";

	// Redraw
	[self setNeedsDisplay];
}

/* layout */
- (void)layoutSubviews
{	
	[super layoutSubviews];
	const CGRect contentRect = self.contentView.bounds;
	
	// XXX: We actually should never be editing...
	if (!self.editing) {
		CGRect frame;
		
		// Place the name label.
		frame = CGRectMake(contentRect.origin.x + kLeftMargin, 7, contentRect.size.width - kRightMargin, 16);
		_eventNameLabel.frame = frame;

		// Place the time label.
		frame = CGRectMake(contentRect.origin.x + kLeftMargin, 30, contentRect.size.width - kRightMargin, 14);
		_eventTimeLabel.frame = frame;
		
		// Place the service name label.
		frame = CGRectMake(contentRect.size.width - kRightMargin - 50, 30, 50, 14);
		_eventServiceLabel.frame = frame;
	}
}

/* (de)select */
- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
	UIColor *backgroundColor = nil;

	/*
	 Views are drawn most efficiently when they are opaque and do not have a clear background,
	 so in newLabelForMainText: the labels are made opaque and given a white background.
	 
	 To show selection properly, however, the views need to be transparent (so that the selection
	 color shows through).  
	 */
	[super setSelected:selected animated:animated];

	if (selected) {
		backgroundColor = [UIColor clearColor];
	} else {
		backgroundColor = [UIColor whiteColor];
	}

	// Name Label
	_eventNameLabel.backgroundColor = backgroundColor;
	_eventNameLabel.highlighted = selected;
	_eventNameLabel.opaque = !selected;

	// Time Label
	_eventTimeLabel.backgroundColor = backgroundColor;
	_eventTimeLabel.highlighted = selected;
	_eventTimeLabel.opaque = !selected;

	// Service Label
	_eventServiceLabel.backgroundColor = backgroundColor;
	_eventServiceLabel.highlighted = selected;
	_eventServiceLabel.opaque = !selected;
}

/* Create and configure a label. */
- (UILabel *)newLabelWithPrimaryColor:(UIColor *)primaryColor selectedColor:(UIColor *)selectedColor fontSize:(CGFloat)fontSize bold:(BOOL)bold
{
	UIFont *font;
	UILabel *newLabel;
	if (bold) {
		font = [UIFont boldSystemFontOfSize:fontSize];
	} else {
		font = [UIFont systemFontOfSize:fontSize];
	}
	
	/*
	 Views are drawn most efficiently when they are opaque and do not have a clear background,
	 so in newLabelForMainText: the labels are made opaque and given a white background.
	 
	 To show selection properly, however, the views need to be transparent (so that the selection
	 color shows through).
	 This is handled in setSelected:animated:
	 */
	newLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	newLabel.backgroundColor = [UIColor whiteColor];
	newLabel.opaque = YES;
	newLabel.textColor = primaryColor;
	newLabel.highlightedTextColor = selectedColor;
	newLabel.font = font;
	
	return newLabel;
}

@end
