//
//  NSURL+Sanitized.m
//  Mastonaut
//
//  Created by Bruno Philipe on 21.03.19.
//  Mastonaut - Mastodon Client for Mac
//  Copyright © 2019 Bruno Philipe.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//

#import "NSURL+Sanitization.h"

@interface NSString (Sanitization)

- (NSString *)removingCharactersFromCharacterSet:(NSCharacterSet *)illegalCharset;
- (NSRange)fullRange;

@end

@implementation NSURL (Sanitization)

+ (NSCharacterSet *)URLInvalidCharset
{
	static NSCharacterSet *charset;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{

		NSMutableCharacterSet *illegalCharset = [[NSCharacterSet illegalCharacterSet] mutableCopy];
		[illegalCharset formUnionWithCharacterSet:[NSCharacterSet controlCharacterSet]];
		charset = [illegalCharset copy];
	});

	return charset;
}

+ (NSRegularExpression *)urlComponentsRegex
{
	static NSRegularExpression *regex;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{

		regex = [NSRegularExpression regularExpressionWithPattern:@"(?<protocol>\\w+)(?<slashes>://)((?<user>\\w+)"
																   "((?<userColon>:)(?<password>\\w+))?(?<at>@))?"
                                                                   "(?<host>[^:/]+)((?<portColon>:)(?<port>\\d+))?"
                                                                   "(?<path>/[^#?]*)?(?<query>\\?"
																   "[^#]+)?((?<octothorpe>#)(?<fragment>.+))?"
														  options:0
															error:nil];
	});

	return regex;
}

+ (NSDictionary<NSString *, NSCharacterSet *> *)captureGroupCharsetMap
{
	static NSDictionary<NSString *, NSCharacterSet *> *instance = nil;

	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		instance = @{@"user": [NSCharacterSet URLUserAllowedCharacterSet],
					 @"password": [NSCharacterSet URLPasswordAllowedCharacterSet],
					 @"host": [NSCharacterSet URLHostAllowedCharacterSet],
					 @"port": [NSCharacterSet decimalDigitCharacterSet],
					 @"path": [NSCharacterSet URLPathAllowedCharacterSet],
					 @"query": [NSCharacterSet URLQueryAllowedCharacterSet],
					 @"fragment": [NSCharacterSet URLFragmentAllowedCharacterSet]};
	});

	return instance;
}

+ (nullable NSURL *)urlBySanitizingAddress:(nonnull NSString *)address
{
	NSString *cleanString = [address removingCharactersFromCharacterSet:[self URLInvalidCharset]];
	cleanString = [cleanString stringByRemovingPercentEncoding];

	if (!cleanString || [cleanString length] == 0) { return nil; }

	NSTextCheckingResult *match = [[self urlComponentsRegex] firstMatchInString:cleanString
																		options:0
																		  range:[cleanString fullRange]];

	if (match == nil) { return nil; }

	NSArray *groups = @[@"protocol", @"slashes", 
                        @"user", @"userColon", @"password", @"at",
                        @"host", @"portColon", @"port",
                        @"path",
                        @"query",
                        @"octothorpe", @"fragment"];

	NSMutableString *sanitizedAddress = [[NSMutableString alloc] initWithCapacity:[cleanString length]];

	for (NSString *captureGroup in groups)
	{
		NSRange captureGroupRange = [match rangeWithName:captureGroup];
		if (captureGroupRange.location == NSNotFound) continue;

		NSString *substring = [cleanString substringWithRange:captureGroupRange];

		NSCharacterSet *allowedCharset = [[self captureGroupCharsetMap] objectForKey:captureGroup];

		if (allowedCharset == nil)
		{
			[sanitizedAddress appendString:substring];
		}
		else
		{
			NSString *escapedString = [substring stringByAddingPercentEncodingWithAllowedCharacters:allowedCharset];
			[sanitizedAddress appendString:escapedString];
		}
	}

	return [NSURL URLWithString:sanitizedAddress];
}

@end

@implementation NSString (Sanitization)

- (NSString *)removingCharactersFromCharacterSet:(NSCharacterSet *)illegalCharset
{
	NSRange searchRange = NSMakeRange(0, [self length]);
	NSMutableString *sanitizedString = [NSMutableString new];

	do
	{
		NSRange invalidRange = [self rangeOfCharacterFromSet:illegalCharset options:0 range:searchRange];

		if (invalidRange.location == NSNotFound)
		{
			break;
		}

		NSRange legalSubrange = NSMakeRange(searchRange.location, invalidRange.location - searchRange.location);
		[sanitizedString appendString:[self substringWithRange:legalSubrange]];

		searchRange = NSMakeRange(NSMaxRange(invalidRange), [self length] - NSMaxRange(invalidRange));
	}
	while (searchRange.length > 0);

	if (searchRange.length > 0)
	{
		[sanitizedString appendString:[self substringWithRange:searchRange]];
	}

	return sanitizedString;
}

- (NSRange)fullRange
{
	return NSMakeRange(0, [self length]);
}

@end
