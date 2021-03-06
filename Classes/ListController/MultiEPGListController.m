//
//  MultiEPGListController.m
//  dreaMote
//
//  Created by Moritz Venn on 27.01.11.
//  Copyright 2011 Moritz Venn. All rights reserved.
//

#import "MultiEPGListController.h"

#import "AppDelegate.h"
#import "Constants.h"
#import "RemoteConnectorObject.h"
#import "MultiEPGHeaderView.h"

#import "NSDateFormatter+FuzzyFormatting.h"
#import "UIDevice+SystemVersion.h"
#import "UITableViewCell+EasyInit.h"

#import "MultiEPGTableViewCell.h"

#import <XMLReader/SaxXmlReader.h>

@interface MultiEPGListController()
/*!
 @brief Setup and assign toolbar items.
 */
- (void)configureToolbar;

/*!
 @brief Refresh "now" timestamp and take care of timer.
 */
- (void)refreshNow;

/*!
 @brief Entry point for thread fetching events from database.
 */
- (void)readEPG;

/*!
 @brief Activity Indicator.
 */
@property (nonatomic, strong) MBProgressHUD *progressHUD;
@end

@implementation MultiEPGListController

@synthesize multiEpgDelegate;
@synthesize pendingRequests;
@synthesize progressHUD;
@synthesize isSlave;

- (id)init
{
	if((self = [super init]))
	{
		_epgCache = [EPGCache sharedInstance];
		_events = [[NSMutableDictionary alloc] init];
		_services = [[NSMutableArray alloc] init];
		_secondsSinceBegin = -1;
		_servicesToRefresh = -1;
	}
	return self;
}

- (void)dealloc
{
	progressHUD.delegate = nil;
}

/* layout */
- (void)loadView
{
	[super loadView];
	_tableView.delegate = self;
	_tableView.dataSource = self;
	const CGFloat headerHeight = (IS_IPAD()) ? kMultiEPGHeaderHeightIpad : kMultiEPGCellHeight;

	UIView *contentView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
	contentView.autoresizesSubviews = YES;
	contentView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
	self.view = contentView;
	CGRect visibleFrame = CGRectMake(0, headerHeight, contentView.frame.size.width, contentView.frame.size.height-headerHeight);
	_tableView.frame = visibleFrame;
	[contentView addSubview:_tableView];

	_headerView = [[MultiEPGHeaderView alloc] initWithFrame:CGRectMake(0, 0, contentView.frame.size.width, headerHeight)];
	[contentView addSubview:_headerView];

	[self configureToolbar];
	[self theme];
}

- (void)theme
{
	[super theme];
	_headerView.backgroundColor = _tableView.backgroundColor;
	self.view.backgroundColor = _tableView.backgroundColor;
	[_headerView theme];
}

- (void)viewDidUnload
{
	_tableView.tableHeaderView = nil;
	_headerView = nil;

	[super viewDidUnload];
}

- (void)emptyData
{
	[_services removeAllObjects];
	[_events removeAllObjects];
	[_tableView reloadData];
	_xmlReader = nil;
}

- (void)fetchData
{
	@autoreleasepool
	{
		progressHUD = [[MBProgressHUD alloc] initWithView:self.view];
		[self.view addSubview: progressHUD];
		progressHUD.delegate = self;
		[progressHUD setLabelText:NSLocalizedString(@"Loading EPG…", @"Label of Progress HUD in MultiEPG")];
		[progressHUD setDetailsLabelText:NSLocalizedString(@"This can take a while.", @"Details label of Progress HUD in MultiEPG. Since loading the EPG for an entire bouquet took me about 5minutes over WiFi this warning is appropriate.")];
		[progressHUD setMode:MBProgressHUDModeDeterminate];
		progressHUD.progress = 0.0f;
		[progressHUD show:YES];
		progressHUD.taskInProgress = YES;

		_servicesToRefresh = -1;
		_reloading = YES;
		++pendingRequests;
		[_epgCache refreshBouquet:_bouquet delegate:self isRadio:NO];
	}
}

/* about to appear */
- (void)viewWillAppear:(BOOL)animated
{
	if(![EPGCache sharedInstance].reloading)
	{
		NSDate *newBegin = nil;
		if(!_willReapper)
		{
			// reset visible area to to "now"
			newBegin = [NSDate date];
		}
		else
		{
			// don't change visible area, but reload event data
			newBegin = _curBegin;
		}
		self.curBegin = newBegin;

		_willReapper = NO;
	}
	[super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
	const CGFloat headerHeight = (IS_IPAD()) ? 40 : kMultiEPGCellHeight;
	_headerView.frame = CGRectMake(0, 0, self.view.frame.size.width, headerHeight);
	[super viewDidAppear:animated];
}

/* about to disappear */
- (void)viewWillDisappear:(BOOL)animated
{
	if(!_willReapper)
	{
		NSTimer *timer = _refreshTimer;
		_refreshTimer = nil;
		[timer invalidate];
	}
	[super viewWillDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
	return YES;
}

/* getter for bouquet property */
- (NSObject<ServiceProtocol> *)bouquet
{
	return _bouquet;
}

/* setter for bouquet property */
- (void)setBouquet: (NSObject<ServiceProtocol> *)new
{
	++pendingRequests;
	// Same bouquet assigned, abort
	if(_bouquet == new) return;
	_bouquet = [new copy];

	// Free Caches and reload data
	[self emptyData];
	_reloading = YES;
	[_refreshHeaderView setTableLoadingWithinScrollView:_tableView];
	if([self.view superview])
		self.curBegin = [NSDate date];

	// NOTE: We let the ServiceList passively refresh our data, so just die here
}

/* getter of curBegin property */
- (NSDate *)curBegin
{
	return _curBegin;
}

/* setter of curBegin property */
- (void)setCurBegin:(NSDate *)now
{
	NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	NSDateComponents *components = [gregorian components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit) fromDate:now];

	_curBegin = [gregorian dateFromComponents:components];
	[_events removeAllObjects];
	[_tableView reloadData];
	_headerView.begin = _curBegin;

	[self refreshNow];

	++pendingRequests;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ [self readEPG]; });
}

/* getter of willReapper */
- (BOOL)willReappear
{
	return _willReapper;
}

/* setter of willReapper */
- (void)setWillReappear:(BOOL)new
{
	if([_events count]) _willReapper = new;
}

/* go back two hours in time */
- (void)backButtonPressed:(id)sender
{
	NSNumber *timeInterval = [[NSUserDefaults standardUserDefaults] objectForKey:kMultiEPGInterval];
	NSDate *until = [_curBegin dateByAddingTimeInterval:-[timeInterval floatValue]];
	self.curBegin = until;
}

/* go forward two hours in time */
- (void)forwardButtonPressed:(id)sender
{
	NSNumber *timeInterval = [[NSUserDefaults standardUserDefaults] objectForKey:kMultiEPGInterval];
	NSDate *until = [_curBegin dateByAddingTimeInterval:[timeInterval floatValue]];
	self.curBegin = until;
}

/* go to current hour */
- (void)nowButtonPressed:(id)sender
{
	self.curBegin = [NSDate date];
}

/* go to 20:00 */
- (void)primetimeButtonPressed:(id)sender
{
	NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	NSDateComponents *components = [gregorian components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit) fromDate:_curBegin];
	[components setHour: 20];
	self.curBegin = [gregorian dateFromComponents:components];
}

/* setup toolbar */
- (void)configureToolbar
{
	// XXX: use Rewind/FFwd SystemItems for back/forward? Check HIG!
	UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:@"<<"
																   style:UIBarButtonItemStyleBordered
																  target:self
																  action:@selector(backButtonPressed:)];
	UIBarButtonItem *nowButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Now", @"MultiEPG change to current hour")
																  style:UIBarButtonItemStyleBordered
																 target:self
																 action:@selector(nowButtonPressed:)];

	// flex item used to separate the left groups items and right grouped items
	const UIBarButtonItem *flexItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
																					target:nil
																					action:nil];

	UIBarButtonItem *primetimeButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Primetime", @"MultiEPG change to 20:00")
																		style:UIBarButtonItemStyleBordered
																	   target:self
																	   action:@selector(primetimeButtonPressed:)];
	UIBarButtonItem *fwdButton = [[UIBarButtonItem alloc] initWithTitle:@">>"
																  style:UIBarButtonItemStyleBordered
																 target:self
																 action:@selector(forwardButtonPressed:)];

	NSArray *items = [[NSArray alloc] initWithObjects:backButton, nowButton, flexItem, primetimeButton, fwdButton, nil];
	[self setToolbarItems:items animated:NO];

}

/* refresh "now" timestamp */
- (void)refreshNow
{
	// create timer
	if(_refreshTimer == nil)
	{
		_refreshTimer = [NSTimer scheduledTimerWithTimeInterval:60
														 target:self
													   selector:@selector(refreshNow)
													   userInfo:nil
														repeats:YES];
	}

	// check if we are in visible timespan
	NSDate *now = [[NSDate alloc] init];
	_secondsSinceBegin = [now timeIntervalSinceDate:_curBegin];
	[_tableView reloadData];
}

/* entry point for thread fetching epg entries */
- (void)readEPG
{
	@autoreleasepool {

		@synchronized(self)
		{
			NSDate *begin = _curBegin;
			NSNumber *timeInterval = [[NSUserDefaults standardUserDefaults] objectForKey:kMultiEPGInterval];
			NSDate *until = [begin dateByAddingTimeInterval:[timeInterval floatValue]];
			[_epgCache readEPGForTimeIntervalFrom:begin until:until to:self];
		}

	}
}

/* did rotate */
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	[super didRotateFromInterfaceOrientation:fromInterfaceOrientation];

	// TODO: rotate with rest of the screen
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:0.1f];
	const CGFloat headerHeight = (IS_IPAD()) ? 40 : kMultiEPGCellHeight;
	_headerView.frame = CGRectMake(0, 0, self.view.frame.size.width, headerHeight);
	[UIView commitAnimations];
}

#pragma mark -
#pragma mark EGORefreshTableHeaderDelegate methods
#pragma mark -

- (void)egoRefreshTableHeaderDidTriggerRefresh:(EGORefreshTableHeaderView*)view
{
	if(_reloading) return;

	const UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Really %@?", @"Confirmation dialog title"), NSLocalizedString(@"refresh EPG", "used in confirmation dialog: really refresh epg?")]
																   delegate:self
														  cancelButtonTitle:NSLocalizedString(@"Cancel", "")
													 destructiveButtonTitle:NSLocalizedString(@"Refresh", "")
														  otherButtonTitles:nil];
	actionSheet.actionSheetStyle = UIActionSheetStyleDefault;
	if(self.tabBarController == nil)
		[actionSheet showFromTabBar:APP_DELEGATE.tabBarController.tabBar];
	else
		[actionSheet showFromTabBar:self.tabBarController.tabBar];
}

#pragma mark -
#pragma mark UIActionSheetDelegate methods
#pragma mark -

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if(buttonIndex == actionSheet.destructiveButtonIndex)
	{
		[self emptyData];

		// NOTE: not running from our queue as we don't want this to be canceled
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ [self fetchData]; });
	}
	else
	{
		[_refreshHeaderView egoRefreshScrollViewDataSourceDidFinishedLoading:_tableView];
	}
}

#pragma mark -
#pragma mark MBProgressHUDDelegate
#pragma mark -

- (void)hudWasHidden:(MBProgressHUD *)hud
{
	[progressHUD removeFromSuperview];
	self.progressHUD = nil;
}

#pragma mark -
#pragma mark DataSourceDelegate
#pragma mark -

- (void)dataSourceDelegate:(BaseXMLReader *)dataSource errorParsingDocument:(NSError *)error
{
	if(dataSource && dataSource == _xmlReader && [dataSource isKindOfClass:[SaxXmlReader class]])
		_xmlReader = nil;

	if(--pendingRequests == 0)
	{
		// alert user
		const UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Failed to retrieve data", @"Title of Alert when retrieving remote data failed.")
															  message:[error localizedDescription]
															 delegate:nil
													cancelButtonTitle:@"OK"
													otherButtonTitles:nil];
		[alert show];

		[_tableView reloadData];
		_reloading = NO;
		[_refreshHeaderView egoRefreshScrollViewDataSourceDidFinishedLoading:_tableView];
	}
}

- (void)dataSourceDelegateFinishedParsingDocument:(BaseXMLReader *)dataSource
{
	if(dataSource && dataSource == _xmlReader && [dataSource isKindOfClass:[SaxXmlReader class]])
		_xmlReader = nil;

	if(--pendingRequests == 0)
	{
		[_tableView reloadData];
		_reloading = NO;
		[_refreshHeaderView egoRefreshScrollViewDataSourceDidFinishedLoading:_tableView];
	}
}

#pragma mark -
#pragma mark ServiceSourceDelegate
#pragma mark -

- (void)addService:(NSObject <ServiceProtocol>*)service
{
	[_services addObject:service];
#if INCLUDE_FEATURE(Extra_Animation)
	const NSUInteger idx = _services.count-1;
	[_tableView insertRowsAtIndexPaths: [NSArray arrayWithObject: [NSIndexPath indexPathForRow:idx inSection:0]]
					  withRowAnimation: UITableViewRowAnimationLeft];
#endif
}

- (void)addServices:(NSArray *)items
{
#if INCLUDE_FEATURE(Extra_Animation)
	NSUInteger count = _services.count;
	NSMutableArray *indexPaths = (self.isViewLoaded && [self.view superview]) ? [NSMutableArray arrayWithCapacity:items.count] : nil;
#endif
	[_services addObjectsFromArray:items];
#if INCLUDE_FEATURE(Extra_Animation)
	for(NSObject<ServiceProtocol> *service in items)
	{
		[indexPaths addObject:[NSIndexPath indexPathForRow:count inSection:0]];
		++count;
	}
#endif
#if INCLUDE_FEATURE(Extra_Animation)
	if(indexPaths)
		[_tableView insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationLeft];
	else
	{
		[_tableView reloadData];
	}
#endif
}

#pragma mark -
#pragma mark EventSourceDelegate
#pragma mark -

- (void)addEvent:(NSObject <EventProtocol>*)event
{
	NSMutableArray *arr = [_events valueForKey:event.service.sref];
	if(arr)
	{
		[arr addObject:event];
	}
	else
	{
		arr = [[NSMutableArray alloc] initWithObjects:event, nil];
		[_events setValue:arr forKey:event.service.sref];
	}
}

#pragma mark -
#pragma mark EPGCacheDelegate
#pragma mark -

- (void)finishedRefreshingCache
{
	progressHUD.taskInProgress = NO;
	[progressHUD hide:YES];

	_servicesToRefresh = -1;
	_reloading = NO;

	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ [self readEPG]; });
}

- (void)remainingServicesToRefresh:(NSNumber *)count
{
	if(_servicesToRefresh == -1)
		_servicesToRefresh = [count integerValue];
	progressHUD.progress = 1 - ([count integerValue] / _servicesToRefresh);
}

#pragma mark -
#pragma mark SwipeTableViewDelegate
#pragma mark -

- (void)tableView:(SwipeTableView *)tableView didSwipeRowAtIndexPath:(NSIndexPath *)indexPath
{
	// only detect left&right swipes
	const SwipeType lastSwipe = _tableView.lastSwipe & (swipeTypeLeft | swipeTypeRight);
	NSTimeInterval interval = 0;
	switch(lastSwipe)
	{
		case swipeTypeRight:
		{
			NSNumber *timeInterval = [[NSUserDefaults standardUserDefaults] objectForKey:kMultiEPGInterval];
			interval = -[timeInterval floatValue];
			break;
		}
		case swipeTypeLeft:
		{
			NSNumber *timeInterval = [[NSUserDefaults standardUserDefaults] objectForKey:kMultiEPGInterval];
			interval = [timeInterval floatValue];
			break;
		}
		default: break;
	}

	if(interval)
	{
		NSDate *until = [_curBegin dateByAddingTimeInterval:interval];
		self.curBegin = until;
	}
}

#pragma mark -
#pragma mark UITableView
#pragma mark -

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if(IS_IPAD())
	{
		return kMultiEPGCellHeightIpad;
	}
	else if(self.isViewLoaded && [self.view superview])
	{
		NSObject<ServiceProtocol> *service = [_services objectAtIndex:indexPath.row];
		if(service.picon)
			return kMultiEPGCellHeightPicon;
	}
	return kMultiEPGCellHeight;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	// do nothing if reloading
	if(_reloading)
	{
#if IS_DEBUG()
		[NSException raise:@"MultiEPGListUserInteractionWhileReloading" format:@"willSelectRowAtIndexPath was triggered for indexPath (section %d, row %d) while reloading", indexPath.section, indexPath.row];
#endif
		return;
	}

	const MultiEPGTableViewCell *cell = (MultiEPGTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
	const CGRect cellRect = [tableView rectForRowAtIndexPath:indexPath];
	const CGPoint lastTouch = _tableView.lastTouch;
	CGPoint locationInCell;
	locationInCell.x = lastTouch.x;
	locationInCell.y = lastTouch.y - cellRect.origin.y;
	NSObject<EventProtocol> *event = [cell eventAtPoint:locationInCell];
	if([multiEpgDelegate respondsToSelector:@selector(multiEPG:didSelectEvent:onService:)])
		[multiEpgDelegate multiEPG:self didSelectEvent:event onService:cell.service];

	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

/* cell for row */
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	MultiEPGTableViewCell *cell = [MultiEPGTableViewCell reusableTableViewCellInView:tableView withIdentifier:kMultiEPGCell_ID];

	NSObject<ServiceProtocol> *service = [_services objectAtIndex:indexPath.row];
	cell.service = service;
	cell.epgView.begin = _curBegin;
	cell.epgView.events = [_events valueForKey:service.sref];
	cell.epgView.secondsSinceBegin = _secondsSinceBegin;

	[[DreamoteConfiguration singleton] styleTableViewCell:cell inTableView:tableView asSlave:self.isSlave];
	return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [_services count];
}

@end
