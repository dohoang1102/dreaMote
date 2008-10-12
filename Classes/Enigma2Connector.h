//
//  Enigma2Connector.h
//  Untitled
//
//  Created by Moritz Venn on 08.03.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "RemoteConnector.h"

@interface Enigma2Connector : NSObject <RemoteConnector> {
@private
	NSURL *baseAddress;
}

@property (nonatomic, retain) NSURL *baseAddress;

@end
