//
//  OtherListController.m
//  dreaMote
//
//  Created by Moritz Venn on 09.03.08.
//  Copyright 2008-2011 Moritz Venn. All rights reserved.
//

#import "OtherListController.h"

#import "Constants.h"
#import "RemoteConnectorObject.h"
#import "UITableViewCell+EasyInit.h"

#import "MainTableViewCell.h"

#import "MGSplitViewController.h"

#import "AboutViewController.h"
#import "AboutDreamoteViewController.h"
#if IS_FULL()
	#import "AutoTimerListController.h"
	#import "AutoTimerSplitViewController.h"
#endif
#import "BouquetListController.h"
#import "ConfigViewController.h"
#import "ConfigListController.h"
#import "ControlViewController.h"
#import "CurrentViewController.h"
#import "EPGRefreshViewController.h"
#import "EventSearchListController.h"
#import "MessageViewController.h"
#import "MovieListController.h"
#import "LocationListController.h"
#import "ServiceListController.h"
#import "SignalViewController.h"
#import "SleepTimerViewController.h"
#import "TimerListController.h"
#import "MediaPlayerController.h"
#import "PackageManagerListController.h"

@interface OtherListController()
- (void)handleReconnect: (NSNotification *)note;
/*!
 @brief display about dialog
 @param sender ui element
 */
- (void)aboutDreamoteAction: (id)sender;
@end

@implementation OtherListController

@synthesize tableView, mgSplitViewController;

- (id)init
{
	if((self = [super init]))
	{
		self.title = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
		self.tabBarItem.title = NSLocalizedString(@"More", @"Tab Title of OtherListController");
		_configListController = nil;
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self stopObservingThemeChanges];
}

- (void)didReceiveMemoryWarning
{
	_aboutDreamoteViewController = nil;

	if([RemoteConnectorObject isConnected])
		[[RemoteConnectorObject sharedRemoteConnector] freeCaches];

    [super didReceiveMemoryWarning];
}

- (void)viewDidLoad
{
	const BOOL isIpad = IS_IPAD();
	menuList = [[NSMutableArray alloc] init];

	// create our view controllers - we will encase each title and view controller pair in a NSDictionary
	// and add it to a mutable array.  If you want to add more pages, simply call "addObject" on "menuList"
	// with an additional NSDictionary.  Note we use NSLocalizedString to load a localized version of its title.
	_aboutDictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:
						NSLocalizedString(@"About Receiver", @"Title of About Receiver in Other List"), @"title",
						NSLocalizedString(@"Information on software and tuners", @"Explaination of About Receiver in Other List"), @"explainText",
						[AboutViewController class], @"viewControllerClass",
						nil];

#if IS_FULL()
	Class viewControllerClass = (isIpad) ? [AutoTimerSplitViewController class] : [AutoTimerListController class];
	_autotimerDictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:
						 NSLocalizedString(@"AutoTimer-Plugin", @"Title of AutoTimer in Other List"), @"title",
						 NSLocalizedString(@"Add and edit AutoTimers", @"Explaination of AutoTimer in Other List"), @"explainText",
						 viewControllerClass, @"viewControllerClass",
						 nil];
#endif

	[menuList addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
						 NSLocalizedString(@"Settings", @"Title of Settings in Other List"), @"title",
						 NSLocalizedString(@"Change configuration and edit known hosts", @"Explaination of Settings in Other List"), @"explainText",
						 [[ConfigListController alloc] init], @"viewController",
						 nil]];

	_epgrefreshDictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:
							  NSLocalizedString(@"EPGRefresh-Plugin", @"Title of EPGRefresh in Other List"), @"title",
							  NSLocalizedString(@"Settings of EPGRefresh-Plugin", @"Explaination of EPGRefresh in Other List"), @"explainText",
							  [EPGRefreshViewController class], @"viewControllerClass",
							  nil];

	_eventSearchDictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:
							NSLocalizedString(@"Search EPG", @"Title of Event Search in Other List"), @"title",
							NSLocalizedString(@"Search EPG for event titles", @"Explaination of Event Search in Other List"), @"explainText",
							[EventSearchListController class], @"viewControllerClass",
							nil];

	_signalDictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:
							   NSLocalizedString(@"Signal Finder", @"Title of Signal Finder in Other List"), @"title",
							   NSLocalizedString(@"Displays current SNR/AGC", @"Explaination of Signal Finder in Other List"), @"explainText",
							   [SignalViewController class], @"viewControllerClass",
							   nil];

	if(!isIpad)
	{
		_locationsDictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:
							NSLocalizedString(@"Recording Locations", @"Title of Location List in Other List"), @"title",
							NSLocalizedString(@"Show recording locations", @"Explaination of Location List in Other List"), @"explainText",
							[LocationListController class], @"viewControllerClass",
							nil];

		_recordDictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:
							NSLocalizedString(@"Movies", @"Title of Movie List in Other List"), @"title",
							NSLocalizedString(@"Recorded Movies", @"Explaination of Movie List in Other List"), @"explainText",
							[MovieListController class], @"viewControllerClass",
							nil];

		_mediaPlayerDictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:
								  NSLocalizedString(@"Media Player", @"Title of Media Player in Other List"), @"title",
								  NSLocalizedString(@"Control the remote media player", @"Explaination of Media Player in Other List"), @"explainText",
								  [MediaPlayerController class], @"viewControllerClass",
								  nil];
	}

	[menuList addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
						NSLocalizedString(@"Control", @"Title of Control View in Other List"), @"title",
						NSLocalizedString(@"Control Powerstate and Volume", @"Explaination of Control View in Other List"), @"explainText",
						[ControlViewController class], @"viewControllerClass",
						nil]];

	[menuList addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
						 NSLocalizedString(@"Messages", @"Title of Message View in Other List"), @"title",
						 NSLocalizedString(@"Send short Messages", @"Explaination of Message View in Other List"), @"explainText",
						 [MessageViewController class], @"viewControllerClass",
						 nil]];

	_sleeptimerDictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:
							  NSLocalizedString(@"Sleep Timer", @"Title of Sleep Timer in Other List"), @"title",
							  NSLocalizedString(@"Edit and (de)activate Sleep Timer", @"Explaination of Sleep Timer in Other List"), @"explainText",
							  [SleepTimerViewController class], @"viewControllerClass",
							  nil];

	_packageManagerDictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:
							  NSLocalizedString(@"Package Manager", @"Title of Package Manager in Other List"), @"title",
							  NSLocalizedString(@"Install/Update/Remove packages", @"Explaination of Package Manager in Other List"), @"explainText",
							  [PackageManagerListController class], @"viewControllerClass",
							  nil];

	// Add the "About" button to the navigation bar
	UIBarButtonItem *buttonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"About", @"About Button Text") style:UIBarButtonItemStyleBordered target:self action:@selector(aboutDreamoteAction:)];
	if(isIpad)
		self.navigationItem.rightBarButtonItem = buttonItem; // left button somehow gets shrinked pretty badly, so use the right one instead
	else
		self.navigationItem.leftBarButtonItem = buttonItem;

	tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
	if(isIpad)
		tableView.rowHeight = kUIRowHeight;

	// setup our list view to autoresizing in case we decide to support autorotation along the other UViewControllers
	tableView.autoresizesSubviews = YES;
	tableView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);

	// listen to connection changes
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleReconnect:) name:kReconnectNotification object:nil];

	[self startObservingThemeChanges];
	[self theme];
}

- (void)theme
{
	[super theme];

	// TODO: find a way to fix this!
	NSIndexPath *idxPath = [tableView indexPathForSelectedRow];
	if(idxPath)
	{
		[tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:idxPath] withRowAnimation:UITableViewRowAnimationNone];
		[tableView selectRowAtIndexPath:idxPath animated:NO scrollPosition:UITableViewScrollPositionNone];
	}
}

- (void)viewDidUnload
{
	[self stopObservingThemeChanges];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	self.tableView = nil;
	self.navigationItem.leftBarButtonItem = self.navigationItem.rightBarButtonItem = nil;

	_aboutDreamoteViewController = nil;
#if IS_FULL()
	_autotimerDictionary = nil;
#endif
	_configListController = nil;
	_epgrefreshDictionary = nil;
	_eventSearchDictionary = nil;
	_mediaPlayerDictionary = nil;
	_locationsDictionary = nil;
	_recordDictionary = nil;
	_signalDictionary = nil;
	_sleeptimerDictionary = nil;
	_packageManagerDictionary = nil;
	[menuList removeAllObjects];

	[super viewDidUnload];
}

- (void)aboutDreamoteAction: (id)sender
{
	if(_aboutDreamoteViewController == nil)
		_aboutDreamoteViewController = [[AboutDreamoteViewController alloc] init];
	[self.navigationController presentModalViewController: _aboutDreamoteViewController animated:YES];
}

- (void)handleReconnect: (NSNotification *)note
{
	if(_aboutDictionary) // check an arbitrary item for nil
		[self viewWillAppear:YES];
}

#pragma mark UIViewController delegates

- (void)viewWillAppear:(BOOL)animated
{
	const BOOL isIpad = IS_IPAD();
	// this UIViewController is about to re-appear, make sure we remove the current selection in our table view
	NSIndexPath *tableSelection = [tableView indexPathForSelectedRow];
	if(mgSplitViewController)
	{
		NSMutableDictionary *selectedDictionary = [menuList objectAtIndex:tableSelection.row];
		UIViewController *masterViewController = [selectedDictionary objectForKey:@"masterViewController"];
		if(masterViewController)
		{
			MGSplitViewController *targetViewController = [selectedDictionary objectForKey:@"viewController"];
			UINavigationController *navController = (UINavigationController *)targetViewController.masterViewController;
			[navController pushViewController:masterViewController animated:NO];
			[selectedDictionary removeObjectForKey:@"masterViewController"];

			if([masterViewController respondsToSelector:@selector(setMgSplitViewController:)])
			{
				NSLog(@"Note: Giving master its previous split view back, this is some crazy sh**!");
				[(AutoTimerListController *)masterViewController setMgSplitViewController:targetViewController];
			}
		}
	}
	else
	{
		[tableView deselectRowAtIndexPath:tableSelection animated:YES];
	}

	const id connId = [[NSUserDefaults standardUserDefaults] objectForKey: kActiveConnection];
	if(![RemoteConnectorObject isConnected])
		if(![RemoteConnectorObject connectTo: [connId integerValue]])
			return;

	BOOL reload = NO;
	/* The menu reorganization might be buggy, this should be redone
	   as it was a bad hack to begin with */
	// Add/Remove Record
	if(!isIpad)
	{
		if([[RemoteConnectorObject sharedRemoteConnector] hasFeature: kFeaturesRecordInfo])
		{
			if([[RemoteConnectorObject sharedRemoteConnector] hasFeature: kFeaturesRecordingLocations])
			{
				if(![menuList containsObject: _locationsDictionary])
				{
					[menuList removeObject:_recordDictionary];
					[menuList insertObject:_locationsDictionary atIndex: 2];
					reload = YES;
				}
			}
			else
			{
				if(![menuList containsObject: _recordDictionary])
				{
					[menuList removeObject:_locationsDictionary];
					[menuList insertObject:_recordDictionary atIndex: 2];
					reload = YES;
				}
			}
		}
		else
		{
			if([menuList containsObject: _recordDictionary]
			   || [menuList containsObject: _locationsDictionary])
			{
				[menuList removeObject: _recordDictionary];
				[menuList removeObject: _locationsDictionary];
				reload = YES;
			}
		}
		
		// Add/Remove Media Player
		if([[RemoteConnectorObject sharedRemoteConnector] hasFeature: kFeaturesMediaPlayer])
		{
			if(![menuList containsObject: _mediaPlayerDictionary])
			{
				[menuList insertObject: _mediaPlayerDictionary atIndex: 2];
				reload = YES;
			}
		}
		else
		{
			if([menuList containsObject: _mediaPlayerDictionary])
			{
				[menuList removeObject: _mediaPlayerDictionary];
				reload = YES;
			}
		}
	}

	// Add/Remove Signal Finder
	if([[RemoteConnectorObject sharedRemoteConnector] hasFeature: kFeaturesSatFinder])
	{
		if(![menuList containsObject: _signalDictionary])
		{
			[menuList insertObject: _signalDictionary atIndex: (isIpad) ? 3 : 4];
			reload = YES;
		}
	}
	else
	{
		if([menuList containsObject: _signalDictionary])
		{
			[menuList removeObject: _signalDictionary];
			reload = YES;
		}
	}

	// Add/Remove Package Manager
	if([[RemoteConnectorObject sharedRemoteConnector] hasFeature: kFeaturesPackageManagement])
	{
		if(![menuList containsObject: _packageManagerDictionary])
		{
			[menuList insertObject: _packageManagerDictionary atIndex: (isIpad) ? 4 : 5];
			reload = YES;
		}
	}
	else
	{
		if([menuList containsObject: _packageManagerDictionary])
		{
			[menuList removeObject: _packageManagerDictionary];
			reload = YES;
		}
	}

	// Add/Remove Sleep Timer
	if([[RemoteConnectorObject sharedRemoteConnector] hasFeature: kFeaturesSleepTimer])
	{
		if(![menuList containsObject: _sleeptimerDictionary])
		{
			[menuList insertObject: _sleeptimerDictionary atIndex: (isIpad) ? 4 : 5];
			reload = YES;
		}
	}
	else
	{
		if([menuList containsObject: _sleeptimerDictionary])
		{
			[menuList removeObject: _sleeptimerDictionary];
			reload = YES;
		}
	}

	// Add/Remove Event Search
	/*!
	 @note Full version does emulated epg search in cache, so only check for native
	 search ability in lite version.
	 */
#if IS_FULL()
	if(YES)
#else
	if([[RemoteConnectorObject sharedRemoteConnector] hasFeature: kFeaturesEPGSearch])
#endif
	{
		if(![menuList containsObject: _eventSearchDictionary])
		{
			[menuList insertObject: _eventSearchDictionary atIndex: 2];
			reload = YES;
		}
	}
	else
	{
		if([menuList containsObject: _eventSearchDictionary])
		{
			[menuList removeObject: _eventSearchDictionary];
			reload = YES;
		}
	}

	// Add/Remove About Receiver
	if([[RemoteConnectorObject sharedRemoteConnector] hasFeature: kFeaturesAbout])
	{
		if(![menuList containsObject: _aboutDictionary])
		{
			[menuList insertObject: _aboutDictionary atIndex: 0];
			reload = YES;
		}
	}
	else
	{
		if([menuList containsObject: _aboutDictionary])
		{
			[menuList removeObject: _aboutDictionary];
			reload = YES;
		}
	}

#if IS_FULL()
	if([[RemoteConnectorObject sharedRemoteConnector] hasFeature:kFeaturesAutoTimer])
	{
		if(![menuList containsObject:_autotimerDictionary])
		{
			[menuList addObject:_autotimerDictionary]; // add to EOL
			reload = YES;
		}
	}
	else
	{
		if([menuList containsObject:_autotimerDictionary])
		{
			[menuList removeObject:_autotimerDictionary];
			reload = YES;
		}
	}
#endif

	if([[RemoteConnectorObject sharedRemoteConnector] hasFeature:kFeaturesEPGRefresh])
	{
		if(![menuList containsObject:_epgrefreshDictionary])
		{
			[menuList addObject:_epgrefreshDictionary]; // add to EOL
			reload = YES;
		}
	}
	else
	{
		if([menuList containsObject:_epgrefreshDictionary])
		{
			[menuList removeObject:_epgrefreshDictionary];
			reload = YES;
		}
	}

	if(reload)
		[tableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated
{
	[RemoteConnectorObject cancelPendingOperations];
	[super viewDidAppear:animated];
}

#pragma mark UITableView delegates

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [menuList count];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSMutableDictionary *selectedDictionary = [menuList objectAtIndex:indexPath.row];
	UIViewController *targetViewController = [selectedDictionary objectForKey:@"viewController"];
	if(targetViewController == nil)
	{
		Class targetViewControllerClass = [selectedDictionary objectForKey:@"viewControllerClass"];
		targetViewController = [[targetViewControllerClass alloc] init];
		[selectedDictionary setObject:targetViewController forKey:@"viewController"];
	}

	if(mgSplitViewController)
	{
		if([targetViewController isKindOfClass:[MGSplitViewController class]])
		{
			UIViewController *masterViewController = ((MGSplitViewController *)targetViewController).masterViewController;
			UIViewController *detailViewController = ((MGSplitViewController *)targetViewController).detailViewController;

			UIViewController *pushViewController = masterViewController;
			if([masterViewController isKindOfClass:[UINavigationController class]])
			{
				NSLog(@"WARNING: Stealing a view controller from a navigation stack does is dangerous, think of a better way!");
				pushViewController = ((UINavigationController *)masterViewController).visibleViewController;
				[selectedDictionary setObject:pushViewController forKey:@"masterViewController"];
			}
			if([pushViewController respondsToSelector:@selector(setMgSplitViewController:)])
			{
				NSLog(@"Note: Transferring split view controller to subview - this could get messy!");
				[(AutoTimerListController *)pushViewController setMgSplitViewController:mgSplitViewController];
			}
			[self.navigationController pushViewController:pushViewController animated:YES];

			if(detailViewController != mgSplitViewController.detailViewController)
				[detailViewController.view removeFromSuperview];
			UINavigationController *navController = nil;
			if([detailViewController isKindOfClass:[UINavigationController class]])
				navController = (UINavigationController *)detailViewController;
			else
			{
				if([detailViewController respondsToSelector:@selector(setIsSlave:)])
					[(id)detailViewController setIsSlave:YES];
				navController = [[UINavigationController alloc] initWithRootViewController:detailViewController];
			}
			[[DreamoteConfiguration singleton] styleNavigationController:navController];
			mgSplitViewController.detailViewController = navController;
		}
		else
		{
			if([targetViewController respondsToSelector:@selector(setIsSlave:)])
				[(id)targetViewController setIsSlave:YES];
			UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:targetViewController];
			[[DreamoteConfiguration singleton] styleNavigationController:navController];
			mgSplitViewController.detailViewController = navController;
		}
	}
	else
		[self.navigationController pushViewController:targetViewController animated:YES];
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	MainTableViewCell *cell = [MainTableViewCell reusableTableViewCellInView:tv withIdentifier:kMainCell_ID];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	cell.dataDictionary = [menuList objectAtIndex:indexPath.row];

	return [[DreamoteConfiguration singleton] styleTableViewCell:cell inTableView:tv];
}

/* rotate with device */
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

#pragma mark OtherViewProtocol

- (void)forceConfigDialog
{
	// TODO: select settings item?
	if([self.navigationController.visibleViewController isKindOfClass:[ConfigViewController class]])
	{
		((ConfigViewController *)self.navigationController.visibleViewController).mustSave = YES;
	}
	else
	{
		ConfigViewController *targetViewController = [ConfigViewController newConnection];
		targetViewController.mustSave = YES;
		[self.navigationController pushViewController:targetViewController animated:YES];
	}
}

@end
