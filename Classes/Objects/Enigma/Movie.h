//
//  Movie.h
//  dreaMote
//
//  Created by Moritz Venn on 01.01.09.
//  Copyright 2008-2011 Moritz Venn. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CXMLNode.h"

#import <Objects/MovieProtocol.h>

/*!
 @brief Movie in Enigma.
 */
@interface EnigmaMovie : NSObject <MovieProtocol>
{
@private
	NSNumber *_length; /*!< @brief Length. */
	NSNumber *_size; /*!< @brief Size. */
	NSUInteger _idx; /*!< @brief Index in result. Used for sorting. */

	CXMLNode *_node; /*!< @brief CXMLNode describing this Movie. */
}

/*!
 @brief Standard initializer.
 
 @param node Pointer to CXMLNode describing this Movie.
 @return EnigmaMovie instance.
 */
- (id)initWithNode: (CXMLNode *)node;

@property (nonatomic, assign) NSUInteger idx;

@end
