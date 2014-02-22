//
//  MMSpanParser.m
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

#import "MMSpanParser.h"


#import "MMElement.h"
#import "MMHTMLParser.h"
#import "MMScanner.h"

static NSString * const ESCAPABLE_CHARS = @"\\`*_{}[]()#+-.!>";

@interface MMSpanParser ()
@property (strong, nonatomic) MMHTMLParser *htmlParser;

@property (strong, nonatomic) NSMutableArray *elements;
@property (strong, nonatomic) NSMutableArray *openElements;

@property (assign, nonatomic) BOOL parseLinks;
@end

@implementation MMSpanParser

//==================================================================================================
#pragma mark -
#pragma mark NSObject Methods
//==================================================================================================

- (id)init
{
    self = [super init];
    
    if (self)
    {
        self.htmlParser = [MMHTMLParser new];
        self.parseLinks = YES;
    }
    
    return self;
}


//==================================================================================================
#pragma mark -
#pragma mark Public Methods
//==================================================================================================

- (NSArray *)parseSpansWithScanner:(MMScanner *)scanner
{
    return [self _parseWithScanner:scanner untilTestPasses:^{ return [scanner atEndOfString]; }];
}


//==================================================================================================
#pragma mark -
#pragma mark Private Methods
//==================================================================================================

- (MMElement *)_parseNextElementWithScanner:(MMScanner *)scanner
{
    // 1) Check for a text segment
    
    NSCharacterSet *specialChars = [NSCharacterSet characterSetWithCharactersInString:@"\\`*_<&[! "];
    NSCharacterSet *boringChars  = [specialChars invertedSet];
    NSUInteger skipped = [scanner skipCharactersFromSet:boringChars];
    if (skipped > 0)
    {
        MMElement *text = [MMElement new];
        text.type  = MMElementTypeNone;
        text.range = NSMakeRange(scanner.location-skipped, skipped);
        return text;
    }
    
    // 2) Check for a newline
    if ([scanner atEndOfLine])
    {
        // TODO: Add a line break?
        
        // Add a newline
        MMElement *newline = [MMElement new];
        newline.type  = MMElementTypeNone;
        newline.range = NSMakeRange(0, 0);
        
        [scanner advanceToNextLine];
        
        return newline;
    }
    
    // 3) Check for a span element
    
    MMElement *span = [self _parseSpanWithScanner:scanner];
    if (span)
    {
        return span;
    }
    
    // 4) Check for an entity
    
    MMElement *entity = [self _parseEntityWithScanner:scanner];
    if (entity)
    {
        return entity;
    }
    
    // 5) Check for a backslash
    if ([scanner nextCharacter] == '\\')
    {
        // If the next character isn't one that can be escaped, then let the backslash pass through
        // unchanged. Otherwise, skip the backslash and return the escaped character.
        
        [scanner beginTransaction];
        [scanner advance]; // skip over the backslash
        
        NSCharacterSet *escapedChars = [NSCharacterSet characterSetWithCharactersInString:ESCAPABLE_CHARS];
        if ([escapedChars characterIsMember:[scanner nextCharacter]])
        {
            [scanner commitTransaction:YES];
        }
        else
        {
            [scanner commitTransaction:NO];
        }
        
        // Then fall through to (6) below.
    }
    
    // 6) Otherwise, return the character
    MMElement *character = [MMElement new];
    character.type = MMElementTypeNone;
    character.range = NSMakeRange(scanner.location, 1);
    
    [scanner advance];
    
    return character;
}

- (NSArray *)_parseWithScanner:(MMScanner *)scanner untilTestPasses:(BOOL (^)())test
{
    NSMutableArray *result = [NSMutableArray array];
    
    while (![scanner atEndOfString])
    {
        MMElement *element = [self _parseNextElementWithScanner:scanner];
        if (element)
        {
            [result addObject:element];
        }
        
        // Check for the end character
        [scanner beginTransaction];
        if (test())
        {
            [scanner commitTransaction:YES];
            return result;
        }
        [scanner commitTransaction:NO];
    }
    
    return nil;
}
       
- (MMElement *)_parseSpanWithScanner:(MMScanner *)scanner
{
    MMElement *element;
    
    [scanner beginTransaction];
    element = [self _parseStrongWithScanner:scanner];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    [scanner beginTransaction];
    element = [self _parseEmWithScanner:scanner];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    [scanner beginTransaction];
    element = [self _parseCodeSpanWithScanner:scanner];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    [scanner beginTransaction];
    element = [self _parseLineBreakWithScanner:scanner];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    if (self.parseLinks)
    {
        [scanner beginTransaction];
        element = [self _parseAutomaticLinkWithScanner:scanner];
        [scanner commitTransaction:element != nil];
        if (element)
            return element;
        
        [scanner beginTransaction];
        element = [self _parseAutomaticEmailLinkWithScanner:scanner];
        [scanner commitTransaction:element != nil];
        if (element)
            return element;
        
        [scanner beginTransaction];
        element = [self _parseImageWithScanner:scanner];
        [scanner commitTransaction:element != nil];
        if (element)
            return element;
        
        [scanner beginTransaction];
        element = [self _parseLinkWithScanner:scanner];
        [scanner commitTransaction:element != nil];
        if (element)
            return element;
    }
    
    [scanner beginTransaction];
    element = [self.htmlParser parseInlineTagWithScanner:scanner];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    [scanner beginTransaction];
    element = [self.htmlParser parseCommentWithScanner:scanner];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    return nil;
}

- (MMElement *)_parseStrongWithScanner:(MMScanner *)scanner
{
    // Must have 2 *s or _s
    unichar character = [scanner nextCharacter];
    if (!(character == '*' || character == '_'))
        return nil;
    
    for (NSUInteger idx=0; idx<2; idx++)
    {
        if ([scanner nextCharacter] != character)
            return nil;
        [scanner advance];
    }
    
    NSCharacterSet  *whitespaceSet = [NSCharacterSet whitespaceCharacterSet];
    NSArray         *children      = [self _parseWithScanner:scanner untilTestPasses:^{
        // Can't be at the beginning of the line
        if ([scanner atBeginningOfLine])
            return NO;
        
        // Must follow the end of a word
        if ([whitespaceSet characterIsMember:[scanner previousCharacter]])
            return NO;
        
        // Must have 2 *s or _s
        for (NSUInteger idx=0; idx<2; idx++)
        {
            if ([scanner nextCharacter] != character)
                return NO;
            [scanner advance];
        }
        
        return YES;
    }];
    
    if (!children)
        return nil;
    
    MMElement *element = [MMElement new];
    element.type     = MMElementTypeStrong;
    element.range    = NSMakeRange(scanner.startLocation, scanner.location-scanner.startLocation);
    element.children = children;
    
    return element;
}

- (MMElement *)_parseEmWithScanner:(MMScanner *)scanner
{
    // Must have 1 * or _
    unichar character = [scanner nextCharacter];
    if (!(character == '*' || character == '_'))
        return nil;
    [scanner advance];
    
    // Can't be at the end of a line or before a space
    if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[scanner nextCharacter]])
        return nil;
    
    NSCharacterSet  *whitespaceSet = [NSCharacterSet whitespaceCharacterSet];
    NSArray         *children      = [self _parseWithScanner:scanner untilTestPasses:^{
        // Can't be at the beginning of the line
        if ([scanner atBeginningOfLine])
            return NO;
        
        // Must follow the end of a word
        if ([whitespaceSet characterIsMember:[scanner previousCharacter]])
            return NO;
        
        // Must have a * or _
        if ([scanner nextCharacter] != character)
            return NO;
        [scanner advance];
        
        return YES;
    }];
    
    if (!children)
        return nil;
    
    MMElement *element = [MMElement new];
    element.type      = MMElementTypeEm;
    element.range     = NSMakeRange(scanner.startLocation, scanner.location-scanner.startLocation);
    element.children  = children;
    
    return element;
    
}

- (MMElement *)_parseCodeSpanWithScanner:(MMScanner *)scanner
{
    if ([scanner nextCharacter] != '`')
        return nil;
    [scanner advance];
    
    MMElement *element = [MMElement new];
    element.type = MMElementTypeCodeSpan;
    
    // Check for more `s
    NSUInteger level = 1;
    while ([scanner nextCharacter] == '`')
    {
        level++;
        [scanner advance];
    }
    
    // skip leading whitespace
    [scanner skipCharactersFromSet:[NSCharacterSet whitespaceCharacterSet]];
    
    // Skip to the next '`'
    NSCharacterSet *boringChars  = [[NSCharacterSet characterSetWithCharactersInString:@"`&<>"] invertedSet];
    NSUInteger      textLocation = scanner.location;
    while (1)
    {
        if ([scanner atEndOfString])
            return nil;
        
        // Skip other characters
        [scanner skipCharactersFromSet:boringChars];
        
        // Add the code as text
        if (textLocation != scanner.location)
        {
            MMElement *text = [MMElement new];
            text.type  = MMElementTypeNone;
            text.range = NSMakeRange(textLocation, scanner.location-textLocation);
            [element addChild:text];
        }
        
        // Check for closing `s
        if ([scanner nextCharacter] == '`')
        {
            // Set the text location to catch the ` in case it isn't the closing `s
            textLocation = scanner.location;
            
            NSUInteger idx;
            for (idx=0; idx<level; idx++)
            {
                if ([scanner nextCharacter] != '`')
                    break;
                [scanner advance];
            }
            if (idx >= level)
                break;
            else
                continue;
        }
        
        unichar nextChar = [scanner nextCharacter];
        // Check for entities
        if (nextChar == '&')
        {
            MMElement *entity = [MMElement new];
            entity.type  = MMElementTypeEntity;
            entity.range = NSMakeRange(scanner.location, 1);
            entity.stringValue = @"&amp;";
            [element addChild:entity];
            [scanner advance];
        }
        else if (nextChar == '<')
        {
            MMElement *entity = [MMElement new];
            entity.type  = MMElementTypeEntity;
            entity.range = NSMakeRange(scanner.location, 1);
            entity.stringValue = @"&lt;";
            [element addChild:entity];
            [scanner advance];
        }
        else if (nextChar == '>')
        {
            MMElement *entity = [MMElement new];
            entity.type  = MMElementTypeEntity;
            entity.range = NSMakeRange(scanner.location, 1);
            entity.stringValue = @"&gt;";
            [element addChild:entity];
            [scanner advance];
        }
        // Or did we hit the end of the line?
        else if ([scanner atEndOfLine])
        {
            textLocation = scanner.location;
            [scanner advanceToNextLine];
            continue;
        }
        
        textLocation = scanner.location;
    }
    
    // remove trailing whitespace
    if (element.children.count > 0)
    {
        MMElement *lastText = element.children.lastObject;
        unichar lastCharacter = [scanner.string characterAtIndex:NSMaxRange(lastText.range)-1];
        while ([[NSCharacterSet whitespaceCharacterSet] characterIsMember:lastCharacter])
        {
            NSRange range = lastText.range;
            range.length -= 1;
            lastText.range = range;
            
            lastCharacter = [scanner.string characterAtIndex:NSMaxRange(lastText.range)-1];
        }
    }
    
    element.range = NSMakeRange(scanner.startLocation, scanner.location-scanner.startLocation);
    
    return element;
}

- (MMElement *)_parseLineBreakWithScanner:(MMScanner *)scanner
{
    // A line break is made up of 2 spaces. Since 1 is left on the line, match it against the
    // previous character instead of the next one.
    if ([scanner previousCharacter] != ' ')
        return nil;
    if ([scanner nextCharacter] != ' ')
        return nil;
    
    [scanner advance];
    while ([scanner nextCharacter] == ' ')
    {
        [scanner advance];
    }
    
    if (![scanner atEndOfLine])
        return nil;
    
    // Don't ever add a line break to the last line
    if ([scanner atEndOfString])
        return nil;
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeLineBreak;
    element.range = NSMakeRange(scanner.location, scanner.location-scanner.startLocation);
    
    return element;
}

- (MMElement *)_parseAutomaticLinkWithScanner:(MMScanner *)scanner
{
    // Leading <
    if ([scanner nextCharacter] != '<')
        return nil;
    [scanner advance];
    
    NSUInteger textLocation = scanner.location;
    
    // Find the trailing >
    [scanner skipCharactersFromSet:[[NSCharacterSet characterSetWithCharactersInString:@">"] invertedSet]];
    if ([scanner atEndOfLine])
        return nil;
    [scanner advance];
    
    NSRange   linkRange = NSMakeRange(textLocation, (scanner.location-1)-textLocation);
    NSString *linkText  = [scanner.string substringWithRange:linkRange];
    
    // Make sure it looks like a link
    NSRegularExpression *regex;
    NSRange matchRange;
    regex      = [NSRegularExpression regularExpressionWithPattern:@"^(\\w+)://" options:0 error:nil];
    matchRange = [regex rangeOfFirstMatchInString:linkText options:0 range:NSMakeRange(0, linkText.length)];
    if (matchRange.location == NSNotFound)
        return nil;
    NSURL *url = [NSURL URLWithString:linkText];
    if (!url)
        return nil;
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeLink;
    element.range = NSMakeRange(scanner.startLocation, scanner.location-scanner.startLocation);
    element.href  = linkText;
    
    // Do the text the hard way to take care of ampersands
    NSRange textRange = NSMakeRange(textLocation, NSMaxRange(linkRange)-textLocation);
    NSCharacterSet *ampersands = [NSCharacterSet characterSetWithCharactersInString:@"&"];
    while (textRange.length > 0)
    {
        NSRange result = [scanner.string rangeOfCharacterFromSet:ampersands
                                                         options:0
                                                           range:textRange];
        
        if (result.location != NSNotFound)
        {
            if (textRange.location != result.location)
            {
                MMElement *text = [MMElement new];
                text.type  = MMElementTypeNone;
                text.range = NSMakeRange(textRange.location, result.location-textRange.location);
                [element addChild:text];
            }
            
            MMElement *ampersand = [MMElement new];
            ampersand.type  = MMElementTypeEntity;
            ampersand.range = NSMakeRange(textRange.location, 1);
            ampersand.stringValue = @"&amp;";
            [element addChild:ampersand];
            
            textRange = NSMakeRange(result.location+1, NSMaxRange(textRange)-(result.location+1));
        }
        else
        {
            if (textRange.length > 0)
            {
                MMElement *text = [MMElement new];
                text.type  = MMElementTypeNone;
                text.range = textRange;
                [element addChild:text];
            }
            break;
        }
    }
    
    return element;
}

- (MMElement *)_parseAutomaticEmailLinkWithScanner:(MMScanner *)scanner
{
    // Leading <
    if ([scanner nextCharacter] != '<')
        return nil;
    [scanner advance];
    
    NSUInteger textLocation = scanner.location;
    
    // Find the trailing >
    [scanner skipCharactersFromSet:[[NSCharacterSet characterSetWithCharactersInString:@">"] invertedSet]];
    if ([scanner atEndOfLine])
        return nil;
    [scanner advance];
    
    NSRange   linkRange = NSMakeRange(textLocation, (scanner.location-1)-textLocation);
    NSString *linkText  = [scanner.string substringWithRange:linkRange];
    
    // Make sure it looks like a link
    NSRegularExpression *regex;
    NSRange matchRange;
    regex      = [NSRegularExpression regularExpressionWithPattern:@"^[-._0-9\\p{L}]+@[-\\p{L}0-9][-.\\p{L}0-9]*\\.\\p{L}+$"
                                                           options:NSRegularExpressionCaseInsensitive
                                                             error:nil];
    matchRange = [regex rangeOfFirstMatchInString:linkText options:0 range:NSMakeRange(0, linkText.length)];
    if (matchRange.location == NSNotFound)
        return nil;
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeMailTo;
    element.range = NSMakeRange(scanner.startLocation, scanner.location-scanner.startLocation);
    element.href  = linkText;
    
    return element;
}

- (NSArray *)_parseLinkTextBodyWithScanner:(MMScanner *)scanner
{
    NSMutableArray *ranges  = [NSMutableArray new];
    NSCharacterSet *boringChars;
    NSUInteger      level;
    
    if ([scanner nextCharacter] != '[')
        return nil;
    [scanner advance];
    
    boringChars = [[NSCharacterSet characterSetWithCharactersInString:@"[]\\"] invertedSet];
    level       = 1;
    NSRange textRange = scanner.currentRange;
    while (level > 0)
    {
        if ([scanner atEndOfString])
            return nil;
        
        if ([scanner atEndOfLine])
        {
            if (textRange.length > 0)
            {
                [ranges addObject:[NSValue valueWithRange:textRange]];
            }
            [scanner advanceToNextLine];
            textRange = scanner.currentRange;
        }
        
        [scanner skipCharactersFromSet:boringChars];
        
        unichar character = [scanner nextCharacter];
        if (character == '[')
        {
            level += 1;
        }
        else if (character == ']')
        {
            level -= 1;
        }
        else if (character == '\\')
        {
            [scanner advance];
        }
        
        textRange.length = scanner.location - textRange.location;
        [scanner advance];
    }
    
    if (textRange.length > 0)
    {
        [ranges addObject:[NSValue valueWithRange:textRange]];
    }
    
    return ranges;
}

- (MMElement *)_parseInlineLinkWithScanner:(MMScanner *)scanner
{
    NSCharacterSet *boringChars;
    NSUInteger      level;
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeLink;
    
    // Find the []
    element.innerRanges = [self _parseLinkTextBodyWithScanner:scanner];
    if (!element.innerRanges)
        return nil;
    
    // Find the ()
    if ([scanner nextCharacter] != '(')
        return nil;
    [scanner advance];
    
    NSUInteger      urlLocation = scanner.location;
    NSUInteger      urlEnd      = urlLocation;
    boringChars = [[NSCharacterSet characterSetWithCharactersInString:@"()\\ \t"] invertedSet];
    level       = 1;
    while (level > 0)
    {
        [scanner skipCharactersFromSet:boringChars];
        if ([scanner atEndOfLine])
            return nil;
        urlEnd = scanner.location;
        
        unichar character = [scanner nextCharacter];
        if (character == '(')
        {
            level += 1;
        }
        else if (character == ')')
        {
            level -= 1;
        }
        else if (character == '\\')
        {
            [scanner advance]; // skip over the backslash
            // skip over the next character below
        }
        else if ([[NSCharacterSet whitespaceCharacterSet] characterIsMember:character])
        {
            if (level != 1)
                return nil;
            break;
        }
        urlEnd = scanner.location;
        [scanner advance];
    }
    
    NSUInteger titleLocation = NSNotFound;
    NSUInteger titleEnd      = NSNotFound;
    
    // If the level is still 1, then we hit a space.
    if (level == 1)
    {
        // skip the whitespace
        [scanner skipCharactersFromSet:[NSCharacterSet whitespaceCharacterSet]];
        
        // make sure there's a "
        if ([scanner nextCharacter] != '"')
            return nil;
        [scanner advance];
        
        titleLocation = scanner.location;
        boringChars   = [[NSCharacterSet characterSetWithCharactersInString:@"\""] invertedSet];
        while (1)
        {
            [scanner skipCharactersFromSet:boringChars];
            
            if ([scanner atEndOfLine])
                return nil;
            
            [scanner advance];
            if ([scanner nextCharacter] == ')')
            {
                titleEnd = scanner.location - 1;
                [scanner advance];
                break;
            }
        }
    }
    
    NSRange   urlRange = NSMakeRange(urlLocation, urlEnd-urlLocation);
    NSString *href     = [scanner.string substringWithRange:urlRange];
    
    // If the URL is surrounded by angle brackets, ditch them
    if ([href hasPrefix:@"<"] && [href hasSuffix:@">"])
    {
        href = [href substringWithRange:NSMakeRange(1, href.length-2)];
    }
    
    element.range = NSMakeRange(scanner.startLocation, scanner.location-scanner.startLocation);
    element.href  = [self _stringWithBackslashEscapesRemoved:href];
    
    if (titleLocation != NSNotFound)
    {
        NSRange titleRange = NSMakeRange(titleLocation, titleEnd-titleLocation);
        element.title = [scanner.string substringWithRange:titleRange];
    }
    
    return element;
}

- (MMElement *)_parseReferenceLinkWithScanner:(MMScanner *)scanner
{
    MMElement *element = [MMElement new];
    element.type = MMElementTypeLink;
    
    // Find the []
    element.innerRanges = [self _parseLinkTextBodyWithScanner:scanner];
    if (!element.innerRanges.count)
        return nil;
    
    // Skip optional whitespace
    if ([scanner nextCharacter] == ' ')
        [scanner advance];
    // or possible newline
    else if ([scanner atEndOfLine])
        [scanner advanceToNextLine];
    
    // Look for the second []
    NSArray *idRanges = [self _parseLinkTextBodyWithScanner:scanner];
    if (!idRanges.count)
    {
        idRanges = element.innerRanges;
    }

    NSMutableString *idString = [NSMutableString new];
    for (NSValue *value in idRanges)
    {
        NSRange range = [value rangeValue];
        [idString appendString:[scanner.string substringWithRange:range]];
        [idString appendString:@" "]; // newlines are replaced by spaces for the id
    }
    // Delete the last space
    [idString deleteCharactersInRange:NSMakeRange(idString.length-1, 1)];
    
    element.range = NSMakeRange(scanner.startLocation, scanner.location-scanner.startLocation);
    element.identifier = idString;
    
    return element;
}

- (MMElement *)_parseLinkWithScanner:(MMScanner *)scanner
{
    MMElement *element;
    
    element = [self _parseInlineLinkWithScanner:scanner];
    
    if (element == nil)
    {
        // Assume that this method will already be wrapped in a transaction
        [scanner commitTransaction:NO];
        [scanner beginTransaction];
        element = [self _parseReferenceLinkWithScanner:scanner];
    }
    
    if (element != nil)
    {
        self.parseLinks = NO;
        MMScanner *innerScanner = [MMScanner scannerWithString:scanner.string lineRanges:element.innerRanges];
        element.children = [self _parseWithScanner:innerScanner untilTestPasses:^{ return [innerScanner atEndOfString]; }];
        self.parseLinks = YES;
    }
    
    return element;
}

- (MMElement *)_parseImageWithScanner:(MMScanner *)scanner
{
    MMElement *element;
    
    // An image starts with a !, but then is a link
    if ([scanner nextCharacter] != '!')
        return nil;
    [scanner advance];
    
    // Add a transaction to protect the ! that was scanned
    [scanner beginTransaction];
    
    element = [self _parseInlineLinkWithScanner:scanner];
    
    if (element == nil)
    {
        // Assume that this method will already be wrapped in a transaction
        [scanner commitTransaction:NO];
        [scanner beginTransaction];
        element = [self _parseReferenceLinkWithScanner:scanner];
    }
    
    [scanner commitTransaction:YES];
    
    if (element != nil)
    {
        element.type = MMElementTypeImage;
        
        NSMutableString *altText = [NSMutableString new];
        for (NSValue *value in element.innerRanges)
        {
            NSRange range = [value rangeValue];
            [altText appendString:[scanner.string substringWithRange:range]];
        }
        element.stringValue = altText;
    }
    
    return element;
}

- (MMElement *)_parseAmpersandWithScanner:(MMScanner *)scanner
{
    if ([scanner nextCharacter] != '&')
        return nil;
    [scanner advance];
    
    // check if this is an html entity
    [scanner beginTransaction];
    
    if ([scanner nextCharacter] == '#')
        [scanner advance];
    [scanner skipCharactersFromSet:[NSCharacterSet alphanumericCharacterSet]];
    if ([scanner nextCharacter] == ';')
    {
        [scanner commitTransaction:NO];
        return nil;
    }
    [scanner commitTransaction:NO];
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeEntity;
    element.range = NSMakeRange(scanner.location-1, 1);
    element.stringValue = @"&amp;";
    
    return element;
}

- (MMElement *)_parseLeftAngleBracketWithScanner:(MMScanner *)scanner
{
    if ([scanner nextCharacter] != '<')
        return nil;
    [scanner advance];
    
    // Can't be followed by a letter, /, ?, $, or !
    unichar nextChar = [scanner nextCharacter];
    if ([[NSCharacterSet letterCharacterSet] characterIsMember:nextChar])
        return nil;
    if ([[NSCharacterSet characterSetWithCharactersInString:@"/?$!"] characterIsMember:nextChar])
        return nil;
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeEntity;
    element.range = NSMakeRange(scanner.location-1, 1);
    element.stringValue = @"&lt;";
    
    return element;
}

- (MMElement *)_parseEntityWithScanner:(MMScanner *)scanner
{
    MMElement *element;
    
    [scanner beginTransaction];
    element = [self _parseAmpersandWithScanner:scanner];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    [scanner beginTransaction];
    element = [self _parseLeftAngleBracketWithScanner:scanner];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    return nil;
}

- (NSString *)_stringWithBackslashEscapesRemoved:(NSString *)string
{
    NSMutableString *result = [string mutableCopy];
    
    NSCharacterSet *escapableChars = [NSCharacterSet characterSetWithCharactersInString:ESCAPABLE_CHARS];
    
    NSRange searchRange = NSMakeRange(0, result.length);
    while (searchRange.length > 0)
    {
        NSRange range = [result rangeOfString:@"\\" options:0 range:searchRange];
        
        if (range.location == NSNotFound || NSMaxRange(range) == NSMaxRange(searchRange))
            break;
        
        // If it is escapable, than remove the backslash
        unichar nextChar = [result characterAtIndex:range.location + 1];
        if ([escapableChars characterIsMember:nextChar])
        {
            [result replaceCharactersInRange:range withString:@""];
        }
        
        searchRange.location = range.location + 1;
        searchRange.length   = result.length - searchRange.location;
    }
    
    return result;
}


@end
