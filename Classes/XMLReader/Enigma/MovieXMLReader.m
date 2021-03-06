//
//  MovieXMLReader.m
//  dreaMote
//
//  Created by Moritz Venn on 31.12.08.
//  Copyright 2008-2011 Moritz Venn. All rights reserved.
//

#import "MovieXMLReader.h"

#import "Constants.h"

#import "../../Objects/Enigma/Movie.h"
#import "../../Objects/Generic/Movie.h"

@implementation EnigmaMovieXMLReader

/* initialize */
- (id)initWithDelegate:(NSObject<MovieSourceDelegate> *)delegate
{
	if((self = [super init]))
	{
		_delegate = delegate;
		_timeout = kTimeout * 3; // a lot higher timeout to allow to spin up hdd
	}
	return self;
}

/* send fake object */
- (void)sendErroneousObject
{
	NSObject<MovieProtocol> *fakeObject = [[GenericMovie alloc] init];
	fakeObject.title = NSLocalizedString(@"Error retrieving Data", @"");
	[_delegate performSelectorOnMainThread: @selector(addMovie:)
								withObject: fakeObject
							 waitUntilDone: NO];
}

/*
 Example:
 <?xml version="1.0" encoding="UTF-8"?>
 <movies>
  <service><reference>1:0:1:6dcf:44d:1:c00000:93d2d1:0:0:/hdd/movie/WDR Köln - Rockpalast - Haldern Pop 2006 - 26_08_06.ts</reference><name>Rockpalast - Haldern Pop 2006</name><orbital_position>192</orbital_position></service>
 </movies>
*/
- (void)parseFull
{
	const NSArray *resultNodes = [document nodesForXPath:@"/movies/service" error:nil];
	NSUInteger idx = 0;

	for(CXMLElement *resultElement in resultNodes)
	{
		// A service in the xml represents a movie, so create an instance of it.
		EnigmaMovie *newMovie = [[EnigmaMovie alloc] initWithNode: (CXMLNode *)resultElement];
		newMovie.idx = ++idx;

		[_delegate performSelectorOnMainThread: @selector(addMovie:)
									withObject: newMovie
								 waitUntilDone: NO];
	}
}

@end
