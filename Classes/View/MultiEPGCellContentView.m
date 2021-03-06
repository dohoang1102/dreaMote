//
//  MultiEPGCellContentView.m
//  dreaMote
//
//  Created by Moritz Venn on 11.11.11.
//  Copyright (c) 2011 Moritz Venn. All rights reserved.
//

#import "MultiEPGCellContentView.h"

#import <Constants.h>
#import <Objects/Generic/Event.h>

#if IS_DEBUG()
	#import "NSDateFormatter+FuzzyFormatting.h"
#endif

/*!
 @brief Private functions of ServiceTableViewCell.
 */
@interface MultiEPGCellContentView()
/*!
 @brief Currently playing event or nil if not in range.
 */
@property (nonatomic, strong) NSObject<EventProtocol> *currentEvent;
@end

@implementation MultiEPGCellContentView

@synthesize begin, currentEvent, highlighted;

- (id)initWithFrame:(CGRect)frame
{
    if((self = [super initWithFrame:frame]))
	{
		self.backgroundColor = [UIColor clearColor];
		self.contentMode = UIViewContentModeRedraw;
		_secondsSinceBegin = NSNotFound;
    }
    return self;
}

/* getter of events property */
- (NSArray *)events
{
	@synchronized(self)
	{
		return _events;
	}
}

/* setter of events property */
- (void)setEvents:(NSArray *)new
{
	@synchronized(self)
	{
		if(_events == new) return;
		_events = new;

		self.currentEvent = nil;

		// wait a few moments with the redraw until we know when 'now' is
	}
}

/* getter of secondsSinceBegin property */
- (NSTimeInterval)secondsSinceBegin
{
	return _secondsSinceBegin;
}

/* setter of now property */
- (void)setSecondsSinceBegin:(NSTimeInterval)secondsSinceBegin
{
	_secondsSinceBegin = secondsSinceBegin;

	const float interval = [[NSUserDefaults standardUserDefaults] floatForKey:kMultiEPGInterval];
	if(currentEvent && [currentEvent.begin timeIntervalSinceDate:begin] <= secondsSinceBegin && [currentEvent.end timeIntervalSinceDate:begin] > secondsSinceBegin)
	{
		// nothing (current event still active)
	}
	// no current event or not in timespan any longer
	else
	{
		if(secondsSinceBegin < 0)
		{
			NSObject<EventProtocol> *firstObject = [_events count] ? [_events objectAtIndex:0] : nil;
			if(firstObject && [firstObject.begin timeIntervalSinceDate:begin] < secondsSinceBegin)
			{
				self.currentEvent = firstObject;
			}
		}
		else if(_secondsSinceBegin > interval)
		{
			NSObject<EventProtocol> *lastObject = [_events lastObject];
			if(lastObject && [lastObject.end timeIntervalSinceDate:begin] > secondsSinceBegin)
			{
				self.currentEvent = lastObject;
			}
		}
		else
		{
			for(NSObject<EventProtocol> *event in _events)
			{
				if([event.begin timeIntervalSinceDate:begin] <= secondsSinceBegin && [event.end timeIntervalSinceDate:begin] > secondsSinceBegin)
				{
					self.currentEvent = event;
					break;
				}
			}
		}
	}

	// Redraw
	[self setNeedsDisplay];
}

- (void)setHighlighted:(BOOL)lit
{
	if(highlighted != lit)
	{
		highlighted = lit;
		[self setNeedsDisplay];
	}
}

- (NSObject<EventProtocol> *)eventAtPoint:(CGPoint)point
{
	const CGFloat widthPerSecond = self.bounds.size.width / [[NSUserDefaults standardUserDefaults] floatForKey:kMultiEPGInterval];

	// NOTE: we iterate through the array and check the previous events begin against our begin
	// this should fix possible problems with overlapping events
	NSObject<EventProtocol> *prevEvent = nil;
	for(NSObject<EventProtocol> *event in _events)
	{
		if(prevEvent == nil)
		{
			prevEvent = event;
			continue;
		}
		const CGFloat eventBegin = [prevEvent.begin timeIntervalSinceDate:begin];
		const CGFloat leftLine = (eventBegin < 0) ? 0 : eventBegin * widthPerSecond;
		const CGFloat rightLine = [event.begin timeIntervalSinceDate:begin] * widthPerSecond;

		// if x within bounds of previous event, return it…
		if(point.x >= leftLine && point.x < rightLine)
		{
			return prevEvent;
		}
		prevEvent = event;
	}
	return prevEvent; // last event or nil if there are none
}

/* draw cell */
- (void)drawRect:(CGRect)rect
{
	const CGRect contentRect = self.bounds;
	const CGFloat multiEpgInterval = [[NSUserDefaults standardUserDefaults] floatForKey:kMultiEPGInterval];
	const CGFloat widthPerSecond = contentRect.size.width / multiEpgInterval;
	const CGFloat boundsX = contentRect.origin.x;
	const CGFloat boundsHeight = contentRect.size.height;
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextSetLineWidth(ctx, 0.25f);

	DreamoteConfiguration *singleton = [DreamoteConfiguration singleton];
	UIColor *color = nil;
	if(highlighted)
	{
		color = singleton.highlightedTextColor;
	}
	else
	{
		color = singleton.textColor;
	}
	UIFont *font = [UIFont systemFontOfSize:singleton.multiEpgFontSize];
	[color set];

	CGRect curRect;
	CGSize fullHeight;

	// create a mutable copy of the array
	NSMutableArray *events = [_events mutableCopy];

	// add sentinel element to enforce boundaries
	NSObject<EventProtocol> *sentinel = [[GenericEvent alloc] init];
	[events addObject:sentinel];
	sentinel.begin = [begin dateByAddingTimeInterval:multiEpgInterval];

	// remove first element (there has to be at least the sentinel) to set initial values
	NSObject<EventProtocol> *prevEvent = [events objectAtIndex:0];
	[events removeObjectAtIndex:0];
	CGFloat prevX = [prevEvent.begin timeIntervalSinceDate:begin];
	if(prevX < 0)
		prevX = 0;
	else
		prevX *= widthPerSecond;

	// iterate over elements 1 to n+1 while actually working on element i-1 ;)
	for(NSObject<EventProtocol> *event in events)
	{
		// draw left line
		CGContextMoveToPoint(ctx, prevX, 0);
		CGContextAddLineToPoint(ctx, prevX, boundsHeight);

		const CGFloat newX = [event.begin timeIntervalSinceDate:begin] * widthPerSecond;
		curRect = CGRectMake(boundsX + prevX, 0, newX - prevX, boundsHeight);

		// handle current event
		if(prevEvent == self.currentEvent)
		{
			UIImage *currentBgImage = currentEvent ? singleton.multiEpgCurrentBackground : nil;
			UIColor *currentBgColor = currentEvent && !currentBgImage ? singleton.multiEpgCurrentFillColor : nil;
			// draw image
			if(currentBgImage)
			{
				// TODO: any way to optimize this?
				[currentBgImage drawInRect:curRect];
			}
			// fill color
			else
			{
				[currentBgColor setFill];
				CGContextFillRect(ctx, curRect);
			}
		}

		[color setFill];
		fullHeight = [prevEvent.title sizeWithFont:font constrainedToSize:curRect.size lineBreakMode:UILineBreakModeClip];
		curRect = CGRectMake (CGRectGetMidX(curRect) - fullHeight.width / 2.0,
									  CGRectGetMidY(curRect) - fullHeight.height / 2.0,
									  fullHeight.width, fullHeight.height);
		[prevEvent.title drawInRect:curRect withFont:font lineBreakMode:UILineBreakModeTailTruncation alignment:UITextAlignmentCenter];

		prevX = newX;
		prevEvent = event;
	}
	CGContextStrokePath(ctx);
	if(_secondsSinceBegin > -1 && _secondsSinceBegin < multiEpgInterval)
	{
		const CGFloat xPosNow = (CGFloat)_secondsSinceBegin * widthPerSecond;
		CGContextSetRGBStrokeColor(ctx, 1.0f, 0.0f, 0.0f, 0.8f);
		CGContextSetLineWidth(ctx, 0.4f);
		CGContextMoveToPoint(ctx, xPosNow, 0);
		CGContextAddLineToPoint(ctx, xPosNow, boundsHeight);
		CGContextStrokePath(ctx);
	}

	//[super drawRect:rect];
}

@end
