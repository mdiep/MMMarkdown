//
//  MMScanner.m
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

#import "MMScanner.h"


@interface MMScanner ()
@property (assign, nonatomic) NSUInteger startLocation;
@property (assign, nonatomic) NSRange    lineRange;
@property (strong, nonatomic, readonly) NSMutableArray *transactions;

- (NSUInteger) _locationOfNextLineAfterLocation:(NSUInteger)aLocation;
@end

@implementation MMScanner

@synthesize string = _string;

@synthesize startLocation = _startLocation;
@synthesize lineRange    = _lineRange;
@synthesize transactions = _transactions;

//==================================================================================================
#pragma mark -
#pragma mark Public Methods
//==================================================================================================

+ (id) scannerWithString:(NSString *)aString
{
    return [[[self class] alloc] initWithString:aString];
}

- (id) initWithString:(NSString *)aString
{
    self = [super init];
    
    if (self)
    {
        _string       = aString;
        _transactions = [NSMutableArray new];
        
        self.startLocation = 0;
        self.location      = 0;
    }
    
    return self;
}

- (void) beginTransaction
{
    [self.transactions addObject:[NSValue valueWithRange:self.lineRange]];
}

- (void) commitTransaction:(BOOL)shouldSave
{
    if (!self.transactions.count)
        [NSException raise:@"Transaction underflow" format:@"Could not commit transaction because the stack is empty"];
    
    NSValue *value = [self.transactions lastObject];
    [self.transactions removeLastObject];
    
    if (!shouldSave)
    {
        self.lineRange = [value rangeValue];
    }
}

- (BOOL) atEndOfLine
{
    return self.lineRange.length == 0;
}

- (BOOL) atEndOfString
{
    return self.location >= self.string.length;
}

- (unichar) nextCharacter
{
    if (self.lineRange.length == 0)
        return '\n';
    return [self.string characterAtIndex:self.location];
}

- (void) advance
{
    // Don't advance past the end of the line unless explicitly asked to.
    if ([self atEndOfLine])
        return;
    
    NSRange range = self.lineRange;
    range.location += 1;
    range.length   -= 1;
    self.lineRange = range;
}

- (void) advanceToNextLine
{
    self.location = 1 + NSMaxRange(self.lineRange); // lineRange doesn't include the \n
}

- (NSUInteger) skipCharactersFromSet:(NSCharacterSet *)aSet
{
    NSRange range = [self.string rangeOfCharacterFromSet:[aSet invertedSet]
                                                 options:0
                                                   range:self.lineRange];
    
    NSUInteger current = self.location;
    if (range.location == NSNotFound)
        self.location = NSMaxRange(self.lineRange);
    else
        self.location = range.location;
    return self.location - current;
}

- (NSUInteger) skipCharactersFromSet:(NSCharacterSet *)aSet max:(NSUInteger)maxToSkip
{
    NSUInteger idx=0;
    for (; idx<maxToSkip; idx++)
    {
        unichar character = [self nextCharacter];
        if ([aSet characterIsMember:character])
            [self advance];
        else
            break;
    }
    return idx;
}

- (NSUInteger) skipIndentationUpTo:(NSUInteger)maxSpacesToSkip
{
    NSUInteger skipped = 0;
    [self beginTransaction];
    
    while (![self atEndOfLine] && skipped < maxSpacesToSkip)
    {
        unichar character = [self nextCharacter];
        
        if (character == ' ')
            skipped += 1;
        else if (character == '\t')
        {
            skipped -= skipped % 4;
            skipped += 4;
        }
        else
            break;
        
        [self advance];
    }
    
    [self commitTransaction:skipped <= maxSpacesToSkip];
    return skipped;
}

- (NSUInteger) skipToEndOfLine
{
    NSUInteger length = self.lineRange.length;
    self.location = NSMaxRange(self.lineRange);
    return length;
}


//==================================================================================================
#pragma mark -
#pragma mark Public Properties
//==================================================================================================

- (NSUInteger) location
{
    return self.lineRange.location;
}

- (void) setLocation:(NSUInteger)location
{
    NSUInteger nextLine = [self _locationOfNextLineAfterLocation:location];
    self.lineRange = NSMakeRange(location, (nextLine - 1) - location);
}


//==================================================================================================
#pragma mark -
#pragma mark Private Methods
//==================================================================================================

- (NSUInteger) _locationOfNextLineAfterLocation:(NSUInteger)aLocation
{
    NSRange searchRange  = NSMakeRange(aLocation, self.string.length-aLocation);
    NSRange newlineRange = [self.string rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]
                                                        options:0
                                                            range:searchRange];
    
    if (newlineRange.location == NSNotFound)
    {
        return self.string.length;
    }
    else
    {
        return newlineRange.location + 1;
    }
}


@end
