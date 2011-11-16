//
//  ReloadableListController.m
//  dreaMote
//
//  Created by Moritz Venn on 06.01.11.
//  Copyright 2011 Moritz Venn. All rights reserved.
//

#import "ReloadableListController.h"

#import "DreamoteConfiguration.h"
#import "RemoteConnectorObject.h" // [+RemoteConnectorObject queueInvocationWithTarget: selector:]

#import "UIDevice+SystemVersion.h"

#import "ServiceListController.h" // isSlave

#import <View/GradientView.h>

#import <XMLReader/BaseXMLReader.h>
#import <XMLReader/SaxXmlReader.h>

@implementation ReloadableListController

@synthesize tableView = _tableView;

/* initialize */
- (id)init
{
	if((self = [super init]))
	{
		_reloading = NO;
	}
	return self;
}

/* dealloc */
- (void)dealloc
{
	[self stopObservingThemeChanges];
	_refreshHeaderView.delegate = nil;
	_refreshHeaderView = nil;
	_tableView.delegate = nil;
	_tableView.dataSource = nil;
	_tableView = nil;
}

/* layout */
- (void)loadView
{
	// create table view
	_tableView = [[SwipeTableView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame] style:UITableViewStylePlain];
	_tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;

	// setup our content view so that it auto-rotates along with the UViewController
	_tableView.autoresizesSubviews = YES;
	_tableView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);

#if INCLUDE_FEATURE(Ads)
	UIView *contentView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
	contentView.autoresizesSubviews = YES;
	contentView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
	self.view = contentView;
	CGRect visibleFrame = CGRectMake(0, 0, contentView.frame.size.width, contentView.frame.size.height);
	_tableView.frame = visibleFrame;
	[contentView addSubview:_tableView];
#else
	self.view = _tableView;
#endif

	// add header view
	_refreshHeaderView = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.view.bounds.size.height, self.view.bounds.size.width, self.view.bounds.size.height)];
	_refreshHeaderView.delegate = self;
	[_tableView addSubview:_refreshHeaderView];
}

- (void)loadGroupedTableView
{
	// create table view
	_tableView = [[SwipeTableView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame] style:UITableViewStyleGrouped];
	_tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;

	// setup our content view so that it auto-rotates along with the UViewController
	_tableView.autoresizesSubviews = YES;
	_tableView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);

	// on the ipad we need a dummy background view to be able to render the background
	if(IS_IPAD())
	{
		[_tableView setBackgroundView:[[UIView alloc] init]];
	}

#if INCLUDE_FEATURE(Ads)
	UIView *contentView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
	contentView.autoresizesSubviews = YES;
	contentView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
	self.view = contentView;
	CGRect visibleFrame = CGRectMake(0, 0, contentView.frame.size.width, contentView.frame.size.height);
	_tableView.frame = visibleFrame;
	[contentView addSubview:_tableView];
#else
	self.view = _tableView;
#endif

	// add header view
	// NOTE: looks ugly on ipad, so only enable this on iphone for now
	if(!IS_IPAD())
	{
		_refreshHeaderView = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.view.bounds.size.height, self.view.bounds.size.width, self.view.bounds.size.height)];
		_refreshHeaderView.delegate = self;
		[_tableView addSubview:_refreshHeaderView];
	}
}

- (void)theme
{
	DreamoteConfiguration *singleton = [DreamoteConfiguration singleton];
#if INCLUDE_FEATURE(Ads)
	UIColor *backgroundColor = nil;
	if(_tableView.style == UITableViewStyleGrouped || ([self respondsToSelector:@selector(isSlave)] && [(id)self isSlave]))
		backgroundColor = singleton.groupedTableViewBackgroundColor;
	else
		backgroundColor = singleton.backgroundColor;
	self.view.backgroundColor = backgroundColor;
#endif

	const BOOL isIos5 = [UIDevice newerThanIos:5.0f];
	switch(singleton.currentTheme)
	{
		default:
			_refreshHeaderView.statusLabel.textColor = [UIColor colorWithRed:87.0f/255.0f green:108.0f/255.0f blue:137.0f/255.0f alpha:1.0f];
			_refreshHeaderView.statusLabel.shadowColor = [UIColor colorWithWhite:0.9f alpha:1.0f];
			_refreshHeaderView.arrorImage.contents = (id)[UIImage imageNamed:@"blueArrow.png"].CGImage;
			if(isIos5)
				_refreshHeaderView.activityView.color = nil;
			_refreshHeaderView.activityView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
			break;
		case THEME_NIGHT:
			_refreshHeaderView.statusLabel.textColor = singleton.textColor;
			_refreshHeaderView.arrorImage.contents = (id)[UIImage imageNamed:@"grayArrow.png"].CGImage;
			_refreshHeaderView.statusLabel.shadowColor = nil;
			_refreshHeaderView.activityView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
			if(isIos5)
				_refreshHeaderView.activityView.color = singleton.textColor;
			break;
		case THEME_DARK:
			_refreshHeaderView.statusLabel.textColor = singleton.textColor;
			_refreshHeaderView.statusLabel.shadowColor = nil;
			_refreshHeaderView.arrorImage.contents = (id)[UIImage imageNamed:@"whiteArrow.png"].CGImage;
			_refreshHeaderView.activityView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhite;
			if(isIos5)
				_refreshHeaderView.activityView.color = singleton.textColor;
			break;
	}
	[super theme];
}

- (void)viewDidLoad
{
	[self startObservingThemeChanges];
	[super viewDidLoad];
}

- (void)viewDidUnload
{
	[self stopObservingThemeChanges];
	_refreshHeaderView.delegate = nil;
	_refreshHeaderView = nil;
	_tableView.delegate = nil;
	_tableView.dataSource = nil;
	_tableView = nil;
	
	[super viewDidUnload];
}

/* view did appear */
- (void)viewDidAppear:(BOOL)animated
{
	if(_reloading)
		[_refreshHeaderView setTableLoadingWithinScrollView:_tableView];
}

#pragma mark -
#pragma mark ReloadableView methods
#pragma mark -

/* start download of content data */
- (void)fetchData
{
	// subclasses should override this
}

/* remove content data */
- (void)emptyData
{
	// subclasses should override this
}

#pragma mark -
#pragma mark DataSourceDelegate
#pragma mark -

- (void)dataSourceDelegate:(BaseXMLReader *)dataSource errorParsingDocument:(NSError *)error
{
	if(dataSource == _xmlReader && [dataSource isKindOfClass:[SaxXmlReader class]])
		_xmlReader = nil;

	_reloading = NO;
	[_refreshHeaderView egoRefreshScrollViewDataSourceDidFinishedLoading:_tableView];
	[_tableView reloadData];

	// no error -> probably handled by child class
	if(!error)
		return;

	// Alert user
	const UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Failed to retrieve data", @"Title of Alert when retrieving remote data failed.")
														  message:[error localizedDescription]
														 delegate:nil
												cancelButtonTitle:@"OK"
												otherButtonTitles:nil];
	[alert show];
}

- (void)dataSourceDelegateFinishedParsingDocument:(BaseXMLReader *)dataSource
{
	if(dataSource == _xmlReader && [dataSource isKindOfClass:[SaxXmlReader class]])
		_xmlReader = nil;

	_reloading = NO;
	[_refreshHeaderView egoRefreshScrollViewDataSourceDidFinishedLoading:_tableView];
#if INCLUDE_FEATURE(Extra_Animation)
	[_tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
#else
	[_tableView reloadData];
#endif
}

#pragma mark -
#pragma mark UIScrollViewDelegate Methods
#pragma mark -

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
	[_refreshHeaderView egoRefreshScrollViewDidScroll:scrollView];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
	[_refreshHeaderView egoRefreshScrollViewDidEndDragging:scrollView];
}

#pragma mark -
#pragma mark EGORefreshTableHeaderDelegate Methods
#pragma mark -

- (void)egoRefreshTableHeaderDidTriggerRefresh:(EGORefreshTableHeaderView*)view
{
	if(_reloading) return;
	[self emptyData];

	// Run this in our "temporary" queue
	[RemoteConnectorObject queueInvocationWithTarget:self selector:@selector(fetchData)];
}

- (BOOL)egoRefreshTableHeaderDataSourceIsLoading:(EGORefreshTableHeaderView*)view
{
	return _reloading;
}

@end
