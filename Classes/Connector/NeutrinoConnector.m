//
//  NeutrinoConnector.m
//  dreaMote
//
//  Created by Moritz Venn on 15.10.08.
//  Copyright 2008-2011 Moritz Venn. All rights reserved.
//

#import "NeutrinoConnector.h"

#import <Constants.h>

#import <Delegates/AppDelegate.h>

#import <Objects/Generic/Service.h>
#import <Objects/Generic/Volume.h>
#import <Objects/Generic/Timer.h>

#import <SynchronousRequestReader.h>
#import <Delegates/MovieSourceDelegate.h>
#import <Delegates/ServiceSourceDelegate.h>
#import <Delegates/SignalSourceDelegate.h>
#import <Delegates/TimerSourceDelegate.h>
#import <Delegates/VolumeSourceDelegate.h>

#import <XMLReader/Neutrino/EventXMLReader.h>
#import <XMLReader/Neutrino/ServiceXMLReader.h>

#import <libxml/parser.h>
#import <libxml/tree.h>
#import <libxml/xpath.h>

#import <ViewController/NeutrinoRCEmulatorController.h>

#import <Categories/NSString+URLEncode.h>

enum neutrinoMessageTypes {
	kNeutrinoMessageTypeNormal = 0,
	kNeutrinoMessageTypeConfirmed = 1,
	kNeutrinoMessageTypeMax = 2,
};

@implementation NeutrinoConnector

- (const BOOL const)hasFeature: (enum connectorFeatures)feature
{
	return
		(feature == kFeaturesBouquets) ||
		(feature == kFeaturesCurrent) ||
		(feature == kFeaturesConstantTimerId) ||
		(feature == kFeaturesMessageType) ||
		(feature == kFeaturesTimerRepeated) ||
		(feature == kFeaturesComplicatedRepeated) ||
		(feature == kFeaturesStreaming) ||
		(feature == kFeaturesScreenshot);
}

- (const NSUInteger const)getMaxVolume
{
	return 100;
}

- (id)initWithAddress: (NSString *)address andUsername: (NSString *)inUsername andPassword: (NSString *)inPassword andPort: (NSInteger)inPort useSSL: (BOOL)ssl
{
	if((self = [super init]))
	{
		// Protect from unexpected input and assume a full URL if address starts with http
		if([address rangeOfString: @"http"].location == 0)
		{
			_baseAddress = [[NSURL alloc] initWithString:address];
		}
		else
		{
			NSString *remoteAddress = nil;
			const NSString *scheme = ssl ? @"https://" : @"http://";
			remoteAddress = [NSString stringWithFormat: @"%@%@", scheme, address];
			if(inPort > 0)
				remoteAddress = [remoteAddress stringByAppendingFormat: @":%d", inPort];

			_baseAddress = [[NSURL alloc] initWithString:remoteAddress];
		}
	}
	return self;
}


- (void)freeCaches
{
	// NOTE: We don't use any caches
}

+ (NSObject <RemoteConnector>*)newWithConnection:(const NSDictionary *)connection
{
	NSString *address = [connection objectForKey: kRemoteHost];
	NSString *username = [[connection objectForKey: kUsername] urlencode];
	NSString *password = [[connection objectForKey: kPassword] urlencode];
	const NSInteger port = [[connection objectForKey: kPort] integerValue];
	const BOOL ssl = [[connection objectForKey: kSSL] boolValue];

	return [[NeutrinoConnector alloc] initWithAddress:address andUsername:username andPassword:password andPort:port useSSL:ssl];
}

+ (NSArray *)knownDefaultConnections
{
	NSNumber *connector = [NSNumber numberWithInteger:kNeutrinoConnector];
	return [NSArray arrayWithObjects:
				[NSDictionary dictionaryWithObjectsAndKeys:
					@"dbox", kRemoteHost,
					@"root", kUsername,
					@"dbox2", kPassword,
					@"NO", kSSL,
					connector, kConnector,
					nil],
				[NSDictionary dictionaryWithObjectsAndKeys:
					@"coolstream", kRemoteHost,
					@"root", kUsername,
					@"coolstream", kPassword,
					@"NO", kSSL,
					connector, kConnector,
					nil],
			nil];
}

+ (NSArray *)matchNetServices:(NSArray *)netServices
{
	// XXX: implement this?
	return nil;
}

- (UIViewController *)newRCEmulator
{
	return [[NeutrinoRCEmulatorController alloc] init];
}

- (BOOL)isReachable:(NSError **)error
{
	// Generate URI
	NSURL *myURI = [NSURL URLWithString:@"/control/info"  relativeToURL:_baseAddress];

	NSHTTPURLResponse *response;
	[SynchronousRequestReader sendSynchronousRequest:myURI
								   returningResponse:&response
											   error:error];

	if([response statusCode] == 200)
	{
		return YES;
	}
	else
	{
		// no connection error but unexpected status, generate error
		if(error != nil && *error == nil)
		{
			*error = [NSError errorWithDomain:@"myDomain"
										 code:99
									 userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:NSLocalizedString(@"Connection to remote host failed with status code %d.", @""), [response statusCode]] forKey:NSLocalizedDescriptionKey]];
		}
		return NO;
	}
}

- (void)indicateError:(NSObject<DataSourceDelegate> *)delegate error:(__unsafe_unretained NSError *)error
{
	// check if delegate wants to be informated about errors
	SEL errorParsing = @selector(dataSourceDelegate:errorParsingDocument:);
	NSMethodSignature *sig = [delegate methodSignatureForSelector:errorParsing];
	if(delegate && [delegate respondsToSelector:errorParsing] && sig)
	{
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
		[invocation retainArguments];
		[invocation setTarget:delegate];
		[invocation setSelector:errorParsing];
		//[invocation setArgument:&self atIndex:2];
		[invocation setArgument:&error atIndex:3];
		[invocation performSelectorOnMainThread:@selector(invoke) withObject:NULL
								  waitUntilDone:NO];
	}
}

- (void)indicateSuccess:(NSObject<DataSourceDelegate> *)delegate
{
	// check if delegate wants to be informated about parsing end
	SEL finishedParsing = @selector(dataSourceDelegateFinishedParsingDocument:);
	NSMethodSignature *sig = [delegate methodSignatureForSelector:finishedParsing];
	if(delegate && [delegate respondsToSelector:finishedParsing] && sig)
	{
		NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
		[invocation retainArguments];
		[invocation setTarget:delegate];
		[invocation setSelector:finishedParsing];
		//[invocation setArgument:&self atIndex:2];
		[invocation performSelectorOnMainThread:@selector(invoke) withObject:NULL
								  waitUntilDone:NO];
	}
}

#pragma mark Services

- (Result *)zapTo:(NSObject<ServiceProtocol> *) service
{
	Result *result = [Result createResult];

	// Generate URI
	NSURL *myURI = [NSURL URLWithString: [NSString stringWithFormat:@"/control/zapto?%@", [service.sref urlencode]] relativeToURL: _baseAddress];

	NSHTTPURLResponse *response;
	[SynchronousRequestReader sendSynchronousRequest:myURI
								   returningResponse:&response
											   error:nil];

	result.result = ([response statusCode] == 200);
	result.resulttext = [NSHTTPURLResponse localizedStringForStatusCode: [response statusCode]];
	return result;
}

- (BaseXMLReader *)fetchBouquets: (NSObject<ServiceSourceDelegate> *)delegate isRadio:(BOOL)isRadio
{
	if(isRadio)
	{
#if IS_DEBUG()
		[NSException raise:@"ExcUnsupportedFunction" format:@""];
#endif
		return nil;
	}

	// Generate URI
	NSURL *myURI = [NSURL URLWithString: @"/control/getbouquets" relativeToURL: _baseAddress];

	NSHTTPURLResponse *response;
	NSError *error = nil;
	NSData *data = [SynchronousRequestReader sendSynchronousRequest:myURI
												  returningResponse:&response
															  error:&error];

	// Error occured, so send fake object
	if(error || !data)
	{
		NSObject<ServiceProtocol> *fakeService = [[GenericService alloc] init];
		fakeService.sname = NSLocalizedString(@"Error retrieving Data", @"");
		[delegate performSelectorOnMainThread: @selector(addService:)
								   withObject: fakeService
								waitUntilDone: NO];

		[self indicateError:delegate error:error];
		return nil;
	}

	// Parse
	const NSString *baseString = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
	const NSArray *bouquetStringList = [baseString componentsSeparatedByString: @"\n"];
	for(NSString *bouquetString in bouquetStringList)
	{
		// Number Name
		NSRange firstSpace = [bouquetString rangeOfString:@" " options:NSLiteralSearch range:NSMakeRange(0, [bouquetString length])];
		if(firstSpace.length == 0 || [bouquetString length] < firstSpace.location + 1) // something bad happened… but maybe it will go away if we just ignore it ;-)
			continue;

		NSObject<ServiceProtocol> *service = [[GenericService alloc] init];
		service.sref = [bouquetString substringToIndex:firstSpace.location];
		service.sname = [bouquetString substringFromIndex:firstSpace.location + 1];

		[delegate performSelectorOnMainThread: @selector(addService:)
								   withObject: service
								waitUntilDone: NO];
	}

	[self indicateSuccess:delegate];
	return nil;
}

- (BaseXMLReader *)fetchServices: (NSObject<ServiceSourceDelegate> *)delegate bouquet:(NSObject<ServiceProtocol> *)bouquet isRadio:(BOOL)isRadio
{
	if(isRadio)
	{
#if IS_DEBUG()
		[NSException raise:@"ExcUnsupportedFunction" format:@""];
#endif
		return nil;
	}

	// split view on ipad
	if(!bouquet)
	{
		[self indicateSuccess:delegate];
		return nil;
	}

	NSURL *myURI = [NSURL URLWithString: [NSString stringWithFormat:@"/control/getbouquet?xml=true&bouquet=%@&mode=TV", bouquet.sref] relativeToURL: _baseAddress];

	BaseXMLReader *streamReader = [[NeutrinoServiceXMLReader alloc] initWithDelegate:delegate];
	[streamReader parseXMLFileAtURL:myURI parseError:nil];
	return streamReader;
}

- (BaseXMLReader *)fetchEPG: (NSObject<EventSourceDelegate> *)delegate service:(NSObject<ServiceProtocol> *)service
{
	// TODO: Maybe we should not hardcode "max"
	NSURL *myURI = [NSURL URLWithString: [NSString stringWithFormat:@"/control/epg?xml=true&channelid=%@&details=true", service.sref] relativeToURL: _baseAddress];

	BaseXMLReader *streamReader = [[NeutrinoEventXMLReader alloc] initWithDelegate:delegate];
	[streamReader parseXMLFileAtURL:myURI parseError:nil];
	return streamReader;
}

- (NSURL *)getStreamURLForService:(NSObject<ServiceProtocol> *)service
{
	// XXX: we first zap on the receiver and subsequently retrieve the new streaming url, any way to optimize this?
	Result *result = [self zapTo:service];
	if(result.result)
	{
		NSURL *myURI = [NSURL URLWithString:@"/control/build_live_url" relativeToURL:_baseAddress];

		NSHTTPURLResponse *response;
		NSError *error = nil;
		NSData *data = [SynchronousRequestReader sendSynchronousRequest:myURI
													  returningResponse:&response
																  error:&error];

		NSString *myString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		NSString *bogusAddress = [NSString stringWithFormat:@"%@:%d", _baseAddress.host, [_baseAddress.port integerValue]];
		myString = [myString stringByReplacingOccurrencesOfString:bogusAddress withString:_baseAddress.host];
		myURI = [NSURL URLWithString:myString];
		return myURI;
	}
	return nil;
}

#pragma mark Timer

// TODO: reimplement this as streaming parser some day :-)
- (BaseXMLReader *)fetchTimers: (NSObject<TimerSourceDelegate> *)delegate
{
	// Generate URI
	NSURL *myURI = [NSURL URLWithString:@"/control/timer?format=id" relativeToURL:_baseAddress];

	NSHTTPURLResponse *response;
	NSError *error = nil;
	NSData *data = [SynchronousRequestReader sendSynchronousRequest:myURI
												  returningResponse:&response
															  error:&error];

	// Error occured, so send fake object
	if(error || !data)
	{
		NSObject<TimerProtocol> *fakeObject = [[GenericTimer alloc] init];
		fakeObject.title = NSLocalizedString(@"Error retrieving Data", @"");
		fakeObject.state = 0;
		fakeObject.valid = NO;
		[delegate performSelectorOnMainThread: @selector(addTimer:)
								   withObject: fakeObject
								waitUntilDone: NO];

		[self indicateError:delegate error:error];
		return nil;
	}

	// get string encoding for getting services through xml
	CFStringEncoding cfenc = CFStringConvertNSStringEncodingToEncoding(NSISOLatin1StringEncoding);
	CFStringRef cfencstr = CFStringConvertEncodingToIANACharSetName(cfenc);
	CFIndex length = CFStringGetLength(cfencstr);
	char *enc = (char *)malloc(length + 1);
	const BOOL conversionResult = enc == NULL ? NO : CFStringGetCString(cfencstr, enc, length, kCFStringEncodingUTF8);
	if(!conversionResult)
	{
		free(enc);
		enc = NULL; // try no encoding
	}

	// Parse
	const NSString *baseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	const NSArray *timerStringList = [baseString componentsSeparatedByString: @"\n"];
	const NSMutableDictionary *serviceMap = [NSMutableDictionary dictionary];
	for(NSString *timerString in timerStringList)
	{
		// eventID eventType eventRepeat repcount announceTime alarmTime stopTime data
		NSArray *timerStringComponents = [timerString componentsSeparatedByString:@" "];

		if([timerStringComponents count] < 8) // NOTE: should not happen... but hopefully not our fault if it does...
			continue;

		NSObject<TimerProtocol> *timer = [[GenericTimer alloc] init];

		// Determine type, reject unhandled
		const NSInteger timerType = [[timerStringComponents objectAtIndex: 1] integerValue];
		if(timerType == neutrinoTimerTypeRecord)
			timer.justplay = NO;
		else if(timerType == neutrinoTimerTypeZapto)
			timer.justplay = YES;
		else
		{
			timer = nil;
			continue;
		}

		timer.eit = [timerStringComponents objectAtIndex: 0]; // NOTE: actually wrong but we need it :-)
		timer.title = [NSString stringWithFormat: @"Timer %@", timer.eit];
		timer.repeated = [[timerStringComponents objectAtIndex: 2] integerValue]; // NOTE: as long as we don't offer to edit this via gui we can just keep the value and not change it to some common interpretation
		timer.repeatcount = [[timerStringComponents objectAtIndex: 3] integerValue];
		if(timer.justplay)
		{
			// NOTE: internally we require begin & end even for justplay timers
			// until we change this use announce & alarm for justplay, because stop is 0
			[timer setBeginFromString: [timerStringComponents objectAtIndex: 4]]; // announce
			[timer setEndFromString: [timerStringComponents objectAtIndex: 5]]; // alarm
		}
		else
		{
			[timer setBeginFromString: [timerStringComponents objectAtIndex: 5]]; // alarm
			[timer setEndFromString: [timerStringComponents objectAtIndex: 6]]; // stop
		}

		// Eventually fetch Service from our Cache
		NSRange objRange;
		objRange.location = 7;
		objRange.length = [timerStringComponents count] - 7;
		NSString *sref = [[timerStringComponents subarrayWithRange:objRange] componentsJoinedByString:@" "];

		NSObject<ServiceProtocol> *service = [serviceMap valueForKey:sref];
		if(service == nil)
		{
			// create new service
			service = [[GenericService alloc] init];
			service.sref = sref;

			// request epg for channel id with no events (to retrieve name)
			myURI = [NSURL URLWithString:[NSString stringWithFormat:@"/control/epg?xml=true&channelid=%@&max=0", [sref urlencode]] relativeToURL:_baseAddress];
			NSData *data = [SynchronousRequestReader sendSynchronousRequest:myURI
														  returningResponse:nil
																	  error:&error];
			xmlDocPtr doc = NULL;
			xmlXPathContextPtr xpathCtx = NULL;
			xmlXPathObjectPtr xpathObj = NULL;
			if(error == nil)
			{
				doc = xmlReadMemory([data bytes], [data length], "", enc, XML_PARSE_RECOVER);
			}
			if(doc != NULL) do
			{
				xmlNodeSetPtr nodes;

				xpathCtx = xmlXPathNewContext(doc);
				if(!xpathCtx) break;

				// get state
				xpathObj = xmlXPathEvalExpression((xmlChar *)"/epglist/channel_name", xpathCtx);
				if(!xpathObj) break;

				nodes = xpathObj->nodesetval;
				if(!nodes) break;

				if(nodes->nodeNr > 0)
				{
					xmlChar *stringVal = xmlNodeListGetString(doc, nodes->nodeTab[0]->children, 1);
					service.sname = [NSString stringWithCString:(const char *)stringVal encoding:NSISOLatin1StringEncoding];
					xmlFree(stringVal);
				}
			} while(0);
			xmlXPathFreeObject(xpathObj);
			xmlXPathFreeContext(xpathCtx);
			xmlFreeDoc(doc);
			error = nil; // reset possible error code

			// set invalid name if not found
			if(service.sname == nil || [service.sname isEqualToString:@""])
			{
				service.sname = [NSString stringWithFormat:NSLocalizedString(@"Unknown Service (%@)", @"Unable to find service name for service id"), sref];
			}

			// keep in cache
			[serviceMap setValue:service forKey:sref];
		}
		timer.service = service;

		// Determine state
		const NSDate *announce = [NSDate dateWithTimeIntervalSince1970:
									[[timerStringComponents objectAtIndex: 4] doubleValue]];
		if([announce timeIntervalSinceNow] > 0)
			timer.state = kTimerStateWaiting;
		else if([timer.begin timeIntervalSinceNow] > 0)
			timer.state = kTimerStatePrepared;
		else if([timer.end timeIntervalSinceNow] > 0)
			timer.state = kTimerStateRunning;
		else
			timer.state = kTimerStateFinished;

		[delegate performSelectorOnMainThread: @selector(addTimer:)
								   withObject: timer
								waitUntilDone: NO];
	}
	free(enc);

	[self indicateSuccess:delegate];
	return nil;
}

- (Result *)addTimer:(NSObject<TimerProtocol> *) newTimer
{
	Result *result = [Result createResult];

	// Generate URI
	// NOTE: Fails if I try to format the whole URL by one stringWithFormat... type will be wrong and sref can't be read so the program will crash
	NSMutableString *add = [NSMutableString stringWithCapacity: 100];
	[add appendString: @"/control/timer?action=new"];
	if(newTimer.justplay)
	{
		const NSInteger end = (NSInteger)[newTimer.end timeIntervalSince1970];
		[add appendFormat:@"&announce=%d&alarm=%d&stop=%d&type=", (NSInteger)[newTimer.begin timeIntervalSince1970], end, end + 120];
		[add appendFormat:@"%d", neutrinoTimerTypeZapto];
	}
	else
	{
		[add appendFormat:@"&alarm=%d&stop=%d&type=", (int)[newTimer.begin timeIntervalSince1970], (int)[newTimer.end timeIntervalSince1970]];
		[add appendFormat:@"%d", neutrinoTimerTypeRecord];
	}

	[add appendString: @"&channel_id="];
	[add appendString: [newTimer.service.sref urlencode]];
	NSURL *myURI = [NSURL URLWithString: add relativeToURL: _baseAddress];

	NSHTTPURLResponse *response;
	[SynchronousRequestReader sendSynchronousRequest:myURI
								   returningResponse:&response
											   error:nil];

	// Sourcecode suggests that they always return ok, so we only do this simple check
	result.result = ([response statusCode] == 200);
	result.resulttext = [NSHTTPURLResponse localizedStringForStatusCode: [response statusCode]];
	return result;
}

- (Result *)editTimer:(NSObject<TimerProtocol> *) oldTimer: (NSObject<TimerProtocol> *) newTimer
{
	Result *result = [Result createResult];

	// Generate URI
	// NOTE: Fails if I try to format the whole URL by one stringWithFormat... type will be wrong and sref can't be read so the program will crash
	NSMutableString *add = [NSMutableString stringWithCapacity: 100];
	[add appendFormat: @"/control/timer?action=modify&id=%@", oldTimer.eit];
	if(newTimer.justplay)
	{
		const NSInteger end = (NSInteger)[newTimer.end timeIntervalSince1970];
		[add appendFormat:@"&announce=%d&alarm=%d&stop=%d&type=", (NSInteger)[newTimer.begin timeIntervalSince1970], end, end + 120];
		[add appendFormat:@"%d", neutrinoTimerTypeZapto];
	}
	else
	{
		[add appendFormat:@"&alarm=%d&stop=%d&type=", (NSInteger)[newTimer.begin timeIntervalSince1970], (NSInteger)[newTimer.end timeIntervalSince1970]];
		[add appendFormat:@"%d", neutrinoTimerTypeRecord];
	}

	[add appendString: @"&channel_id="];
	[add appendString: [newTimer.service.sref urlencode]];
	[add appendString: @"&rep="];
	[add appendFormat: @"%d", newTimer.repeated];
	[add appendString: @"&repcount="];
	[add appendFormat: @"%d", newTimer.repeatcount];
	NSURL *myURI = [NSURL URLWithString: add relativeToURL: _baseAddress];

	NSHTTPURLResponse *response;
	[SynchronousRequestReader sendSynchronousRequest:myURI
								   returningResponse:&response
											   error:nil];

	// Sourcecode suggests that they always return ok, so we only do this simple check
	result.result = ([response statusCode] == 200);
	result.resulttext = [NSHTTPURLResponse localizedStringForStatusCode: [response statusCode]];
	return result;
}

- (Result *)delTimer:(NSObject<TimerProtocol> *) oldTimer
{
	Result *result = [Result createResult];

	// Generate URI
	NSURL *myURI = [NSURL URLWithString: [NSString stringWithFormat: @"/control/timer?action=remove&id=%@", oldTimer.eit] relativeToURL: _baseAddress];

	NSHTTPURLResponse *response;
	[SynchronousRequestReader sendSynchronousRequest:myURI
								   returningResponse:&response
											   error:nil];

	// Sourcecode suggests that they always return ok, so we only do this simple check
	result.result = ([response statusCode] == 200);
	result.resulttext = [NSHTTPURLResponse localizedStringForStatusCode: [response statusCode]];
	return result;
}

- (Result *)cleanupTimers:(const NSArray *)timers
{
	// not needed afaik, timerd cleans up automatically
	return nil;
}

#pragma mark Recordings

- (BaseXMLReader *)fetchMovielist: (NSObject<MovieSourceDelegate> *)delegate withLocation: (NSString *)location
{
	// is this possible?
	return nil;
}

#pragma mark Control

// XXX: not working correctly (does not skip old events if they are returned), hence the feature is still disabled
- (BaseXMLReader *)getCurrent: (NSObject<EventSourceDelegate,ServiceSourceDelegate> *)delegate
{
	NSURL *myURI = [NSURL URLWithString:@"/control/zapto" relativeToURL: _baseAddress];

	NSHTTPURLResponse *response;
	NSError *error = nil;
	NSData *data = [SynchronousRequestReader sendSynchronousRequest:myURI
												  returningResponse:&response
															  error:&error];

	// invalid status, abort
	if([response statusCode] != 200 || error)
	{
		[self indicateError:delegate error:error];
		return nil;
	}

	NSString *serviceId = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
	myURI = [NSURL URLWithString:[NSString stringWithFormat:@"/control/epg?xml=true&channelid=%@&details=true&max=50", [serviceId urlencode]] relativeToURL:_baseAddress];
	BaseXMLReader *streamReader = [[NeutrinoEventXMLReader alloc] initWithDelegate:delegate andGetCurrent:YES];
	[streamReader parseXMLFileAtURL:myURI parseError:nil];

	return streamReader;
}

- (void)sendPowerstate: (NSString *) newState
{
	// Generate URI
	NSURL *myURI = [NSURL URLWithString: [NSString stringWithFormat:@"/control/%@", newState] relativeToURL: _baseAddress];

	NSHTTPURLResponse *response;
	[SynchronousRequestReader sendSynchronousRequest:myURI
								   returningResponse:&response
											   error:nil];
}

- (void)shutdown
{
	[self sendPowerstate: @"shutdown"];
}

- (void)standby
{
	// Generate URI
	NSURL *myURI = [NSURL URLWithString: @"/control/standby" relativeToURL: _baseAddress];

	[APP_DELEGATE addNetworkOperation];

	NSHTTPURLResponse *response;
	NSData *data = [SynchronousRequestReader sendSynchronousRequest:myURI
												  returningResponse:&response
															  error:nil];

	NSString *myString = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
	const BOOL equalsOn = [myString isEqualToString: @"on"]; // NOTE: on non-dbox2 hw this always returns "off"
	if(equalsOn)
		myString = @"standby?off";
	else
		myString = @"standby?on";

	[self sendPowerstate: myString];

	[APP_DELEGATE removeNetworkOperation];
}

- (void)reboot
{
	[self sendPowerstate: @"reboot"];
}

- (void)restart
{
	// NOTE: not available
}

- (void)getVolume: (NSObject<VolumeSourceDelegate> *)delegate
{
	GenericVolume *volumeObject = [[GenericVolume alloc] init];

	// Generate URI (mute)
	NSURL *myURI = [NSURL URLWithString: @"/control/volume?status" relativeToURL: _baseAddress];

	NSHTTPURLResponse *response;
	NSData *data = [SynchronousRequestReader sendSynchronousRequest:myURI
												  returningResponse:&response
															  error:nil];
	
	NSString *myString = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
	if([myString isEqualToString: @"1"])
		volumeObject.ismuted = YES;
	else
		volumeObject.ismuted = NO;


	// Generate URI (volume)
	myURI = [NSURL URLWithString: @"/control/volume" relativeToURL: _baseAddress];

	data = [SynchronousRequestReader sendSynchronousRequest:myURI
										  returningResponse:&response
													  error:nil];
	
	myString = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
	volumeObject.current = [myString integerValue];


	[delegate performSelectorOnMainThread: @selector(addVolume:)
							   withObject: volumeObject
							waitUntilDone: NO];
}

- (BOOL)toggleMuted
{
	// Generate URI
	NSURL *myURI = [NSURL URLWithString: @"/control/volume?status" relativeToURL: _baseAddress];

	NSHTTPURLResponse *response;
	NSData *data = [SynchronousRequestReader sendSynchronousRequest:myURI
												  returningResponse:&response
															  error:nil];
	
	const NSString *myString = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
	const BOOL equalsRes = [myString isEqualToString: @"1"];
	if(equalsRes)
		myString = @"unmute";
	else
		myString = @"mute";


	// Generate new URI
	myURI = [NSURL URLWithString: [NSString stringWithFormat: @"/control/volume?%@", myString] relativeToURL: _baseAddress];

	[SynchronousRequestReader sendSynchronousRequest:myURI
								   returningResponse:&response
											   error:nil];

	return !equalsRes;
}

- (Result *)setVolume:(NSInteger) newVolume
{
	Result *result = [Result createResult];

	// neutrino expect volume to be a multiple of 5
	const NSUInteger diff = newVolume % 5;
	// NOTE: to make this code easier we could just add/remove the diff but lets try it fair first :-)
	if(diff < 3)
		newVolume -= diff;
	else
		newVolume += diff;

	// Generate URI
	NSURL *myURI = [NSURL URLWithString: [NSString stringWithFormat: @"/control/volume?%d", newVolume] relativeToURL: _baseAddress];

	NSHTTPURLResponse *response;
	[SynchronousRequestReader sendSynchronousRequest:myURI
								   returningResponse:&response
											   error:nil];

	// Sourcecode suggests that they always return ok, so we only do this simple check
	result.result = ([response statusCode] == 200);
	result.resulttext = [NSHTTPURLResponse localizedStringForStatusCode: [response statusCode]];
	return result;
}

- (Result *)sendButton:(NSInteger) type
{
	Result *result = [Result createResult];

	// We fake some button codes (namely tv/radio) so we have to be able to set a custom uri
	NSURL *myURI = nil;

	// Translate ButtonCodes
	NSString *buttonCode = nil;
	switch(type)
	{
		case kButtonCode0: buttonCode = @"KEY_0"; break;
		case kButtonCode1: buttonCode = @"KEY_1"; break;
		case kButtonCode2: buttonCode = @"KEY_2"; break;
		case kButtonCode3: buttonCode = @"KEY_3"; break;
		case kButtonCode4: buttonCode = @"KEY_4"; break;
		case kButtonCode5: buttonCode = @"KEY_5"; break;
		case kButtonCode6: buttonCode = @"KEY_6"; break;
		case kButtonCode7: buttonCode = @"KEY_7"; break;
		case kButtonCode8: buttonCode = @"KEY_8"; break;
		case kButtonCode9: buttonCode = @"KEY_9"; break;
		case kButtonCodeMenu: buttonCode = @"KEY_SETUP"; break;
		case kButtonCodeLeft: buttonCode = @"KEY_LEFT"; break;
		case kButtonCodeRight: buttonCode = @"KEY_RIGHT"; break;
		case kButtonCodeUp: buttonCode = @"KEY_UP"; break;
		case kButtonCodeDown: buttonCode = @"KEY_DOWN"; break;
		case kButtonCodeLame: buttonCode = @"KEY_HOME"; break;
		case kButtonCodeRed: buttonCode = @"KEY_RED"; break;
		case kButtonCodeGreen: buttonCode = @"KEY_GREEN"; break;
		case kButtonCodeYellow: buttonCode = @"KEY_YELLOW"; break;
		case kButtonCodeBlue: buttonCode = @"KEY_BLUE"; break;
		case kButtonCodeVolUp: buttonCode = @"KEY_VOLUMEUP"; break;
		case kButtonCodeVolDown: buttonCode = @"KEY_VOLUMEDOWN"; break;
		case kButtonCodeMute: buttonCode = @"KEY_MUTE"; break;
		case kButtonCodeHelp: buttonCode = @"KEY_HELP"; break;
		case kButtonCodePower: buttonCode = @"KEY_POWER"; break;
		case kButtonCodeOK: buttonCode = @"KEY_OK"; break;
		case kButtonCodeTV:
			myURI = [NSURL URLWithString: @"/control/setmode?tv" relativeToURL: _baseAddress];
			break;
		case kButtonCodeRadio:
			myURI = [NSURL URLWithString: @"/control/setmode?radio" relativeToURL: _baseAddress];
			break;
		//case kButtonCode: buttonCode = @"KEY_"; break; // meant for copy&paste ;-)
		default:
			break;
	}

	if(myURI == nil)
	{
		if(buttonCode == nil)
		{
			result.result = NO;
			result.resulttext = NSLocalizedString(@"Unable to map button to keycode!", @"");
			return result;
		}

		// Generate URI
		myURI = [NSURL URLWithString: [NSString stringWithFormat: @"/control/rcem?%@", buttonCode] relativeToURL: _baseAddress];
	}

	NSHTTPURLResponse *response;
	[SynchronousRequestReader sendSynchronousRequest:myURI
								   returningResponse:&response
											   error:nil];

	result.result = ([response statusCode] == 200);
	result.resulttext = [NSHTTPURLResponse localizedStringForStatusCode: [response statusCode]];
	return result;
}

#pragma mark Messaging

- (Result *)sendMessage:(NSString *)message: (NSString *)caption: (NSInteger)type: (NSInteger)timeout
{
	Result *result = [Result createResult];

	// Generate URI
	NSURL *myURI = [NSURL URLWithString: [NSString stringWithFormat: @"/control/message?%@=%@", type == kNeutrinoMessageTypeConfirmed ? @"nmsg" : @"popup", [message urlencode]] relativeToURL: _baseAddress];

	NSHTTPURLResponse *response;
	[SynchronousRequestReader sendSynchronousRequest:myURI
								   returningResponse:&response
											   error:nil];

	result.result = ([response statusCode] == 200);
	result.resulttext = [NSHTTPURLResponse localizedStringForStatusCode: [response statusCode]];
	return result;
}

- (const NSUInteger const)getMaxMessageType
{
	return kNeutrinoMessageTypeMax;
}

- (NSString *)getMessageTitle: (NSUInteger)type
{
	switch(type)
	{
		case kNeutrinoMessageTypeNormal:
			return NSLocalizedString(@"Normal", @"Message type");
		case kNeutrinoMessageTypeConfirmed:
			return NSLocalizedString(@"Confirmed", @"Message type");
		default:
			return @"???";
	}
}

#pragma mark Screenshots

- (NSData *)getScreenshot: (enum screenshotType)type
{
	//if(type == kScreenshotTypeOSD)
	{
		// Generate URI
		NSURL *myURI = [NSURL URLWithString: @"/control/exec?Y_Tools&fbshot&-r&-o&/tmp/dreaMote_Screenshot.bmp" relativeToURL: _baseAddress];

		NSHTTPURLResponse *response;
		[SynchronousRequestReader sendSynchronousRequest:myURI
									   returningResponse:&response
												   error:nil];

		// something went wrong, try another way
		if([response statusCode] != 200)
		{
			// Generate URI
			myURI = [NSURL URLWithString: @"/control/exec?Y_Tools&fbshot&-o&/tmp/dreaMote_Screenshot.bmp" relativeToURL: _baseAddress];

			[SynchronousRequestReader sendSynchronousRequest:myURI
										   returningResponse:&response
													   error:nil];
		}

		// Generate URI
		myURI = [NSURL URLWithString: @"/tmp/dreaMote_Screenshot.bmp" relativeToURL: _baseAddress];

		NSData *data = [SynchronousRequestReader sendSynchronousRequest:myURI
													  returningResponse:&response
																  error:nil];

		// Generate URI
		myURI = [NSURL URLWithString: @"/control/exec?Y_Tools&fbshot_clear" relativeToURL: _baseAddress];

		[SynchronousRequestReader sendSynchronousRequest:myURI
									   returningResponse:&response
												   error:nil];

		return data;
	}
	return nil;
}

#pragma mark Unsupported

- (BaseXMLReader *)fetchLocationlist: (NSObject<LocationSourceDelegate> *)delegate;
{
#if IS_DEBUG()
	[NSException raise:@"ExcUnsupportedFunction" format:@""];
#endif
	return nil;
}

@end
