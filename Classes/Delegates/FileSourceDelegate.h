//
//  FileSourceDelegate.h
//  dreaMote
//
//  Created by Moritz Venn on 05.01.11.
//  Copyright 2011 Moritz Venn. All rights reserved.
//

#import "FileProtocol.h"

#import "DataSourceDelegate.h"

/*!
 @brief FileSourceDelegate.

 Objects wanting to be called back by a File Source (e.g. MediaPlayer Playlist)
 need to implement this Protocol.
 */
@protocol FileSourceDelegate <DataSourceDelegate>

/*!
 @brief New object was created and should be added to list.
 
 @param anItem File to add.
 */
- (void)addFile: (NSObject<FileProtocol> *)anItem;

@end

