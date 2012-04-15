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
#import "MMSpanScanner.h"
#import "MMTextSegment.h"

@interface MMSpanParser ()
@property (strong, nonatomic) MMSpanScanner  *scanner;
@property (strong, nonatomic) NSMutableArray *elements;
@property (strong, nonatomic) NSMutableArray *openElements;

@property (assign, nonatomic) BOOL parseLinks;
- (NSArray *) _parseRange:(NSRange)aRange ofString:(NSString *)aString;
@end

@implementation MMSpanParser

@synthesize scanner      = _scanner;
@synthesize elements     = _elements;
@synthesize openElements = _openElements;

@synthesize parseLinks = _parseLinks;

//==================================================================================================
#pragma mark -
#pragma mark NSObject Methods
//==================================================================================================

- (id) init
{
    self = [super init];
    
    if (self)
    {
        self.parseLinks = YES;
    }
    
    return self;
}


//==================================================================================================
#pragma mark -
#pragma mark Public Methods
//==================================================================================================

- (NSArray *) parseTextSegment:(MMTextSegment *)aTextSegment
{
    self.scanner      = [MMSpanScanner scannerWithString:aTextSegment.string lineRanges:aTextSegment.ranges];
    self.elements     = [NSMutableArray array];
    self.openElements = [NSMutableArray array];
    
    MMSpanScanner *scanner = self.scanner;
    
    while (1)
    {
        while (![scanner atEndOfString])
        {
            [self _parseNextLine];
            [scanner advanceToNextLine];
        }
        
        // Backtrack if there are any open elements
        if (self.openElements.count)
        {
            // Remove the open elements
            MMElement *bottomElement = [self.openElements objectAtIndex:0];
            [self.elements removeObjectIdenticalTo:bottomElement];
            [self.openElements removeAllObjects];
            
            // Reset the location of the scanner
            self.scanner.location = bottomElement.range.location + 1;
            
            // Add a text element for the skipped character
            MMElement *text = [MMElement new];
            text.type  = MMElementTypeNone;
            text.range = NSMakeRange(bottomElement.range.location, 1);
            [self.elements addObject:text];
        }
        else
            break;
    }
    
    NSArray *elements = self.elements;
    self.scanner      = nil;
    self.elements     = nil;
    self.openElements = nil;
    return elements;
}


//==================================================================================================
#pragma mark -
#pragma mark Private Methods
//==================================================================================================

- (NSArray *) _parseRange:(NSRange)aRange ofString:(NSString *)aString
{
    // Save the state
    MMSpanScanner  *scanner      = self.scanner;
    NSMutableArray *elements     = self.elements;
    NSMutableArray *openElements = self.openElements;
    
    NSArray *lineRanges = [NSArray arrayWithObject:[NSValue valueWithRange:aRange]];
    self.scanner      = [MMSpanScanner scannerWithString:aString lineRanges:lineRanges];
    self.elements     = [NSMutableArray new];
    self.openElements = [NSMutableArray new];
    
    [self _parseNextLine];
    
    NSArray *result = self.elements;
    // Restore the state
    self.scanner      = scanner;
    self.elements     = elements;
    self.openElements = openElements;
    return result;
}

- (void) _parseNextLine
{
    MMSpanScanner *scanner = self.scanner;
    
    NSCharacterSet *specialChars = [NSCharacterSet characterSetWithCharactersInString:@"\\`*_<&["];
    NSCharacterSet *boringChars  = [specialChars invertedSet];
    
    NSUInteger textLocation = scanner.location;
    while (![scanner atEndOfLine])
    {
        // Skip boring characters
        [scanner skipCharactersFromSet:boringChars];
        
        // Check for a backslash
        if ([scanner nextCharacter] == '\\')
        {
            [self _addTextFromLocation:textLocation toLocation:scanner.location];
            [scanner advance]; // skip over the backslash
            textLocation = scanner.location;
            [scanner advance]; // skip over the escaped character
            continue;
        }
        
        // Try to end open elements
        NSUInteger  endLocation    = scanner.location;
        MMElement  *elementToClose = [self _checkOpenElements];
        if (elementToClose)
        {
            [self _addTextFromLocation:textLocation toLocation:endLocation];
            [self _closeElement:elementToClose];
            textLocation = scanner.location;
            continue;
        }
        
        // Try to start new elements
        NSUInteger  startLocation = scanner.location;
        MMElement  *elementToAdd  = [self _startNewElement];
        if (elementToAdd)
        {
            [self _addTextFromLocation:textLocation toLocation:startLocation];
            [self _addElement:elementToAdd];
            textLocation = scanner.location;
            continue;
        }
        
        // Add any escaped entites
        MMElement *newEntity = [self _newEscapedEntity];
        if (newEntity)
        {
            [self _addTextFromLocation:textLocation toLocation:newEntity.range.location];
            [self _addElement:newEntity];
            [self _closeElement:newEntity];
            textLocation = scanner.location;
            continue;
        }
        
        // Otherwise, advance
        [scanner advance];
    }
    
    // Add the final text
    [self _addTextFromLocation:textLocation toLocation:scanner.location];
    
    // Add a newline -- unless this is the last line
    if (![scanner atEndOfString])
    {
        MMElement *element = [MMElement new];
        element.type  = MMElementTypeNone;
        element.range = NSMakeRange(0, 0);
        
        MMElement *topElement = self.openElements.lastObject;
        if (topElement)
            [topElement addChild:element];
        else
            [self.elements addObject:element];
    }
}

- (void) _addTextFromLocation:(NSUInteger)startLocation toLocation:(NSUInteger)endLocation
{
    [self _addTextFromLocation:startLocation toLocation:endLocation toElement:self.openElements.lastObject];
}

- (void) _addTextFromLocation:(NSUInteger)startLocation toLocation:(NSUInteger)endLocation toElement:(MMElement *)toElement
{
    // Don't add empty text
    if (startLocation == endLocation)
        return;
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeNone;
    element.range = NSMakeRange(startLocation, endLocation-startLocation);
    
    if (toElement)
        [toElement addChild:element];
    else
        [self.elements addObject:element];
}

- (void) _closeElement:(MMElement *)anElement
{
    // Get rid of any elements that aren't closed.
    NSMutableArray *openElements = self.openElements;
    MMElement *element = [openElements lastObject];
    while (element && element != anElement)
    {
        if (element.parent)
            [element.parent removeChild:element];
        else
            [self.elements removeObjectIdenticalTo:element];
        
        [openElements removeLastObject];
        element = [openElements lastObject];
    }
    
    // Remove the actual element
    [openElements removeLastObject];
}

- (BOOL) _canCloseStrong:(MMElement *)anElement
{
    MMSpanScanner *scanner = self.scanner;
    
    // Can't be at the beginning of the line
    if ([scanner atBeginningOfLine])
        return NO;
    
    // Must follow the end of a word
    NSCharacterSet *wordSet = [[NSCharacterSet whitespaceCharacterSet] invertedSet];
    if (![wordSet characterIsMember:[scanner previousCharacter]])
        return NO;
    
    // Must have 2 *s or _s
    for (NSUInteger idx=0; idx<2; idx++)
    {
        if ([scanner nextCharacter] != anElement.character)
            return NO;
        [scanner advance];
    }
    
    return YES;
}

- (BOOL) _canCloseEm:(MMElement *)anElement
{
    MMSpanScanner *scanner = self.scanner;
    
    // Can't be at the beginning of the line
    if ([scanner atBeginningOfLine])
        return NO;
    
    // Must follow the end of a word
    NSCharacterSet *wordSet = [[NSCharacterSet whitespaceCharacterSet] invertedSet];
    if (![wordSet characterIsMember:[scanner previousCharacter]])
        return NO;
    
    // Must have a * or _
    if ([scanner nextCharacter] != anElement.character)
        return NO;
    [scanner advance];
    
    return YES;
}

- (BOOL) _canCloseCodeSpan:(MMElement *)anElement
{
    MMSpanScanner *scanner = self.scanner;
    
    for (NSUInteger idx=0; idx<anElement.level; idx++)
    {
        if ([scanner nextCharacter] != '`')
            return NO;
        [scanner advance];
    }
    
    return YES;
}

- (BOOL) _canCloseElement:(MMElement *)anElement
{
    switch (anElement.type)
    {
        case MMElementTypeStrong:
            return [self _canCloseStrong:anElement];
        case MMElementTypeEm:
            return [self _canCloseEm:anElement];
        case MMElementTypeCodeSpan:
            return [self _canCloseCodeSpan:anElement];
        default:
            return YES;
    }
}

- (MMElement *) _checkOpenElements
{
    MMSpanScanner *scanner = self.scanner;
    
    for (MMElement *element in [self.openElements reverseObjectEnumerator])
    {
        [scanner beginTransaction];
        BOOL canClose = [self _canCloseElement:element];
        [scanner commitTransaction:canClose];
        if (canClose)
            return element;
    }
    
    return nil;
}

- (void) _addElement:(MMElement *)anElement
{
    // Add the element to the structure
    MMElement *topElement = self.openElements.lastObject;
    if (topElement)
        [topElement addChild:anElement];
    else
        [self.elements addObject:anElement];
    
    // Add it to the open elements
    if (anElement.range.length == 0)
    {
        [self.openElements addObject:anElement];
    }
}

- (MMElement *) _startAutomaticLink
{
    MMSpanScanner *scanner  = self.scanner;
    NSUInteger     startLoc = scanner.location;
    
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
    NSURL *url = [NSURL URLWithString:linkText];
    if (!url)
        return nil;
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeLink;
    element.range = NSMakeRange(startLoc, scanner.location-startLoc);
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
            [self _addTextFromLocation:textRange.location toLocation:result.location toElement:element];
            
            MMElement *ampersand = [MMElement new];
            ampersand.type  = MMElementTypeEntity;
            ampersand.range = NSMakeRange(textRange.location, 1);
            ampersand.stringValue = @"&amp;";
            [element addChild:ampersand];
            
            textRange = NSMakeRange(result.location+1, NSMaxRange(textRange)-(result.location+1));
        }
        else
        {
            [self _addTextFromLocation:textRange.location toLocation:NSMaxRange(textRange) toElement:element];
            break;
        }
    }
    
    return element;
}

- (MMElement *) _startCodeSpan
{
    MMSpanScanner *scanner  = self.scanner;
    NSUInteger     startLoc = scanner.location;
    
    if ([scanner nextCharacter] != '`')
        return nil;
    [scanner advance];
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeCodeSpan;
    element.range = NSMakeRange(startLoc, 0);
    element.level = 1;
    
    // Check for a 2nd `
    if ([scanner nextCharacter] == '`')
    {
        element.level = 2;
        [scanner advance];
    }
    
    // skip leading whitespace
    [scanner skipCharactersFromSet:[NSCharacterSet whitespaceCharacterSet]];
    
    // Skip to the next '`'
    NSCharacterSet *boringChars  = [[NSCharacterSet characterSetWithCharactersInString:@"`&<>"] invertedSet];
    NSUInteger      textLocation = scanner.location;
    while (![scanner atEndOfString])
    {
        // Skip other characters
        [scanner skipCharactersFromSet:boringChars];
        
        // Add the code as text
        [self _addTextFromLocation:textLocation toLocation:scanner.location toElement:element];
        
        unichar nextChar = [scanner nextCharacter];
        // Did we find the closing `?
        if (nextChar == '`')
        {
            if (element.level == 2)
            {
                // set the location for if this isn't the 2nd backtick--because if it is,
                // the location doesn't matter
                textLocation = scanner.location;
                
                [scanner beginTransaction];
                [scanner advance];
                if ([scanner nextCharacter] == '`')
                    [scanner commitTransaction:NO];
                else
                {
                    [scanner commitTransaction:YES];
                    continue;
                }
            }
            break;
        }
        // Or is it an entity
        else if (nextChar == '&')
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
            [scanner advanceToNextLine];
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
    
    return element;
}

- (MMElement *) _startInlineLink
{
    MMSpanScanner *scanner  = self.scanner;
    NSUInteger     startLoc = scanner.location;
    NSUInteger     length;
    
    // Find the []
    length = [scanner skipNestedBracketsWithDelimiter:'['];
    if (length == 0)
        return nil;
    
    NSRange textRange = NSMakeRange(startLoc+1, length-2);
    
    // Find the ()
    if ([scanner nextCharacter] != '(')
        return nil;
    [scanner advance];
    
    NSCharacterSet *boringChars = [[NSCharacterSet characterSetWithCharactersInString:@"() \t"] invertedSet];
    NSUInteger      urlLocation = scanner.location;
    NSUInteger      urlEnd      = urlLocation;
    NSUInteger      level       = 1;
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
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeLink;
    element.range = NSMakeRange(startLoc, scanner.location-startLoc);
    element.href  = href;
    
    if (titleLocation != NSNotFound)
    {
        NSRange titleRange = NSMakeRange(titleLocation, titleEnd-titleLocation);
        element.stringValue = [scanner.string substringWithRange:titleRange];
    }
    
    self.parseLinks = NO;
    NSArray *innerElements = [self _parseRange:textRange ofString:scanner.string];
    for (MMElement *inner in innerElements)
    {
        [element addChild:inner];
    }
    self.parseLinks = YES;
    
    return element;
}

- (MMElement *) _startReferenceLink
{
    MMSpanScanner *scanner  = self.scanner;
    NSUInteger     startLoc = scanner.location;
    NSUInteger     length;
    
    // Find the []
    length = [scanner skipNestedBracketsWithDelimiter:'['];
    if (length == 0)
        return nil;
    
    NSRange textRange = NSMakeRange(startLoc+1, length-2);
    
    // Skip optional whitespace
    if ([scanner nextCharacter] == ' ')
        [scanner advance];
    
    // Look for the second []
    NSUInteger nameLocation;
    nameLocation = scanner.location;
    length       = [scanner skipNestedBracketsWithDelimiter:'['];
    if (length == 0)
        return nil;
    
    NSRange idRange = NSMakeRange(nameLocation+1, length-2);
    if (idRange.length == 0)
        idRange = textRange;
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeLink;
    element.range = NSMakeRange(startLoc, scanner.location-startLoc);
    element.identifier = [scanner.string substringWithRange:idRange];
    
    self.parseLinks = NO;
    NSArray *innerElements = [self _parseRange:textRange ofString:scanner.string];
    for (MMElement *inner in innerElements)
    {
        [element addChild:inner];
    }
    self.parseLinks = YES;
    
    return element;
}

- (MMElement *) _startStrong
{
    MMSpanScanner *scanner  = self.scanner;
    NSUInteger     startLoc = scanner.location;
    
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
    
    // Can't be at the end of a line or before a space
    if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[scanner nextCharacter]])
        return nil;
    
    MMElement *element = [MMElement new];
    element.type      = MMElementTypeStrong;
    element.range     = NSMakeRange(startLoc, 0);
    element.character = character;
    
    return element;
}

- (MMElement *) _startEm
{
    MMSpanScanner *scanner  = self.scanner;
    NSUInteger     startLoc = scanner.location;
    
    // Must have 1 * or _
    unichar character = [scanner nextCharacter];
    if (!(character == '*' || character == '_'))
        return nil;
    [scanner advance];
    
    // Can't be at the end of a line or before a space
    if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[scanner nextCharacter]])
        return nil;
    
    MMElement *element = [MMElement new];
    element.type      = MMElementTypeEm;
    element.range     = NSMakeRange(startLoc, 0);
    element.character = character;
    
    return element;
}

- (MMElement *) _startNewElement
{
    MMSpanScanner *scanner = self.scanner;
    MMElement *element;
    
    [scanner beginTransaction];
    element = [self _startStrong];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    [scanner beginTransaction];
    element = [self _startEm];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    [scanner beginTransaction];
    element = [self _startCodeSpan];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    if (self.parseLinks)
    {
        [scanner beginTransaction];
        element = [self _startAutomaticLink];
        [scanner commitTransaction:element != nil];
        if (element)
            return element;
        
        [scanner beginTransaction];
        element = [self _startInlineLink];
        [scanner commitTransaction:element != nil];
        if (element)
            return element;
        
        [scanner beginTransaction];
        element = [self _startReferenceLink];
        [scanner commitTransaction:element != nil];
        if (element)
            return element;
    }
    
    return nil;
}

- (MMElement *) _escapeAmpersand
{
    MMSpanScanner *scanner = self.scanner;
    
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

- (MMElement *) _escapeLeftAngleBracket
{
    MMSpanScanner *scanner = self.scanner;
    
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

- (MMElement *) _newEscapedEntity
{
    MMSpanScanner *scanner = self.scanner;
    MMElement *element;
    
    [scanner beginTransaction];
    element = [self _escapeAmpersand];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    [scanner beginTransaction];
    element = [self _escapeLeftAngleBracket];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    return nil;
}


@end
