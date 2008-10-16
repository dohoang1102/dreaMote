//
//  Enigma2Connector.m
//  Untitled
//
//  Created by Moritz Venn on 08.03.08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "Enigma2Connector.h"

#import "Service.h"
#import "Timer.h"
#import "Event.h"
#import "Volume.h"

#import "Enigma/ServiceXMLReader.h"
#import "Enigma/EventXMLReader.h"
#import "Enigma/TimerXMLReader.h"
#import "Enigma/VolumeXMLReader.h"
#import "Enigma/MovieXMLReader.h"

enum powerStates {
	kShutdownState = 1,
	kRebootState = 2,
	kRestartGUIState = 3,
};

@implementation Enigma2Connector

@synthesize baseAddress;

- (const BOOL)hasFeature: (enum connectorFeatures)feature
{
	return
		(feature == kFeaturesDisabledTimers) ||
		(feature == kFeaturesExtendedRecordInfo) ||
		(feature == kFeaturesGUIRestart);
}

- (NSInteger)getMaxVolume
{
	return 100;
}

- (id)initWithAddress:(NSString *) address
{
	if(self = [super init])
	{
		self.baseAddress = [NSURL URLWithString: address];
	}
	return self;
}

- (void)dealloc
{
	[baseAddress release];

	[super dealloc];
}

+ (id <RemoteConnector>*)createClassWithAddress:(NSString *) address
{
	return (id <RemoteConnector>*)[[Enigma2Connector alloc] initWithAddress: address];
}

- (BOOL)isReachable
{
	// Generate URI
	NSURL *myURI = [NSURL URLWithString:@"/web/about" relativeToURL:baseAddress];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	NSHTTPURLResponse *response;
	NSURLRequest *request = [NSURLRequest requestWithURL: myURI
											 cachePolicy: NSURLRequestReloadIgnoringCacheData timeoutInterval: 5];
	[NSURLConnection sendSynchronousRequest: request
										 returningResponse: &response error: nil];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

	return ([response statusCode] == 200);
}

- (BOOL)zapTo:(Service *) service
{
	// Generate URI
	NSURL *myURI = [NSURL URLWithString:[NSString stringWithFormat:@"/web/zap?sRef=%@", [service.sref stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding]] relativeToURL:baseAddress];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	// Create URL Object and download it
	NSHTTPURLResponse *response;
	NSURLRequest *request = [NSURLRequest requestWithURL: myURI
											 cachePolicy: NSURLRequestReloadIgnoringCacheData timeoutInterval: 5];
	[NSURLConnection sendSynchronousRequest: request
										 returningResponse: &response error: nil];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

	return ([response statusCode] == 200);
}

- (void)fetchServices:(id)target action:(SEL)action
{
	NSURL *myURI = [NSURL URLWithString: [NSString stringWithFormat:@"/web/getservices?sRef=%@", @"1:7:1:0:0:0:0:0:0:0:FROM%20BOUQUET%20%22userbouquet.favourites.tv%22%20ORDER%20BY%20bouquet"]  relativeToURL:baseAddress];

	NSError *parseError = nil;

	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	ServiceXMLReader *streamReader = [ServiceXMLReader initWithTarget: target action: action];
	[streamReader parseXMLFileAtURL:myURI parseError:&parseError];
	[streamReader release];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

- (void)fetchEPG:(id)target action:(SEL)action service:(Service *)service
{
	NSURL *myURI = [NSURL URLWithString: [NSString stringWithFormat:@"/web/epgservice?sRef=%@", service.sref] relativeToURL: baseAddress];

	NSError *parseError = nil;

	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	EnigmaEventXMLReader *streamReader = [EnigmaEventXMLReader initWithTarget: target action: action];
	[streamReader parseXMLFileAtURL:myURI parseError:&parseError];
	[streamReader release];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

- (void)fetchTimers:(id)target action:(SEL)action
{
	NSURL *myURI = [NSURL URLWithString: @"/web/timerlist" relativeToURL: baseAddress];
	
	NSError *parseError = nil;
	
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
	
	TimerXMLReader *streamReader = [TimerXMLReader initWithTarget: target action: action];
	[streamReader parseXMLFileAtURL:myURI parseError:&parseError];
	[streamReader release];
	
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

- (void)fetchMovielist:(id)target action:(SEL)action
{
	NSURL *myURI = [NSURL URLWithString: @"/web/movielist" relativeToURL: baseAddress];
	
	NSError *parseError = nil;
	
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
	
	MovieXMLReader *streamReader = [MovieXMLReader initWithTarget: target action: action];
	[streamReader parseXMLFileAtURL:myURI parseError:&parseError];
	[streamReader release];
	
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

- (void)sendPowerstate: (NSInteger) newState
{
	// Generate URI
	NSURL *myURI = [NSURL URLWithString: [NSString stringWithFormat:@"/web/powerstate?newstate=%d", newState] relativeToURL: baseAddress];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	// Create URL Object and download it
	NSURLResponse *response;
	NSURLRequest *request = [NSURLRequest requestWithURL: myURI
											 cachePolicy: NSURLRequestReloadIgnoringCacheData timeoutInterval: 5];
	[NSURLConnection sendSynchronousRequest: request
										 returningResponse: &response error: nil];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

- (void)shutdown
{
	[self sendPowerstate: kShutdownState];
}

- (void)standby
{
	// XXX: we send remote control command button power here as we want to toggle standby
	[self sendButton: kButtonCodePower];
}

- (void)reboot
{
	[self sendPowerstate: kRebootState];
}

- (void)restart
{
	[self sendPowerstate: kRestartGUIState];
}

- (void)getVolume:(id)target action:(SEL)action
{
	NSURL *myURI = [NSURL URLWithString: @"/web/vol" relativeToURL: baseAddress];

	NSError *parseError = nil;
	
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	VolumeXMLReader *streamReader = [VolumeXMLReader initWithTarget: target action: action];
	[streamReader parseXMLFileAtURL:myURI parseError:&parseError];
	[streamReader release];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

- (BOOL)toggleMuted
{
	// Generate URI
	NSURL *myURI = [NSURL URLWithString: @"/web/vol?set=mute" relativeToURL: baseAddress];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	// Create URL Object and download it
	NSURLResponse *response;
	NSURLRequest *request = [NSURLRequest requestWithURL: myURI
											 cachePolicy: NSURLRequestReloadIgnoringCacheData timeoutInterval: 5];
	NSData *data = [NSURLConnection sendSynchronousRequest: request
										 returningResponse: &response error: nil];
	
	NSString *myString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

	NSRange myRange = [myString rangeOfString: @"<e2ismuted>True</e2ismuted>"];
	if(myRange.length)
		return YES;

	return NO;
}

- (BOOL)setVolume:(NSInteger) newVolume
{
	// Generate URI
	NSURL *myURI = [NSURL URLWithString: [NSString stringWithFormat:@"/web/vol?set=set%d", newVolume] relativeToURL: baseAddress];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	// Create URL Object and download it
	NSURLResponse *response;
	NSURLRequest *request = [NSURLRequest requestWithURL: myURI
											 cachePolicy: NSURLRequestReloadIgnoringCacheData timeoutInterval: 5];
	NSData *data = [NSURLConnection sendSynchronousRequest: request
										 returningResponse: &response error: nil];
	
	NSString *myString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

	NSRange myRange = [myString rangeOfString: @"<e2result>True</e2result>"];
	if(myRange.length)
		return YES;
	
	return NO;
}

- (BOOL)addTimer:(Timer *) newTimer
{
	// Generate URI
	NSURL *myURI = [NSURL URLWithString: [NSString stringWithFormat: @"/web/timeradd?sRef=%@&begin=%d&end=%d&name=%@&description=%@&eit=%@&disabled=%d&justplay=%d&afterevent=%d", newTimer.service.sref, (int)[newTimer.begin timeIntervalSince1970], (int)[newTimer.end timeIntervalSince1970], [newTimer.title stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding], [newTimer.tdescription stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding], newTimer.eit, newTimer.disabled ? 1 : 0, newTimer.justplay ? 1 : 0, newTimer.afterevent] relativeToURL: baseAddress];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	// Create URL Object and download it
	NSURLResponse *response;
	NSURLRequest *request = [NSURLRequest requestWithURL: myURI
											 cachePolicy: NSURLRequestReloadIgnoringCacheData timeoutInterval: 5];
	NSData *data = [NSURLConnection sendSynchronousRequest: request
										 returningResponse: &response error: nil];
	
	NSString *myString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

	NSRange myRange = [myString rangeOfString: @"<e2state>True</e2state>"];
	if(myRange.length)
		return YES;
	
	return NO;
}

- (BOOL)editTimer:(Timer *) oldTimer: (Timer *) newTimer
{
	// Generate URI
	NSURL *myURI = [NSURL URLWithString: [NSString stringWithFormat: @"/web/timerchange?sRef=%@&begin=%d&end=%d&name=%@&description=%@&eit=%@&disabled=%d&justplay=%d&afterevent=%d&channelOld=%@&beginOld=%d&endOld=%d&deleteOldOnSave=1", newTimer.service.sref, (int)[newTimer.begin timeIntervalSince1970], (int)[newTimer.end timeIntervalSince1970], [newTimer.title stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding], [newTimer.tdescription stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding], newTimer.eit, newTimer.disabled ? 1 : 0, newTimer.justplay ? 1 : 0, newTimer.afterevent, oldTimer.service.sref, (int)[oldTimer.begin timeIntervalSince1970], (int)[oldTimer.end timeIntervalSince1970]] relativeToURL: baseAddress];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	// Create URL Object and download it
	NSURLResponse *response;
	NSURLRequest *request = [NSURLRequest requestWithURL: myURI
											 cachePolicy: NSURLRequestReloadIgnoringCacheData timeoutInterval: 5];
	NSData *data = [NSURLConnection sendSynchronousRequest: request
										 returningResponse: &response error: nil];
	
	NSString *myString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

	NSRange myRange = [myString rangeOfString: @"<e2state>True</e2state>"];
	if(myRange.length)
		return YES;
	
	return NO;
}

- (BOOL)delTimer:(Timer *) oldTimer
{
	// Generate URI
	NSURL *myURI = [NSURL URLWithString: [NSString stringWithFormat: @"/web/timerdelete?sRef=%@&begin=%d&end=%d", oldTimer.service.sref, (int)[oldTimer.begin timeIntervalSince1970], (int)[oldTimer.end timeIntervalSince1970]] relativeToURL: baseAddress];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	// Create URL Object and download it
	NSURLResponse *response;
	NSURLRequest *request = [NSURLRequest requestWithURL: myURI
											 cachePolicy: NSURLRequestReloadIgnoringCacheData timeoutInterval: 5];
	NSData *data = [NSURLConnection sendSynchronousRequest: request
										 returningResponse: &response error: nil];
	
	NSString *myString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

	NSRange myRange = [myString rangeOfString: @"<e2state>True</e2state>"];
	if(myRange.length)
		return YES;
	
	return NO;
}

- (BOOL)sendButton:(NSInteger) type
{
	// Generate URI
	NSURL *myURI = [NSURL URLWithString: [NSString stringWithFormat: @"/web/remotecontrol?command=%d", type] relativeToURL: baseAddress];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	// Create URL Object and download it
	NSURLResponse *response;
	NSURLRequest *request = [NSURLRequest requestWithURL: myURI
											 cachePolicy: NSURLRequestReloadIgnoringCacheData timeoutInterval: 5];
	NSData *data = [NSURLConnection sendSynchronousRequest: request
										 returningResponse: &response error: nil];
	
	NSString *myString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

	NSRange myRange = [myString rangeOfString: @"<e2result>True</e2result>"];
	if(myRange.length)
		return YES;
	
	return NO;
}

@end
