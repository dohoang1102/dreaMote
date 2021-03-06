//
//  AutoTimerSplitViewController.m
//  dreaMote
//
//  Created by Moritz Venn on 06.11.11.
//  Copyright (c) 2011 Moritz Venn. All rights reserved.
//

#import "AutoTimerSplitViewController.h"

#import <ListController/AutoTimerListController.h>
#import <ViewController/AutoTimerViewController.h>

@interface AutoTimerSplitViewController()
@property (nonatomic, strong) AutoTimerListController *lc;
@end

@implementation AutoTimerSplitViewController

@synthesize lc;

- (void)dealloc
{
	if(lc.mgSplitViewController == self)
		lc.mgSplitViewController = nil;
}

#pragma mark - View lifecycle

- (void)loadView
{
	[super loadView];

	lc = [[AutoTimerListController alloc] init];
	AutoTimerViewController *vc = [AutoTimerViewController newAutoTimer];
	lc.isSplit = YES;
	lc.autotimerView = vc;
	lc.mgSplitViewController = self;

	// Setup navigation controllers and add to split view
	UIViewController *navController1, *navController2;
	navController1 = [[UINavigationController alloc] initWithRootViewController:lc];
	navController2 = [[UINavigationController alloc] initWithRootViewController:vc];
	self.viewControllers = [NSArray arrayWithObjects: navController1, navController2, nil];
}

- (void)viewDidUnload
{
	if(lc.mgSplitViewController == self)
		lc.mgSplitViewController = nil;
	lc = nil;
	[super viewDidUnload];
}

@end
