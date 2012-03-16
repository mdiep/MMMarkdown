//
//  MMTextSection.m
//  MMMarkdown
//
//  Copyright (c) 2012 Matt Diephouse.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "MMTextSegment.h"


@implementation MMTextSegment
{
    NSMutableArray *_ranges;
}

@synthesize string = _string;
@synthesize ranges = _ranges;

//==================================================================================================
#pragma mark -
#pragma mark Public Methods
//==================================================================================================

+ (id) segmentWithString:(NSString *)aString
{
    return [[[self class] alloc] initWithString:aString];
}

- (id) initWithString:(NSString *)aString
{
    self = [super init];
    
    if (self)
    {
        _string = aString;
        _ranges = [NSMutableArray new];
    }
    
    return self;
}

- (void) addRange:(NSRange)aRange
{
    [self willChangeValueForKey:@"ranges"];
    [_ranges addObject:[NSValue valueWithRange:aRange]];
    [self didChangeValueForKey:@"ranges"];
}

- (void) removeLastRange
{
    [self willChangeValueForKey:@"ranges"];
    [_ranges removeLastObject];
    [self didChangeValueForKey:@"ranges"];
}


//==================================================================================================
#pragma mark -
#pragma mark Public Methods
//==================================================================================================

- (void) setRanges:(NSArray *)ranges
{
    _ranges = [ranges mutableCopy];
}


@end
