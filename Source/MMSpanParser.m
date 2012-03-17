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
@end

@implementation MMSpanParser

@synthesize scanner      = _scanner;
@synthesize elements     = _elements;
@synthesize openElements = _openElements;

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
    while (![scanner atEndOfString])
    {
        [self _parseNextLine];
        [scanner advanceToNextLine];
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

- (void) _parseNextLine
{
    MMSpanScanner *scanner = self.scanner;
    
    NSCharacterSet *specialChars = [NSCharacterSet characterSetWithCharactersInString:@"\\`*_<&"];
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
    while (element != anElement)
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

- (BOOL) _canCloseStrongAndEm:(MMElement *)anElement
{
    MMSpanScanner *scanner = self.scanner;
    
    // Can't be at the beginning of the line
    if ([scanner atBeginningOfLine])
        return NO;
    
    // Must follow the end of a word
    NSCharacterSet *wordSet = [[NSCharacterSet whitespaceCharacterSet] invertedSet];
    if (![wordSet characterIsMember:[scanner previousCharacter]])
        return NO;
    
    // Must have 3 *s or _s
    for (NSUInteger idx=0; idx<3; idx++)
    {
        if ([scanner nextCharacter] != anElement.character)
            return NO;
        [scanner advance];
    }
    
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
        case MMElementTypeStrongAndEm:
            return [self _canCloseStrongAndEm:anElement];
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
    [self.openElements addObject:anElement];
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
    element.range = NSMakeRange(startLoc, 0);
    element.stringValue = linkText;
    
    [self _addTextFromLocation:textLocation toLocation:NSMaxRange(linkRange) toElement:element];
    
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
    NSCharacterSet *nonTickCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"`"] invertedSet];
    NSUInteger      textLocation      = scanner.location;
    while (![scanner atEndOfString])
    {
        // Skip other characters
        [scanner skipCharactersFromSet:nonTickCharacters];
        
        // Add the code as text
        [self _addTextFromLocation:textLocation toLocation:scanner.location toElement:element];
        
        // Did we find the closing `?
        if ([scanner nextCharacter] == '`')
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
        
        [scanner advanceToNextLine];
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

- (MMElement *) _startStrongAndEm
{
    MMSpanScanner *scanner  = self.scanner;
    NSUInteger     startLoc = scanner.location;
    
    // Must be at the beginning of a line...
    if (![scanner atBeginningOfLine])
    {
        // ...or after a space
        if ([scanner previousCharacter] != ' ')
            return nil;
    }
    
    // Must have 3 *s or _s
    unichar character = [scanner nextCharacter];
    if (!(character == '*' || character == '_'))
        return nil;
    
    for (NSUInteger idx=0; idx<3; idx++)
    {
        if ([scanner nextCharacter] != character)
            return nil;
        [scanner advance];
    }
    
    MMElement *element = [MMElement new];
    element.type      = MMElementTypeStrongAndEm;
    element.range     = NSMakeRange(startLoc, 0);
    element.character = character;
    
    return element;
}

- (MMElement *) _startNewElement
{
    MMSpanScanner *scanner = self.scanner;
    MMElement *element;
    
    [scanner beginTransaction];
    element = [self _startStrongAndEm];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    [scanner beginTransaction];
    element = [self _startCodeSpan];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    [scanner beginTransaction];
    element = [self _startAutomaticLink];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
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

- (MMElement *) _newEscapedEntity
{
    MMSpanScanner *scanner = self.scanner;
    MMElement *element;
    
    [scanner beginTransaction];
    element = [self _escapeAmpersand];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    return nil;
}


@end
