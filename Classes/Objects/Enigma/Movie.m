//
//  Movie.m
//  dreaMote
//
//  Created by Moritz Venn on 31.12.08.
//  Copyright 2008-2011 Moritz Venn. All rights reserved.
//

#import "Movie.h"

#import "CXMLElement.h"

@implementation EnigmaMovie

@synthesize idx = _idx, timeString;

- (NSArray *)tags
{
	return nil;
}

- (void)setTags: (NSArray *)new
{
#if IS_DEBUG()
	[NSException raise:@"ExcUnsupportedFunction" format:@""];
#endif
}

- (NSString *)filename
{
	return nil;
}

- (void)setFilename:(NSString *)new
{
#if IS_DEBUG()
	[NSException raise:@"ExcUnsupportedFunction" format:@""];
#endif
}

- (NSNumber *)size
{
	return _size;
}

- (void)setSize: (NSNumber *)new
{
#if IS_DEBUG()
	[NSException raise:@"ExcUnsupportedFunction" format:@""];
#endif
}

- (NSNumber *)length
{
	return _length;
}

- (void)setLength: (NSNumber *)new
{
#if IS_DEBUG()
	[NSException raise:@"ExcUnsupportedFunction" format:@""];
#endif
}

- (NSDate *)time
{
	return nil;
}

- (void)setTime: (NSDate *)new
{
#if IS_DEBUG()
	[NSException raise:@"ExcUnsupportedFunction" format:@""];
#endif
}

- (NSString *)sname
{
	return nil;
}

- (void)setSname: (NSString *)new
{
#if IS_DEBUG()
	[NSException raise:@"ExcUnsupportedFunction" format:@""];
#endif
}

- (NSString *)sref
{
	const NSArray *resultNodes = [_node nodesForXPath:@"reference" error:nil];
	for(CXMLElement *resultElement in resultNodes)
	{
		return [resultElement stringValue];
	}
	return nil;
}

- (void)setSref: (NSString *)new
{
#if IS_DEBUG()
	[NSException raise:@"ExcUnsupportedFunction" format:@""];
#endif
}

- (NSString *)edescription
{
	return NSLocalizedString(@"N/A", @"");
}

- (void)setEdescription: (NSString *)new
{
#if IS_DEBUG()
	[NSException raise:@"ExcUnsupportedFunction" format:@""];
#endif
}

- (NSString *)sdescription
{
	return NSLocalizedString(@"N/A", @"");
}

- (void)setSdescription: (NSString *)new
{
#if IS_DEBUG()
	[NSException raise:@"ExcUnsupportedFunction" format:@""];
#endif
}

- (NSString *)title
{
	const NSArray *resultNodes = [_node nodesForXPath:@"name" error:nil];
	for(CXMLElement *resultElement in resultNodes)
	{
		// We have to un-escape some characters here...
		return [[resultElement stringValue] stringByReplacingOccurrencesOfString: @"&amp;" withString: @"&"];
	}
	return nil;
}

- (void)setTitle: (NSString *)new
{
#if IS_DEBUG()
	[NSException raise:@"ExcUnsupportedFunction" format:@""];
#endif
}

- (id)initWithNode: (CXMLNode *)node
{
	if((self = [super init]))
	{
		_node = node;
		_size = [NSNumber numberWithInt: -1];
		_length = [NSNumber numberWithInt: -1];
	}
	return self;
}


- (BOOL)isValid
{
	return _node && self.sref != nil;
}

- (NSComparisonResult)timeCompare:(NSObject<MovieProtocol> *)otherMovie
{
	if(_idx < ((EnigmaMovie *)otherMovie).idx)
		return NSOrderedAscending;
	else if(_idx == ((EnigmaMovie *)otherMovie).idx)
		return [self.title caseInsensitiveCompare:otherMovie.title];
	return NSOrderedDescending;
}

- (NSComparisonResult)titleCompare:(NSObject<MovieProtocol> *)otherMovie
{
	NSComparisonResult res = [self.title caseInsensitiveCompare:otherMovie.title];
	if(res == NSOrderedSame)
	{
		if(_idx < ((EnigmaMovie *)otherMovie).idx)
			res = NSOrderedDescending;
		else if(_idx == ((EnigmaMovie *)otherMovie).idx)
			res = NSOrderedSame;
		else
			res = NSOrderedAscending;
	}
	return res;
}

- (void)setTimeFromString: (NSString *)newTime
{
#if IS_DEBUG()
	[NSException raise:@"ExcUnsupportedFunction" format:@""];
#endif
}

- (void)setTagsFromString: (NSString *)newTags
{
#if IS_DEBUG()
	[NSException raise:@"ExcUnsupportedFunction" format:@""];
#endif
}

@end
