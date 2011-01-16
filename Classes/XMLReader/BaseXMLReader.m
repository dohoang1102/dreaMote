//
//  BaseXMLReader.m
//  dreaMote
//
//  Created by Moritz Venn on 31.12.08.
//  Copyright 2008-2011 Moritz Venn. All rights reserved.
//
#import "BaseXMLReader.h"

/*!
 @brief Private functions of BaseXMLReader.
 */
@interface BaseXMLReader()
/*!
 @brief Instruct XMLReader to send fake object to callback.
 */
- (void)sendErroneousObject;

/*!
 @brief Parse XML Document.
 */
- (void)parseFull;
@end

@implementation BaseXMLReader

/* initialize */
- (id)init
{
	if((self = [super init]))
	{
		_done = NO;
		_timeout = 7; // set default timeout
	}
	return self;
}

/* dealloc */
- (void)dealloc
{
	[_delegate release];
	[_parser release];

	[super dealloc];
}

/* download and parse xml document */
- (CXMLDocument *)parseXMLFileAtURL: (NSURL *)URL parseError: (NSError **)error
{
	_done = NO;
	NSError *localError = nil;
	if(error)
		*error = nil;

#ifdef LAME_ASYNCHRONOUS_DOWNLOAD
	_parser = [[CXMLPushDocument alloc] initWithError: &localError];

	// bail out if we encountered an error
	if(localError)
	{
		if(error)
			*error = localError;
		[self sendErroneousObject];
		// delegate wants to be informated about errors
		if(_delegate && [_delegate respondsToSelector:@selector(dataSourceDelegate:errorParsingDocument:error:)])
			[_delegate dataSourceDelegate:self errorParsingDocument:nil error:localError];
		return nil;
	}

	NSURLRequest *request = [NSURLRequest requestWithURL: URL cachePolicy: NSURLRequestReloadIgnoringCacheData timeoutInterval: 50];
	NSURLConnection *connection = [[NSURLConnection alloc]
									initWithRequest:request
									delegate:self
									startImmediately:NO];

	if(!connection)
	{
		[self sendErroneousObject];
		return nil;
	}

	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	[connection scheduleInRunLoop:[NSRunLoop currentRunLoop]
							forMode: DataDownloaderRunMode];
	[connection start];

	while (!_done) // a BOOL flagged in the delegate methods
	{
		[[NSRunLoop currentRunLoop] runMode: DataDownloaderRunMode
								beforeDate:[NSDate dateWithTimeIntervalSinceNow:15.0]];
	}
	[connection release];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

	if(!_parser.success)
	{
		[self sendErroneousObject];
		// delegate wants to be informated about errors
		if(_delegate && [_delegate respondsToSelector:@selector(dataSourceDelegate:errorParsingDocument:error:)])
			[_delegate dataSourceDelegate:self errorParsingDocument:nil error:localError];
		return nil;

	}
#else //!LAME_ASYNCHRONOUS_DOWNLOAD
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	// Create URL Object and download it
	NSURLResponse *response;
	NSURLRequest *request = [NSURLRequest requestWithURL: URL
											cachePolicy: NSURLRequestReloadIgnoringCacheData timeoutInterval: _timeout];
	NSData *data = [NSURLConnection sendSynchronousRequest: request
											returningResponse: &response error: &localError];

	if(localError == nil)
		_parser = [[CXMLDocument alloc] initWithData: data options: 0 error: &localError];
	
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	_done = YES;

	// bail out if we encountered an error
	if(localError)
	{
		if(error)
			*error = localError;
		[self sendErroneousObject];
		// delegate wants to be informated about errors
		if(_delegate && [_delegate respondsToSelector:@selector(dataSourceDelegate:errorParsingDocument:error:)])
			[_delegate dataSourceDelegate:self errorParsingDocument:nil error:localError];
		return nil;
	}
#endif

	[self parseFull];
	// delegate wants to be informated about parsing end
	if(_delegate && !localError && [_delegate respondsToSelector:@selector(dataSourceDelegate:finishedParsingDocument:)])
		[_delegate dataSourceDelegate:self finishedParsingDocument:nil];
	return _parser;
}

#ifdef LAME_ASYNCHRONOUS_DOWNLOAD
/* received data */
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	[_parser parseChunk: data];
}

/* connection failed */
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	// delegate wants to be informated about errors
	if(_delegate && [_delegate respondsToSelector:@selector(dataSourceDelegate:errorParsingDocument:error:)])
		[_delegate dataSourceDelegate:self errorParsingDocument:nil error:error];

	_done = YES;

	[_parser abortParsing];
}

/* _done */
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	_done = YES;

	[_parser doneParsing];
}

#endif //LAME_ASYNCHRONOUS_DOWNLOAD

/* send fake object back to callback */
- (void)sendErroneousObject
{
	// NOTE: descending classes should implement this
}

/* parse complete xml document */
- (void)parseFull
{
	// NOTE: descending classes should implement this
}

@end
