//
//  PlayListController.m
//  dreaMote
//
//  Created by Moritz Venn on 10.01.11.
//  Copyright 2011 Moritz Venn. All rights reserved.
//

#import "PlayListController.h"


@implementation PlayListController

@synthesize clearButton = _clearButton;
@synthesize playlist = _playlist;
@synthesize saveButton = _saveButton;
@synthesize loadButton = _loadButton;

- (id)init
{
	if((self = [super init]))
	{
		self.title = NSLocalizedString(@"Playlist", @"Title of PlayListController");
		_playlist = [[FileListView alloc] initWithFrame: [[UIScreen mainScreen] applicationFrame]];
		_playlist.isPlaylist = YES;

		if([self respondsToSelector:@selector(setContentSizeForViewInPopover:)])
			self.contentSizeForViewInPopover = CGSizeMake(430.0f, 800.0f);
	}
	return self;
}

- (void)dealloc
{
	[_clearButton release];
	[_saveButton release];
	[_loadButton release];
	[_playlist release];

	[super dealloc];
}

- (void)loadView
{
	self.view = _playlist;
	self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

/* (un)set editing */
- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
	[super setEditing: editing animated: animated];
	[_playlist setEditing: editing animated: animated];

	_clearButton.enabled = !editing;
	_saveButton.enabled = !editing;
	_loadButton.enabled = !editing;
}

@end
