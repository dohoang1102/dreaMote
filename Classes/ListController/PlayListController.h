//
//  PlayListController.h
//  dreaMote
//
//  Created by Moritz Venn on 10.01.11.
//  Copyright 2011 Moritz Venn. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "FileListView.h"

@interface PlayListController : UIViewController {
@protected
	FileListView *_playlist; /*!< @brief Playlist. */
	UIBarButtonItem *_clearButton; /*!< @brief Clear Playlist. */
	UIBarButtonItem *_saveButton; /*!< @brief Save Playlist. */
	UIBarButtonItem *_loadButton; /*!< @brief Load Playlist. */
}

/*!
 @brief Get "Clear" Button.
 */
@property (nonatomic, retain) UIBarButtonItem *clearButton;

/*!
 @brief Get "Save" Button.
 */
@property (nonatomic, retain) UIBarButtonItem *saveButton;

/*!
 @brief Get "Load" Button.
 */
@property (nonatomic, retain) UIBarButtonItem *loadButton;

/*!
 @brief Get/Set Playlist.
 */
@property (nonatomic, retain) FileListView *playlist;

@end
