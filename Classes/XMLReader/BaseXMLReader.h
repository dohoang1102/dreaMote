//
//  BaseXMLReader.h
//  dreaMote
//
//  Created by Moritz Venn on 31.12.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#ifdef LAME_ASYNCHRONOUS_DOWNLOAD
#define DataDownloaderRunMode @"your_namespace.run_mode"
#import "CXMLPushDocument.h"
typedef CXMLPushDocument OurXMLDocument;
#else
#import "CXMLDocument.h"
typedef CXMLDocument OurXMLDocument;
#endif

#import "RemoteConnector.h"

/*!
 @brief Basic XML Reader Class.

 Download a website and read it in as XML.
 Stores contents in a CXMLDocument.
 */
@interface BaseXMLReader : NSObject
{
@private
	BOOL	finished; /*!< @brief Finished parsing? */
@protected
	id		_target; /*!< @brief Callback Target. */
	SEL		_addObject; /*!< @brief Callback Selector. */
	OurXMLDocument *_parser; /*!< @brief CXMLDocument. */
}

/*!
 @brief Standard initializer.
 
 @param target Callback target.
 @param action Callback selector.
 @return BaseXMLReader instance.
 */
- (id)initWithTarget:(id)target action:(SEL)action;

/*
 @brief Download and parse XML document.
 
 @param URL URL to download.
 @param error Will be pointed to NSError if one occurs.
 @return Parsed XML Document.
 */
- (CXMLDocument *)parseXMLFileAtURL: (NSURL *)URL parseError: (NSError **)error;



/*!
 @brief Finished parsing?
 */
@property (readonly) BOOL finished;

@end
