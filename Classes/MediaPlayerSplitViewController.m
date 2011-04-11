//
//  MediaPlayerSplitViewController.m
//  dreaMote
//
//  Created by Moritz Venn on 10.01.11.
//  Copyright 2011 Moritz Venn. All rights reserved.
//

#import "MediaPlayerSplitViewController.h"

#import "PlayListController.h"
#import "MediaPlayerDetailsController.h"

@implementation MediaPlayerSplitViewController

- (id)init
{
    if((self = [super init]))
	{
		self.title = NSLocalizedString(@"MediaPlayer", @"Title of MediaPlayerSplitViewController");

		self.splitPosition = 512;
		UIImage *image = [UIImage imageNamed: @"mediaplayer.png"];
		self.tabBarItem.image = image;
    }
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

#pragma mark -
#pragma mark UIViewController methods
#pragma mark -

- (void)loadView
{
    [super loadView];

	// Instantiate view controllers
	PlayListController *playListController = [[PlayListController alloc] init];
	MediaPlayerDetailsController *detailsController = [[MediaPlayerDetailsController alloc] init];
	detailsController.playlist = playListController.playlist;

	// Setup navigation controllers and add to split view
	UIViewController *navController1, *navController2;
	navController1 = [[UINavigationController alloc] initWithRootViewController: playListController];
	navController2 = [[UINavigationController alloc] initWithRootViewController: detailsController];
	self.viewControllers = [NSArray arrayWithObjects: navController1, navController2, nil];
	[navController1 release];
	[navController2 release];

	// add buttons
	UIBarButtonItem *flipItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
																			  target:detailsController
																			  action:@selector(flipView:)];
	const UIBarButtonItem *flexItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
																					target:nil
																					action:nil];
	NSArray *items = [[NSArray alloc] initWithObjects:flexItem, detailsController.shuffleButton, nil];
	[playListController setToolbarItems:items animated:NO];
	[playListController.navigationController setToolbarHidden:NO animated:YES];
	playListController.navigationItem.leftBarButtonItem = flipItem;

	// details is delegate
	self.delegate = detailsController;

	// release allocated ressources
	[items release];
	[flexItem release];
	[flipItem release];
	[playListController release];
	[detailsController release];
}

@end
