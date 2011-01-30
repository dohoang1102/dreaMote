//
//  EventListController.m
//  dreaMote
//
//  Created by Moritz Venn on 09.03.08.
//  Copyright 2008-2011 Moritz Venn. All rights reserved.
//

#import "EventListController.h"

#import "EventTableViewCell.h"
#import "EventViewController.h"

#import "Constants.h"
#import "RemoteConnectorObject.h"
#import "NSDateFormatter+FuzzyFormatting.h"

#import "Objects/ServiceProtocol.h"
#import "Objects/EventProtocol.h"

#if IS_FULL()
	#import "EPGCache.h"
#endif

@interface EventListController()
/*!
 @brief initiate zap 
 @param sender ui element
 */
- (void)zapAction:(id)sender;
@end

@implementation EventListController

@synthesize dateFormatter = _dateFormatter;

/* initialize */
- (id)init
{
	if((self = [super init]))
	{
		self.title = NSLocalizedString(@"Events", @"Default Title of EventListController");
		_dateFormatter = [[NSDateFormatter alloc] init];
		[_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
		_eventViewController = nil;
		_service = nil;
		_events = [[NSMutableArray array] retain];
	}
	return self;
}

/* new list for given service */
+ (EventListController*)forService: (NSObject<ServiceProtocol> *)ourService
{
	EventListController *eventListController = [[EventListController alloc] init];
	eventListController.service = ourService;

	return [eventListController autorelease];
}

/* getter for service property */
- (NSObject<ServiceProtocol> *)service
{
	return _service;
}

/* setter for service property */
- (void)setService: (NSObject<ServiceProtocol> *)newService
{
	// No change, return immediately
	if(_service == newService) return;

	// Free old service, assign new
	[_service release];
	_service = [newService retain];

	// Set title
	self.title = newService.sname;

	// Clean event list
	[self emptyData];
	[_refreshHeaderView setTableLoadingWithinScrollView:_tableView];

	// Spawn a thread to fetch the event data so that the UI is not blocked while the
	// application parses the XML file.
	[NSThread detachNewThreadSelector:@selector(fetchData) toTarget:self withObject:nil];
}

/* dealloc */
- (void)dealloc
{
	[_events release];
	[_service release];
	[_dateFormatter release];
	[_eventViewController release];
	[_eventXMLDoc release];

	[super dealloc];
}

/* memory warning */
- (void)didReceiveMemoryWarning
{
	[_eventViewController release];
	_eventViewController = nil;
	
    [super didReceiveMemoryWarning];
}

/* layout */
- (void)loadView
{
	[super loadView];
	_tableView.delegate = self;
	_tableView.dataSource = self;
	_tableView.rowHeight = kEventCellHeight;
	_tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
	_tableView.sectionHeaderHeight = 0;

	// Create zap button
	UIBarButtonItem *zapButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Zap", @"") style:UIBarButtonItemStylePlain target:self action:@selector(zapAction:)];
	self.navigationItem.rightBarButtonItem = zapButton;
	[zapButton release];
}

/* zap */
- (void)zapAction:(id)sender
{
	[[RemoteConnectorObject sharedRemoteConnector] zapTo: _service];
}

/* start download of event list */
- (void)fetchData
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[_eventXMLDoc release];
#if IS_FULL()
	[[EPGCache sharedInstance] startTransaction:_service];
#endif
	_reloading = YES;
	_eventXMLDoc = [[[RemoteConnectorObject sharedRemoteConnector] fetchEPG: self service: _service] retain];
	[pool release];
}

/* remove content data */
- (void)emptyData
{
	// Clean event list
	[_events removeAllObjects];
	NSIndexSet *idxSet = [NSIndexSet indexSetWithIndex: 0];
	[_tableView reloadSections:idxSet withRowAnimation:UITableViewRowAnimationRight];
	[_eventXMLDoc release];
	_eventXMLDoc = nil;
}

#pragma mark -
#pragma mark EventSourceDelegate methods
#pragma mark -

/* add event to list */
- (void)addEvent: (NSObject<EventProtocol> *)event
{
	const NSInteger idx = [_events count];
	[_events addObject: event];
	[_tableView insertRowsAtIndexPaths: [NSArray arrayWithObject: [NSIndexPath indexPathForRow:idx inSection:0]]
					  withRowAnimation: UITableViewRowAnimationLeft];
#if IS_FULL()
	[NSThread detachNewThreadSelector:@selector(addEventThreaded:) toTarget:[EPGCache sharedInstance] withObject:event];
#endif
}

#pragma mark	-
#pragma mark		Table View
#pragma mark	-

/* cell for given row */
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	EventTableViewCell *cell = (EventTableViewCell*)[tableView dequeueReusableCellWithIdentifier:kEventCell_ID];
	if(cell == nil)
		cell = [[[EventTableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:kEventCell_ID] autorelease];

	cell.formatter = _dateFormatter;
	cell.showService = NO;
	cell.event = (NSObject<EventProtocol> *)[_events objectAtIndex: indexPath.row];

	return cell;
}

/* select row */
- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSObject<EventProtocol> *event = (NSObject<EventProtocol> *)[_events objectAtIndex: indexPath.row];

	if(_eventViewController == nil)
		_eventViewController = [[EventViewController alloc] init];

	_eventViewController.event = event;
	_eventViewController.service = _service;

	[self.navigationController pushViewController: _eventViewController animated: YES];

	return indexPath;
}

/* number of section */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
	// TODO: seperate by day??
	return 1;
}

/* number of items */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	return [_events count];
}

/* rotate with device */
- (BOOL)shouldAutorotateToInterfaceOrientation: (UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

/* about to display */
- (void)viewWillAppear:(BOOL)animated
{
	// this UIViewController is about to re-appear, make sure we remove the current selection in our table view
	NSIndexPath *tableSelection = [_tableView indexPathForSelectedRow];
	[_tableView deselectRowAtIndexPath:tableSelection animated:YES];
}

/* disappeared */
- (void)viewDidDisappear:(BOOL)animated
{
	[_dateFormatter resetReferenceDate];
#if IS_FULL()
	// end transaction here because there can only be a single active transaction at a time
	// if we didn't stop now the possibility of a corrupted cache is higher, though this way
	// we still could end up with a corrupted cache… the better way might be to add a
	// "transaction context" on the epgcache end and manage the cache from the event parsers
	// instead from the view.
	[[EPGCache sharedInstance] stopTransaction];
#endif
}

@end
