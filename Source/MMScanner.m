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


static NSString *__delimitersForCharacter(unichar character)
{
    switch (character)
    {
        case '[':
        case ']':
            return @"[]";
        case '(':
        case ')':
            return @"()";
        case '<':
        case '>':
            return @"<>";
        case '{':
        case '}':
            return @"{}";
        default:
            [NSException raise:@"Invalid delimiter character"
                        format:@"Character '%C' is not a valid delimiter", character, nil];
            return '\0';
    }
}

@interface MMScanner ()
@property (assign, nonatomic) NSUInteger startLocation;
@property (assign, nonatomic) NSUInteger lineStartLocation;
@property (assign, nonatomic) NSRange    lineRange;
@property (strong, nonatomic, readonly) NSMutableArray *transactions;

- (NSUInteger) _locationOfNextLineAfterLocation:(NSUInteger)aLocation;
- (NSUInteger) _startLocationOfLineAtLocation:(NSUInteger)aLocation;
@end

@implementation MMScanner

@synthesize string = _string;

@synthesize startLocation     = _startLocation;
@synthesize lineStartLocation = _lineStartLocation;
@synthesize lineRange         = _lineRange;
@synthesize transactions      = _transactions;

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

- (BOOL) atBeginningOfLine
{
    return self.location == self.lineStartLocation;
}

- (BOOL) atEndOfLine
{
    return self.lineRange.length == 0 || [self atEndOfString];
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

- (NSString *) substringBeforeCharacter:(unichar)character
{
    NSUInteger location = [self _locationOfCharacter:character inRange:self.lineRange];
    if (location == NSNotFound)
        return nil;
    
    NSRange   range     = NSMakeRange(self.lineRange.location, location-self.lineRange.location);
    NSString *substring = [self.string substringWithRange:range];
    
    return substring;
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
    if (![self atEndOfString])
    {
        self.location = 1 + NSMaxRange(self.lineRange); // lineRange doesn't include the \n
    }
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

- (NSUInteger) skipNestedBracketsWithDelimiter:(unichar)delimiter
{
    NSString *delimiters     = __delimitersForCharacter(delimiter);
    unichar   openDelimiter  = [delimiters characterAtIndex:0];
    unichar   closeDelimeter = [delimiters characterAtIndex:1];
    
    if ([self nextCharacter] != openDelimiter)
        return 0;
    
    [self beginTransaction];
    NSUInteger location = self.location;
    [self advance];
    
    NSString       *specialChars = [NSString stringWithFormat:@"%@\\", delimiters];
    NSCharacterSet *boringChars  = [[NSCharacterSet characterSetWithCharactersInString:specialChars] invertedSet];
    NSUInteger      nestingLevel = 1;
    
    while (nestingLevel > 0)
    {
        if ([self atEndOfLine])
        {
            [self commitTransaction:NO];
            return 0;
        }
        
        [self skipCharactersFromSet:boringChars];
        
        unichar nextChar = [self nextCharacter];
        [self advance];
        
        if (nextChar == openDelimiter)
        {
            nestingLevel++;
        }
        else if (nextChar == closeDelimeter)
        {
            nestingLevel--;
        }
        else if (nextChar == '\\')
        {
            // skip a second character after a backslash
            [self advance];
        }
    }
    
    [self commitTransaction:YES];
    return self.location - location;
}

- (NSUInteger) skipToEndOfLine
{
    NSUInteger length = self.lineRange.length;
    self.location          = NSMaxRange(self.lineRange);
    self.lineStartLocation = self.location;
    return length;
}

- (NSUInteger) skipToLastCharacterOfLine
{
    NSUInteger length = self.lineRange.length - 1;
    self.location = NSMaxRange(self.lineRange) - 1;
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
    self.lineRange         = NSMakeRange(location, (nextLine - 1) - location);
    self.lineStartLocation = [self _startLocationOfLineAtLocation:location];
}


//==================================================================================================
#pragma mark -
#pragma mark Private Methods
//==================================================================================================

- (NSUInteger) _locationOfCharacter:(unichar)character inRange:(NSRange)range
{
    NSString       *characterString = [NSString stringWithCharacters:&character length:1];
    NSCharacterSet *characterSet    = [NSCharacterSet characterSetWithCharactersInString:characterString];
    NSRange result = [self.string rangeOfCharacterFromSet:characterSet options:0 range:range];
    return result.location;
}

- (NSUInteger) _locationOfNextLineAfterLocation:(NSUInteger)aLocation
{
    NSRange searchRange = NSMakeRange(aLocation, self.string.length-aLocation);
    if (self.string.length < aLocation)
        searchRange = NSMakeRange(self.string.length, 0);
    
    NSRange newlineRange = [self.string rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]
                                                        options:0
                                                          range:searchRange];
    
    if (newlineRange.location == NSNotFound)
    {
        return self.string.length + 1;
    }
    
    return newlineRange.location + 1;
}

- (NSUInteger) _startLocationOfLineAtLocation:(NSUInteger)aLocation
{
    NSRange searchRange = NSMakeRange(0, 1+aLocation);
    if (searchRange.length > self.string.length)
        searchRange.length = self.string.length;
    
    NSRange newlineRange = [self.string rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]
                                                        options:NSBackwardsSearch
                                                          range:searchRange];
    if (newlineRange.location == NSNotFound)
    {
        return 0;
    }
    
    return NSMaxRange(newlineRange);
}


@end
