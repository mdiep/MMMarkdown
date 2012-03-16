//
//  MMSpanScanner.m
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

#import "MMSpanScanner.h"


@interface MMSpanScanner ()
@property (assign, nonatomic, readonly) NSRange currentLineRange;
@property (assign, nonatomic) NSUInteger rangeIndex;
@property (strong, nonatomic, readonly) NSMutableArray *transactions;
@end

@implementation MMSpanScanner

@synthesize string     = _string;
@synthesize lineRanges = _lineRanges;

@synthesize location = _location;

@synthesize rangeIndex   = _rangeIndex;
@synthesize transactions = _transactions;

//==================================================================================================
#pragma mark -
#pragma mark Public Methods
//==================================================================================================

+ (id) scannerWithString:(NSString *)aString lineRanges:(NSArray *)theLineRanges
{
    return [[[self class] alloc] initWithString:aString lineRanges:theLineRanges];
}

- (id) initWithString:(NSString *)aString lineRanges:(NSArray *)theLineRanges
{
    NSParameterAssert(theLineRanges.count > 0);
    
    self = [super init];
    
    if (self)
    {
        _string     = aString;
        _lineRanges = theLineRanges;
        
        NSValue *value = [theLineRanges objectAtIndex:0];
        _location = [value rangeValue].location;
        
        _rangeIndex   = 0;
        _transactions = [NSMutableArray new];
    }
    
    return self;
}

- (void) beginTransaction
{
    // Cheat and use a range to hold 2 NSUIntegers, even though they're not a range.
    NSRange range = NSMakeRange(self.rangeIndex, self.location);
    [self.transactions addObject:[NSValue valueWithRange:range]];
}

- (void) commitTransaction:(BOOL)shouldSave
{
    if (!self.transactions.count)
        [NSException raise:@"Transaction underflow" format:@"Could not commit transaction because the stack is empty"];
    
    NSValue *value = [self.transactions lastObject];
    [self.transactions removeLastObject];
    
    if (!shouldSave)
    {
        // See note about the range in -beginTransaction
        NSRange range = [value rangeValue];
        self.rangeIndex = range.location;
        self.location   = range.length;
    }
}

- (BOOL) atBeginningOfLine
{
    return self.location == self.currentLineRange.location;
}

- (BOOL) atEndOfLine
{
    return self.location == NSMaxRange(self.currentLineRange);
}

- (BOOL) atEndOfString
{
    return [self atEndOfLine] && self.rangeIndex == self.lineRanges.count - 1;
}

- (unichar) previousCharacter
{
    if ([self atBeginningOfLine])
        return '\0';
    
    return [self.string characterAtIndex:self.location - 1];
}

- (unichar) nextCharacter
{
    if ([self atEndOfLine])
        return '\n';
    return [self.string characterAtIndex:self.location];
}

- (void) advance
{
    if ([self atEndOfLine])
        return;
    self.location += 1;
}

- (void) advanceToNextLine
{
    // If at the last line, just go to the end of the line
    if (self.rangeIndex == self.lineRanges.count - 1)
    {
        self.location = NSMaxRange(self.currentLineRange);
    }
    // Otherwise actually go to the next line
    else
    {
        self.rangeIndex += 1;
        self.location = self.currentLineRange.location;
    }
    
}

- (NSUInteger) skipCharactersFromSet:(NSCharacterSet *)aSet
{
    NSRange lineRange   = self.currentLineRange;
    NSRange searchRange = NSMakeRange(self.location, NSMaxRange(lineRange)-self.location);
    
    NSRange range = [self.string rangeOfCharacterFromSet:[aSet invertedSet]
                                                 options:0
                                                   range:searchRange];
    
    NSUInteger current = self.location;
    if (range.location == NSNotFound)
        self.location = NSMaxRange(searchRange);
    else
        self.location = range.location;
    return self.location - current;
}


//==================================================================================================
#pragma mark -
#pragma mark Private Properties
//==================================================================================================

- (NSRange) currentLineRange
{
    return [[self.lineRanges objectAtIndex:self.rangeIndex] rangeValue];
}


@end
