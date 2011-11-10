//
//  TimerListController.m
//  dreaMote
//
//  Created by Moritz Venn on 09.03.08.
//  Copyright 2008-2011 Moritz Venn. All rights reserved.
//

#import "TimerListController.h"

#import "TimerViewController.h"

#import "Constants.h"
#import "NSDateFormatter+FuzzyFormatting.h"
#import "RemoteConnectorObject.h"
#import "UIDevice+SystemVersion.h"
#import "UITableViewCell+EasyInit.h"

#import <TableViewCell/TimerTableViewCell.h>

#import <Objects/Generic/Timer.h>
#import <Objects/Generic/Result.h>

#import "MKStoreManager.h"

@interface TimerListController()
#if INCLUDE_FEATURE(Ads)
- (void)createAdBannerView;
- (void)fixupAdView:(UIInterfaceOrientation)toInterfaceOrientation;
@property (nonatomic, strong) id adBannerView;
@property (nonatomic) BOOL adBannerViewIsVisible;
#endif
- (void)cleanupTimers:(id)sender;
- (void)cancelConnection:(NSNotification *)notif;
@end

/*!
 @brief Mapping Section<->State
 We use this array to map incoming timer states to sections and
 sections back to timer states.
 */
static const int stateMap[kTimerStateMax] = {kTimerStateRunning, kTimerStatePrepared, kTimerStateWaiting, kTimerStateFinished};

@implementation TimerListController

@synthesize dateFormatter, isSplit;
@synthesize timerViewController = _timerViewController;
@synthesize willReappear = _willReappear;
#if INCLUDE_FEATURE(Ads)
@synthesize adBannerView = _adBannerView;
@synthesize adBannerViewIsVisible = _adBannerViewIsVisible;
#endif

/* initialize */
- (id)init
{
	if((self = [super init]))
	{
		_timers = [[NSMutableArray alloc] init];
		self.title = NSLocalizedString(@"Timers", @"Title of TimerListController");
		dateFormatter = [[NSDateFormatter alloc] init];
		[dateFormatter setTimeStyle:NSDateFormatterShortStyle];
		_timerViewController = nil;
		_willReappear = NO;
	}
	return self;
}

/* dealloc */
- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if(_timerViewController.delegate == self)
		_timerViewController.delegate = nil;
#if INCLUDE_FEATURE(Ads)
	[_adBannerView setDelegate:nil];
#endif
}

/* memory warning */
- (void)didReceiveMemoryWarning
{
	if(!IS_IPAD())
	{
		if(_timerViewController.delegate == self)
			_timerViewController.delegate = nil;
		_timerViewController = nil;
	}
	
    [super didReceiveMemoryWarning];
}

- (void)cleanupTimers:(id)sender
{
	// TODO: generate list of timers to clean up if non-native, but for now we don't support that anyway
	Result *result = [[RemoteConnectorObject sharedRemoteConnector] cleanupTimers:nil];
	if(!result.result)
	{
		// Alert user
		const UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error cleaning up", @"Title of alert when timer cleanup failed")
															  message:result.resulttext
															 delegate:nil
													cancelButtonTitle:@"OK"
													otherButtonTitles:nil];
		[alert show];
	}

	// reload data
	[self emptyData];
	[_refreshHeaderView setTableLoadingWithinScrollView:_tableView];

	// Run this in our "temporary" queue
	[RemoteConnectorObject queueInvocationWithTarget:self selector:@selector(fetchData)];
}

/* layout */
- (void)loadView
{
	[super loadView];
	_tableView.delegate = self;
	_tableView.dataSource = self;
	_tableView.rowHeight = 62;
	_tableView.allowsSelectionDuringEditing = YES;

	_cleanupButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cleanup", @"Timer cleanup button") style:UIBarButtonItemStylePlain target:self action:@selector(cleanupTimers:)];

	self.navigationItem.rightBarButtonItem = self.editButtonItem;
#if INCLUDE_FEATURE(Ads)
	if(IS_IPHONE() && ![MKStoreManager isFeaturePurchased:kAdFreePurchase])
		[self createAdBannerView];
#endif

	// listen to connection changes
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cancelConnection:) name:kReconnectNotification object:nil];

	[self theme];
}

- (void)viewDidUnload
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
#if INCLUDE_FEATURE(Ads)
	[_adBannerView setDelegate:nil];
	_adBannerView = nil;
#endif
	_cleanupButton = nil;

	[super viewDidUnload];
}

- (void)setWillReappear:(BOOL)new
{
	// allow to skip refresh only if there is any data
	if(_dist[0] > 0) _willReappear = new;
}

/* (un)set editing */
- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
	[super setEditing: editing animated: animated];
	[_tableView setEditing: editing animated: animated];

	if(animated && !_reloading)
	{
		if(editing)
		{
			[_tableView insertRowsAtIndexPaths: [NSArray arrayWithObject: [NSIndexPath indexPathForRow:0 inSection:0]]
							withRowAnimation: UITableViewRowAnimationTop];
		}
		else
		{
			[_tableView deleteRowsAtIndexPaths: [NSArray arrayWithObject: [NSIndexPath indexPathForRow:0 inSection:0]]
							withRowAnimation: UITableViewRowAnimationTop];
		}
	}
	else
		[_tableView reloadData];
}

/* about to appear */
- (void)viewWillAppear:(BOOL)animated
{
	if([[RemoteConnectorObject sharedRemoteConnector] hasFeature:kFeaturesTimerCleanup])
		self.navigationItem.leftBarButtonItem = _cleanupButton;
	else
		self.navigationItem.leftBarButtonItem = nil;

	if(!_willReappear && !_reloading)
	{
		_reloading = YES;
		[self emptyData];
		[_refreshHeaderView setTableLoadingWithinScrollView:_tableView];

		// Run this in our "temporary" queue
		[RemoteConnectorObject queueInvocationWithTarget:self selector:@selector(fetchData)];
	}
	else
	{
		[_tableView deselectRowAtIndexPath:[_tableView indexPathForSelectedRow] animated:YES];
	}

	_willReappear = NO;

	[super viewWillAppear: animated];
#if INCLUDE_FEATURE(Ads)
	[self fixupAdView:self.interfaceOrientation];
#endif
}

/* about to disappear */
- (void)viewWillDisappear:(BOOL)animated
{
	// XXX: I'd actually do this in background (e.g. viewDidDisappear) but this won't reset the editButtonItem
	if(self.editing)
		[self setEditing:NO animated: YES];
}

/* did disappear */
- (void)viewDidDisappear:(BOOL)animated
{
	// Clear remaining caches if not reappearing
	if(!_willReappear)
	{
		if(!IS_IPAD())
		{
			if(_timerViewController.delegate == self)
				_timerViewController.delegate = nil;
			_timerViewController = nil;

			[self emptyData];
		}
	}

	// Reset reference date of date formatter
	[dateFormatter resetReferenceDate];
}

/* fetch timer list */
- (void)fetchData
{
	_reloading = YES;
	_xmlReader = [[RemoteConnectorObject sharedRemoteConnector] fetchTimers:self];
}

/* remove content data */
- (void)emptyData
{
	NSUInteger i = 0;

	// Clean timer list
	for(i = 0; i < kTimerStateMax; i++)
		_dist[i] = 0;
	[_timers removeAllObjects];

#if INCLUDE_FEATURE(Extra_Animation)
	NSIndexSet *idxSet = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, kTimerStateMax + 1)];
	[_tableView reloadSections:idxSet withRowAnimation:UITableViewRowAnimationRight];
#else
	[_tableView reloadData];
#endif

	_xmlReader = nil;
}

- (void)cancelConnection:(NSNotification *)notif
{
	[self emptyData];
	_reloading = NO;
}

/* rotate with device */
- (BOOL)shouldAutorotateToInterfaceOrientation: (UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

/* about to rotate */
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
#if INCLUDE_FEATURE(Ads)
	[self fixupAdView:toInterfaceOrientation];
#endif
}

#pragma mark -
#pragma mark -
#pragma mark -

- (void)dataSourceDelegateFinishedParsingDocument:(BaseXMLReader *)dataSource
{
	_reloading = NO;
	[_refreshHeaderView egoRefreshScrollViewDataSourceDidFinishedLoading:_tableView];
	[_tableView reloadData];
}

#pragma mark -
#pragma mark TimerSourceDelegate
#pragma mark -

/* add timer to list */
- (void)addTimer: (NSObject<TimerProtocol> *)newTimer
{
	NSUInteger state = stateMap[newTimer.state];
	NSUInteger index = _dist[state];

	[_timers insertObject: newTimer atIndex: index];

	for(; state < kTimerStateMax; state++){
		_dist[state]++;
	}
#if INCLUDE_FEATURE(Extra_Animation) && defined(ENABLE_LAGGY_ANIMATIONS)
	state = newTimer.state;
	if(state > 0)
		index -= _dist[state - 1];

	[_tableView insertRowsAtIndexPaths: [NSArray arrayWithObject: [NSIndexPath indexPathForRow: index inSection: state + 1]]
					  withRowAnimation: UITableViewRowAnimationTop];
#endif
}

#pragma mark	-
#pragma mark		Table View
#pragma mark	-

/* to determine which UITableViewCell to be used on a given row. */
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSInteger section = indexPath.section;
	UITableViewCell *cell = nil;

	// First section, "New Timer"
	if(section == 0)
	{
		cell = [BaseTableViewCell reusableTableViewCellInView:tableView withIdentifier:kBaseCell_ID];

		cell.textLabel.text = NSLocalizedString(@"New Timer", @"");
		cell.textLabel.font = [UIFont systemFontOfSize:kTextViewFontSize]; // FIXME: Looks a little weird though

		return cell;
	}

	// Timer state is section - 1, so make this a little more readable
	--section;

	// Acquire cell
	cell = [TimerTableViewCell reusableTableViewCellInView:tableView withIdentifier:kTimerCell_ID];

	// Assign item
	NSInteger offset = 0;
	if(section > 0)
		offset = _dist[section-1];
	((TimerTableViewCell *)cell).formatter = dateFormatter;
	((TimerTableViewCell *)cell).timer = [_timers objectAtIndex: offset + indexPath.row];

	[[DreamoteConfiguration singleton] styleTableViewCell:cell inTableView:tableView];
	return cell;
}

/* row selected */
- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if(self.editing)
	{
		if(indexPath.section == 0)
			[self tableView:tableView commitEditingStyle:UITableViewCellEditingStyleInsert forRowAtIndexPath:indexPath];
		return nil;
	}

	// do nothing if reloading
	if(_reloading)
	{
#if IS_DEBUG()
		[NSException raise:@"TimerListUserInteractionWhileReloading" format:@"willSelectRowAtIndexPath was triggered for indexPath (section %d, row %d) while reloading", indexPath.section, indexPath.row];
#endif
		return nil;
	}

	NSInteger index = indexPath.row;
	const NSInteger section = indexPath.section - 1;
	if(section > 0)
		index += _dist[section - 1];

	NSObject<TimerProtocol> *timer = [_timers objectAtIndex: index];
	if(!timer.valid)
	{
		[tableView deselectRowAtIndexPath: indexPath animated: YES];
		return nil;
	}

	NSObject<TimerProtocol> *ourCopy = [timer copy];

	@synchronized(self)
	{
		if(_timerViewController == nil)
			_timerViewController = [[TimerViewController alloc] init];
	}

	if(!IS_IPAD())
		_willReappear = YES;

	_timerViewController.delegate = self;
	_timerViewController.timer = timer;
	_timerViewController.oldTimer = ourCopy;

	// when in split view go back to timer view, else push it on the stack
	if(!isSplit)
	{
		// XXX: wtf?
		if([self.navigationController.viewControllers containsObject:_timerViewController])
		{
#if IS_DEBUG()
			NSMutableString* result = [[NSMutableString alloc] init];
			for(NSObject* obj in self.navigationController.viewControllers)
				[result appendString:[obj description]];
			[NSException raise:@"TimerViewTwiceInNavigationStack" format:@"_timerViewController was twice in navigation stack: %@", result];
#endif
			[self.navigationController popToViewController:self animated:NO]; // return to self, so we can push the timerview without any problems
		}
		[self.navigationController pushViewController:_timerViewController animated:YES];
	}
	else
		[_timerViewController.navigationController popToRootViewControllerAnimated: YES];

	// NOTE: set this here so the edit button won't get screwed
	_timerViewController.creatingNewTimer = NO;
	return indexPath;
}

/* number of sections */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
	return kTimerStateMax + 1;
}

/* header height */
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	if(section == 0)
		return 0;
	return [[DreamoteConfiguration singleton] tableView:tableView heightForHeaderInSection:section];
}

/* section header */
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
	return [[DreamoteConfiguration singleton] tableView:tableView viewForHeaderInSection:section];
}

/* section title */
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if(section == 0)
		return nil;
	NSUInteger state = stateMap[--section];

	switch(state)
	{
		case kTimerStateWaiting:
			return NSLocalizedString(@"Waiting", @"Timer type");
		case kTimerStatePrepared:
			return NSLocalizedString(@"Prepared", @"Timer type");
		case kTimerStateRunning:
			return NSLocalizedString(@"Running", @"Timer type");
		case kTimerStateFinished:
			return NSLocalizedString(@"Finished", @"Timer type");
		default:
			return nil;
	}
}

/* rows in section */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	// First section only has an item when editing
	if(section == 0)
	{
		return (self.editing) ? 1 : 0;
	}
	--section;

	if(section > 0)
		return _dist[section] - _dist[section-1];
	return _dist[0];
}

/* editing style */
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if(indexPath.section == 0)
		return UITableViewCellEditingStyleInsert;
	return UITableViewCellEditingStyleDelete;
}

/* edit action */
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	// do nothing if reloading
	if(_reloading)
	{
#if IS_DEBUG()
		[NSException raise:@"TimerListUserInteractionWhileReloading" format:@"commitEditingStyle was triggered for indexPath (section %d, row %d) while reloading", indexPath.section, indexPath.row];
#endif
		return;
	}

	// If row is deleted, remove it from the list.
	if (editingStyle == UITableViewCellEditingStyleDelete)
	{
		NSUInteger index = indexPath.row;
		NSUInteger section = indexPath.section - 1;
		if(section > 0)
			index += _dist[section - 1];

		if(index > _timers.count)
		{
#if IS_DEBUG()
			[NSException raise:@"TimerListInvalidIndex" format:@"commitEditingStyle was triggered for invalid index %d (dists %d,%d,%d,%d, section %d / row %d, real count %d)", index, _dist[0], _dist[1], _dist[2], _dist[3], indexPath.section, indexPath.row, _timers.count];
#else
			// Alert user
			const UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", @"")
																  message:[NSString stringWithFormat:NSLocalizedString(@"Received invalid row (%d, %d) which was mapped to index %d of %d. Please reload this table and try again.", @"User interaction with TimerList failed because index could not be retrieved."), indexPath.section, indexPath.row, index, _timers.count]
																 delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
			[alert show];
			[alert release];
#endif
			return;
		}

		NSObject<TimerProtocol> *timer = [_timers objectAtIndex: index];
		if(!timer.valid)
			return;

		// Try to delete timer
		Result *result = [[RemoteConnectorObject sharedRemoteConnector] delTimer: timer];
		if(result.result)
		{
			// If we have a constant timer Id don't refresh all data
			if([[RemoteConnectorObject sharedRemoteConnector] hasFeature: kFeaturesConstantTimerId])
			{
				for(; section < kTimerStateMax; section++){
					_dist[section]--;
				}

				[_timers removeObjectAtIndex: index];

				[tableView deleteRowsAtIndexPaths: [NSArray arrayWithObject: indexPath]
								 withRowAnimation: UITableViewRowAnimationFade];
			}
			// Else reload data
			else
			{
				// NOTE: this WILL reset our scroll position..
				[self emptyData];

				// Run this in our "temporary" queue
				[RemoteConnectorObject queueInvocationWithTarget:self selector:@selector(fetchData)];
			}
		}
		// Timer could not be deleted
		else
		{
			// Alert user
			const UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Delete failed", @"") message:result.resulttext
														   delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
			[alert show];
		}
	}
	// Add new Timer
	else if(editingStyle == UITableViewCellEditingStyleInsert)
	{
		@synchronized(self)
		{
			if(_timerViewController == nil)
				_timerViewController = [[TimerViewController alloc] init];
		}

		if(!IS_IPAD())
			_willReappear = YES;

		NSObject<TimerProtocol> *newTimer = [GenericTimer timer];
		_timerViewController.delegate = self;
		_timerViewController.timer = newTimer;
		_timerViewController.oldTimer = nil;

		// when in split view go back to timer view, else push it on the stack
		if(!isSplit)
		{
			// XXX: wtf?
			if([self.navigationController.viewControllers containsObject:_timerViewController])
			{
#if IS_DEBUG()
				NSMutableString* result = [[NSMutableString alloc] init];
				for(NSObject* obj in self.navigationController.viewControllers)
					[result appendString:[obj description]];
				[NSException raise:@"TimerViewTwiceInNavigationStack" format:@"_timerViewController was twice in navigation stack: %@", result];
#endif
				[self.navigationController popToViewController:self animated:NO]; // return to self, so we can push the timerview without any problems
			}
			[self.navigationController pushViewController:_timerViewController animated:YES];
		}
		else
		{
			[_timerViewController.navigationController popToRootViewControllerAnimated: YES];
			[self setEditing:NO animated:YES];
		}

		// NOTE: set this here so the edit button won't get screwed
		_timerViewController.creatingNewTimer = YES;
	}
}

#pragma mark -
#pragma mark TimerViewControllerDelegate
#pragma mark -

- (void)timerViewController:(TimerViewController *)tvc timerWasAdded:(NSObject<TimerProtocol> *)timer
{
	// TODO: check if we can implement optimized reload
	[self emptyData];
	[RemoteConnectorObject queueInvocationWithTarget:self selector:@selector(fetchData)];
}

- (void)timerViewController:(TimerViewController *)tvc timerWasEdited:(NSObject<TimerProtocol> *)timer :(NSObject<TimerProtocol> *)oldTimer;
{
	// TODO: check if we can implement optimized reload
	[self emptyData];
	[RemoteConnectorObject queueInvocationWithTarget:self selector:@selector(fetchData)];
}

- (void)timerViewController:(TimerViewController *)tvc editingWasCanceled:(NSObject<TimerProtocol> *)timer;
{
	// do we need this for anything?
}

#pragma mark ADBannerViewDelegate
#if INCLUDE_FEATURE(Ads)

//#define __BOTTOM_AD__

- (CGFloat)getBannerHeight:(UIInterfaceOrientation)orientation
{
	if(UIInterfaceOrientationIsLandscape(orientation))
		return IS_IPAD() ? 66 : 32;
	else
		return IS_IPAD() ? 66 : 50;
}

- (CGFloat)getBannerHeight
{
	return [self getBannerHeight:self.interfaceOrientation];
}

- (void)createAdBannerView
{
	Class classAdBannerView = NSClassFromString(@"ADBannerView");
	if(classAdBannerView != nil)
	{
		self.adBannerView = [[classAdBannerView alloc] initWithFrame:CGRectZero];
		[_adBannerView setRequiredContentSizeIdentifiers:[NSSet setWithObjects:
														  ADBannerContentSizeIdentifierPortrait,
														  ADBannerContentSizeIdentifierLandscape,
														  nil]];
		if(UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
		{
			[_adBannerView setCurrentContentSizeIdentifier:ADBannerContentSizeIdentifierLandscape];
		}
		else
		{
			[_adBannerView setCurrentContentSizeIdentifier:ADBannerContentSizeIdentifierPortrait];
		}
#ifdef __BOTTOM_AD__
		// Banner at Bottom
		CGRect cgRect =[[UIScreen mainScreen] bounds];
		CGSize cgSize = cgRect.size;
		[_adBannerView setFrame:CGRectOffset([_adBannerView frame], 0, cgSize.height + [self getBannerHeight])];
#else
		// Banner at the Top
		[_adBannerView setFrame:CGRectOffset([_adBannerView frame], 0, -[self getBannerHeight])];
#endif
		[_adBannerView setDelegate:self];

		[self.view addSubview:_adBannerView];
	}
}

- (void)fixupAdView:(UIInterfaceOrientation)toInterfaceOrientation
{
	if (_adBannerView != nil)
	{
		if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation))
		{
			[_adBannerView setCurrentContentSizeIdentifier:ADBannerContentSizeIdentifierLandscape];
		}
		else
		{
			[_adBannerView setCurrentContentSizeIdentifier:ADBannerContentSizeIdentifierPortrait];
		}
		[UIView beginAnimations:@"fixupViews" context:nil];
		if(_adBannerViewIsVisible)
		{
			CGRect adBannerViewFrame = [_adBannerView frame];
			CGRect contentViewFrame = _tableView.frame;
			CGFloat newBannerHeight = [self getBannerHeight:toInterfaceOrientation];
			
			adBannerViewFrame.origin.x = 0;
#ifdef __BOTTOM_AD__
			adBannerViewFrame.origin.y = self.view.frame.size.height - newBannerHeight;
#else
			adBannerViewFrame.origin.y = 0;
#endif
			[_adBannerView setFrame:adBannerViewFrame];
			[self.view bringSubviewToFront:_adBannerView];

#ifdef __BOTTOM_AD__
			contentViewFrame.origin.y = 0;
#else
			contentViewFrame.origin.y = newBannerHeight;
#endif
			contentViewFrame.size.height = self.view.frame.size.height - newBannerHeight;
			_tableView.frame = contentViewFrame;
		}
		else
		{
			CGRect adBannerViewFrame = [_adBannerView frame];
			adBannerViewFrame.origin.x = 0;
#ifdef __BOTTOM_AD__
			adBannerViewFrame.origin.y = self.view.frame.size.height + [self getBannerHeight:toInterfaceOrientation];
#else
			adBannerViewFrame.origin.y = -[self getBannerHeight:toInterfaceOrientation];
#endif
			[_adBannerView setFrame:adBannerViewFrame];

			CGRect contentViewFrame = _tableView.frame;
			contentViewFrame.origin.y = 0;
			contentViewFrame.size.height = self.view.frame.size.height;
			_tableView.frame = contentViewFrame;
		}
		[UIView commitAnimations];
	}
}

- (void)bannerViewDidLoadAd:(ADBannerView *)banner
{
	if(!_adBannerViewIsVisible)
	{
		_adBannerViewIsVisible = YES;
		[self fixupAdView:self.interfaceOrientation];
	}
}

- (void)bannerView:(ADBannerView *)banner didFailToReceiveAdWithError:(NSError *)error
{
	if(_adBannerViewIsVisible)
	{
		_adBannerViewIsVisible = NO;
		[self fixupAdView:self.interfaceOrientation];
	}
}
#endif

@end
