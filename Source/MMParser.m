//
//  MMParser.m
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

#import "MMParser.h"


#import "MMDocument.h"
#import "MMDocument_Private.h"
#import "MMElement.h"
#import "MMScanner.h"
#import "MMSpanParser.h"
#import "MMTextSegment.h"

@interface MMParser ()
@property (strong, nonatomic) MMSpanParser   *spanParser;
@property (strong, nonatomic) MMScanner      *scanner;
@property (strong, nonatomic) MMDocument     *document;
@property (strong, nonatomic) NSMutableArray *openElements;
@property (strong, nonatomic) MMTextSegment  *textSegment;
@end

@implementation MMParser

@synthesize spanParser   = _spanParser;
@synthesize scanner      = _scanner;
@synthesize document     = _document;
@synthesize openElements = _openElements;
@synthesize textSegment  = _textSegment;

//==================================================================================================
#pragma mark -
#pragma mark NSObject Methods
//==================================================================================================

- (id) init
{
    self = [super init];
    
    if (self)
    {
        self.spanParser = [MMSpanParser new];
    }
    
    return self;
}


//==================================================================================================
#pragma mark -
#pragma mark Public Methods
//==================================================================================================

- (MMDocument *) parseMarkdown:(NSString *)markdown error:(__autoreleasing NSError **)error
{
    self.scanner      = [MMScanner scannerWithString:markdown];
    self.document     = [MMDocument documentWithMarkdown:markdown];
    self.openElements = [NSMutableArray new];
    self.textSegment  = [MMTextSegment segmentWithString:markdown];
    
    // Parse the markdown line-by-line.
    MMScanner *scanner = self.scanner;
    while (![scanner atEndOfString])
    {
        [self _parseNextLine];
        [scanner advanceToNextLine];
    }
    
    [self _endTextSegment];
    [self _closeElements:self.openElements atLocation:markdown.length];
    
    MMDocument *document = self.document;
    self.scanner      = nil;
    self.document     = nil;
    self.openElements = nil;
    self.textSegment  = nil;
    return document;
}


//==================================================================================================
#pragma mark -
#pragma mark Private Methods
//==================================================================================================

- (BOOL) _checkBlockquoteElement:(MMElement *)anElement
{
    MMScanner *scanner = self.scanner;
    
    if ([scanner atEndOfLine])
        return NO;
    
    [scanner skipCharactersFromSet:[NSCharacterSet whitespaceCharacterSet]];
    
    if ([scanner nextCharacter] != '>')
        return NO;
    [scanner advance];
    
    [scanner skipCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] max:1];
    
    return YES;
}

- (BOOL) _checkCodeElement:(MMElement *)anElement
{
    MMScanner *scanner = self.scanner;
    
    NSUInteger indentation = [scanner skipIndentationUpTo:4];
    
    // Code blocks end when there's text that's at an indentation that's less than 4.
    // Blank lines do not end a code block.
    if (indentation < 4 && ![scanner atEndOfLine])
    {
        // Remove trailing blank lines
        NSValue *lastRange = [self.textSegment.ranges lastObject];
        while ([lastRange rangeValue].length == 0)
        {
            [self.textSegment removeLastRange];
            lastRange = [self.textSegment.ranges lastObject];
        }
        
        // Add the text manually here to avoid span parsing
        for (NSValue *value in self.textSegment.ranges)
        {
            MMElement *line = [MMElement new];
            line.type  = MMElementTypeNone;
            line.range = [value rangeValue];
            [anElement addChild:line];
            
            // Add a newline if this isn't just a blank line
            if (line.range.length != 0)
            {
                MMElement *newline = [MMElement new];
                newline.type  = MMElementTypeNone;
                newline.range = NSMakeRange(0, 0);
                [anElement addChild:newline];
            }
        }
        self.textSegment = [MMTextSegment segmentWithString:self.document.markdown];
        
        return NO;
    }
    
    return YES;
}

- (void) _addParagraphsToItemsInList:(MMElement *)aList
{
    for (MMElement *item in aList.children)
    {
        MMElement *paragraph = [MMElement new];
        paragraph.type     = MMElementTypeParagraph;
        paragraph.children = item.children;
        
        if (paragraph.children.count > 0)
        {
            MMElement *firstText = [paragraph.children objectAtIndex:0];
            MMElement *lastText  = [paragraph.children lastObject];
            paragraph.range = NSMakeRange(firstText.range.location, NSMaxRange(lastText.range)-firstText.range.location);
        }
        
        item.children = [NSArray arrayWithObject:paragraph];
    }
}

- (BOOL) _checkListItemElement:(MMElement *)anElement makeChanges:(BOOL)makeChangesFlag
{
    MMScanner *scanner = self.scanner;
    
    // Make sure there's enough indentation
    NSUInteger indentation = [scanner skipIndentationUpTo:anElement.parent.indentation];
    if (indentation != anElement.parent.indentation)
        return NO;
    
    // Figure out how many lists are currently open
    MMElement  *lastElement = [anElement.children lastObject];
    NSUInteger  listCount   = 1;
    while (lastElement.children.count > 0)
    {
        if (lastElement.type == MMElementTypeNumberedList || lastElement.type == MMElementTypeBulletedList)
            listCount++;
        lastElement = [lastElement.children lastObject];
    }
    
    // Check for indentation if after a blank line
    NSArray *ranges    = self.textSegment.ranges;
    NSRange  lastRange = [(NSValue *)[ranges lastObject] rangeValue];
    if (ranges.count > 0 && lastRange.length == 0)
    {
        BOOL indentation = [scanner skipIndentationUpTo:4];
        
        // 4 spaces may mean a new paragraph in the list item
        if (indentation == 4)
        {
            // Check if this list already has paragraphs
            MMElement *list       = anElement.parent;
            MMElement *firstItem  = [list.children objectAtIndex:0];
            if (makeChangesFlag && firstItem.children.count == 0)
            {
                MMElement *list = anElement.parent;
                [self _addParagraphsToItemsInList:list];
                
                // Remove the blank line
                [self.textSegment removeLastRange];
                
                // End the current text segment inside the last paragraph
                MMElement *paragraph = [anElement.children lastObject];
                [self.openElements addObject:paragraph];
                [self _endTextSegment];
                [self.openElements removeLastObject];
            }
            
            return YES;
        }
        
        // After an empty line, but no indentation means the item is done
        return NO;
    }
    
    // Check for a new list item, possibly indented
    [scanner beginTransaction]; // We may want to keep this transaction
    indentation = [self.scanner skipIndentationUpTo:4];
    [scanner beginTransaction]; // We don't want to keep this transaction
    indentation += [self.scanner skipIndentationUpTo:4*(listCount-1)];
    
    if (indentation % 4 == 0)
    {
        BOOL foundAnItem = NO;
        
        // Look for a bullet
        unichar nextChar = [scanner nextCharacter];
        if (nextChar == '*' || nextChar == '-' || nextChar == '+')
        {
            foundAnItem = YES;
        }
        
        // Look for a numbered item
        if (!foundAnItem)
        {
            NSUInteger numOfNums = [scanner skipCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet]];
            if (numOfNums != 0)
            {
                unichar nextChar = [scanner nextCharacter];
                if (nextChar == '.')
                {
                    foundAnItem = YES;
                }
            }
        }
        
        // Check for a space after the marker
        if (foundAnItem)
        {
            [scanner advance];
            foundAnItem = [[NSCharacterSet whitespaceCharacterSet] characterIsMember:[scanner nextCharacter]];
        }
        
        if (foundAnItem)
        {
            [scanner commitTransaction:NO];
            
            if (indentation == 0)
            {
                [scanner commitTransaction:NO];
                return NO;
            }
            
            [scanner commitTransaction:YES];
            
            // If there's an open paragraph, close it before starting the new list
            MMElement *lastChild = [anElement.children lastObject];
            if (listCount == 1 && lastChild && lastChild.type == MMElementTypeParagraph)
            {
                NSRange range = lastChild.range;
                range.length = self.scanner.startLocation - range.location;
                lastChild.range = range;
            }
            
            // If there's not already an open child list, add a blank line so the new list starts on
            // its own line
            BOOL hasOpenChildList = NO;
            NSUInteger idx = [self.openElements indexOfObjectIdenticalTo:anElement];
            if (idx + 1 < self.openElements.count)
            {
                MMElement *openChild = [self.openElements objectAtIndex:idx+1];
                hasOpenChildList = openChild.type == MMElementTypeBulletedList
                                || openChild.type == MMElementTypeNumberedList;
            }
            if (!hasOpenChildList && makeChangesFlag)
            {
                [self.textSegment addRange:NSMakeRange(0, 0)];
            }
            
            return YES;
        }
    }
    
    [scanner commitTransaction:NO];
    [scanner commitTransaction:NO];
    
    // List items only end after blank lines or before new list items
    [scanner skipCharactersFromSet:[NSCharacterSet whitespaceCharacterSet]];
    return YES;
}

- (BOOL) _checkListElement:(MMElement *)anElement
{
    MMScanner *scanner = self.scanner;
    
    [scanner beginTransaction];
    NSArray *lineRanges = [self.textSegment.ranges copy];
    BOOL item = [self _checkListItemElement:[anElement.children lastObject] makeChanges:NO];
    self.textSegment.ranges = lineRanges;
    [scanner commitTransaction:NO];
    if (item)
        return YES;
    
    // Check for a new list item
    
    [scanner skipCharactersFromSet:[NSCharacterSet whitespaceCharacterSet]];
    
    unichar nextChar = [scanner nextCharacter];
    if (nextChar == '*' || nextChar == '-' || nextChar == '+')
    {
        // Maybe this is a horizontal rule, not a bullet
        [scanner beginTransaction];
        MMElement *rule = [self _startHorizontalRule];
        [scanner commitTransaction:NO];
        if (rule != nil)
            return NO;
        
        return YES;
    }
    
    [scanner beginTransaction];
    NSUInteger numOfNums = [scanner skipCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet]];
    if (numOfNums != 0)
    {
        unichar nextChar = [scanner nextCharacter];
        if (nextChar == '.')
        {
            [scanner commitTransaction:NO];
            return YES;
        }
    }
    [scanner commitTransaction:NO];
    
    return NO;
}

- (BOOL) _checkParagraphElement:(MMElement *)anElement
{
    MMScanner *scanner = self.scanner;
    
    [scanner skipCharactersFromSet:[NSCharacterSet whitespaceCharacterSet]];
    
    if ([scanner atEndOfLine])
        return NO;
    
    return YES;
}

- (BOOL) _checkElement:(MMElement *)anElement
{
    switch (anElement.type)
    {
        case MMElementTypeBlockquote:
            return [self _checkBlockquoteElement:anElement];
        case MMElementTypeCodeBlock:
            return [self _checkCodeElement:anElement];
        case MMElementTypeBulletedList:
        case MMElementTypeNumberedList:
            return [self _checkListElement:anElement];
        case MMElementTypeListItem:
            return [self _checkListItemElement:anElement makeChanges:YES];
        case MMElementTypeParagraph:
            return [self _checkParagraphElement:anElement];
        default:
            break;
    }
    return NO;
}

- (NSArray *) _checkOpenElements
{
    MMScanner  *scanner = self.scanner;
    NSUInteger  idx     = 0;
    NSUInteger  count   = self.openElements.count;
    
    for (; idx < count; idx++)
    {
        MMElement *element = [self.openElements objectAtIndex:idx];
        if (element.range.length != 0)
        {
            [self _endTextSegment];
            break;
        }
        
        [scanner beginTransaction];
        BOOL stillOpen = [self _checkElement:element];
        [scanner commitTransaction:stillOpen];
        
        if (!stillOpen)
        {
            [self _endTextSegment];
            break;
        }
    }
    
    if (idx == count)
        return [NSArray array];
    
    return [self.openElements subarrayWithRange:NSMakeRange(idx, count-idx)];
}

- (void) _closeElements:(NSArray *)elementsToClose
             atLocation:(NSUInteger)aLocation
{
    [self _endTextSegment];
    
    for (MMElement *element in elementsToClose)
    {
        NSRange range = element.range;
        element.range = NSMakeRange(range.location, aLocation - range.location);
    }
}

- (void) _removeTrailingBlankLinesFromElements:(NSArray *)elements
{
    for (MMElement *element in elements)
    {
        // Remove trailing blank lines from the elements
        MMElement *lastChild = [element.children lastObject];
        if (lastChild && lastChild.type == MMElementTypeNone && lastChild.range.length == 0)
        {
            [element removeLastChild];
        }
    }
}

- (BOOL) _blockElementCanHaveChildren:(MMElement *)anElement
{
    switch (anElement.type)
    {
        case MMElementTypeCodeBlock:
        case MMElementTypeParagraph:
            return NO;
            
        default:
            return YES;
    }
}

- (BOOL) _blockElementCanHaveParagraph:(MMElement *)anElement
{
    switch (anElement.type)
    {
        case MMElementTypeCodeBlock:
        case MMElementTypeParagraph:
            return NO;
            
        case MMElementTypeListItem:
        {
            // It can have children if the first item in the list has paragraphs
            MMElement *list = anElement.parent;
            if (list.children.count > 0)
            {
                MMElement *firstItem  = [list.children objectAtIndex:0];
                if (firstItem.children.count > 0)
                {
                    MMElement *firstChild = [firstItem.children objectAtIndex:0];
                    return firstChild.type == MMElementTypeParagraph;
                }
            }
            
            return NO;
        }
            
        default:
            return YES;
    }
}

- (void) _parseNextLine
{
    NSUInteger startLocation = self.scanner.location;
    
    // Check the open elements to see if they've been closed
    NSArray *elementsToClose = [self _checkOpenElements];
    
    // Close any block elements and remove any span elements left on the stack
    if (elementsToClose.count > 0)
    {
        [self _closeElements:elementsToClose atLocation:startLocation];
        [self.openElements removeObjectsInArray:elementsToClose];
    }
    
    // Check for additional block elements
    [self _startNewBlockElements];
    
    // Remove trailing blank lines. This needs to happen after starting new elements, because those
    // elements may use the blank lines in deciding what to be.
    [self _removeTrailingBlankLinesFromElements:elementsToClose];
    
    [self.textSegment addRange:self.scanner.lineRange];
}

- (void) _endTextSegment
{
    // If there's nothing to add, don't bother
    if (self.textSegment.ranges.count == 0)
        return;
    
    MMElement *topElement   = [self.openElements lastObject];
    NSArray   *spanElements = [self.spanParser parseTextSegment:self.textSegment];
    
    for (MMElement *element in spanElements)
    {
        if (topElement)
            [topElement addChild:element];
        else
            [self.document addElement:element];
    }
    
    self.textSegment = [MMTextSegment segmentWithString:self.document.markdown];
}

- (NSArray *) _startNewBlockElements
{
    NSMutableArray *newElements = [NSMutableArray new];
    
    MMElement *topElement = [self.openElements lastObject];
    while (!topElement || [self _blockElementCanHaveChildren:topElement])
    {
        MMElement *element = [self _startBlockElement];
        
        if (!element)
            break;
        
        [self _endTextSegment];
        
        [newElements addObject:element];
        
        // Add the new elements to the hierarchy
        if (topElement)
            [topElement addChild:element];
        else
            [self.document addElement:element];
        
        // If the element is still open, add it to the stack
        if (element.range.length == 0)
        {
            [self.openElements addObject:element];
            topElement = element;
        }
        else
            topElement = nil;
    }
    
    return newElements;
}

- (MMElement *) _startBlockElement
{
    MMScanner *scanner = self.scanner;
    MMElement *element;
    
    [scanner beginTransaction];
    element = [self _startHTML];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    [scanner beginTransaction];
    element = [self _startHeader];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    [scanner beginTransaction];
    element = [self _startBlockquote];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    [scanner beginTransaction];
    element = [self _startListItem];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    // Check code first because its four-space behavior trumps most else
    [scanner beginTransaction];
    element = [self _startCodeBlock];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    // Check horizontal rules before lists since they both start with * or -
    [scanner beginTransaction];
    element = [self _startHorizontalRule];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    [scanner beginTransaction];
    element = [self _startBulletedList];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    [scanner beginTransaction];
    element = [self _startNumberedList];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    MMElement *topElement = [self.openElements lastObject];
    if (!topElement || [self _blockElementCanHaveParagraph:topElement])
    {
        [self.scanner beginTransaction];
        element = [self _startParagraph];
        [self.scanner commitTransaction:element != nil];
        if (element)
            return element;
    }
    
    return nil;
}

- (MMElement *) _startHTML
{
    MMScanner *scanner = self.scanner;
    
    NSUInteger startLocation = self.scanner.location;
    
    // At the beginning of the line
    if (![scanner atBeginningOfLine])
        return nil;
    
    // which starts with a '<'
    if ([scanner nextCharacter] != '<')
        return nil;
    [scanner advance];
    
    NSSet *htmlBlockTags = [NSSet setWithObjects:
                            @"p", @"div", @"h1", @"h2", @"h3", @"h4", @"h5", @"h6",
                            @"blockquote", @"pre", @"table", @"dl", @"ol", @"ul",
                            @"script", @"noscript", @"form", @"fieldset", @"iframe",
                            @"math", @"ins", @"del", nil];
    NSString *tagName = [scanner substringBeforeCharacter:'>'];
    if (![htmlBlockTags containsObject:tagName])
        return nil;
    
    // Skip lines until we come across a blank line
    while (![scanner atEndOfLine])
    {
        [scanner advanceToNextLine];
    }
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeHTML;
    element.range = NSMakeRange(startLocation, scanner.location-startLocation);
        
    return element;
}

- (MMElement *) _startHeader
{
    MMScanner *scanner = self.scanner;
    
    NSUInteger level = 0;
    while ([scanner nextCharacter] == '#' && level < 6)
    {
        level++;
        [scanner advance];
    }
    
    if (level == 0)
        return nil;
    
    [scanner skipCharactersFromSet:[NSCharacterSet whitespaceCharacterSet]];
    
    MMElement *textElement = [MMElement new];
    textElement.type  = MMElementTypeNone;
    textElement.range = [scanner lineRange];
    
    [scanner skipToEndOfLine];
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeHeader;
    element.range = NSMakeRange(scanner.startLocation, NSMaxRange(textElement.range)-scanner.startLocation);
    element.level = level;
    [element addChild:textElement];
    
    return element;
}

- (MMElement *) _startBlockquote
{
    MMScanner *scanner = self.scanner;
    
    NSCharacterSet *spaceCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@" "];
    [scanner skipCharactersFromSet:spaceCharacterSet max:3];
    
    if ([scanner nextCharacter] != '>')
        return nil;
    [scanner advance];
    
    [scanner skipCharactersFromSet:spaceCharacterSet max:1];
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeBlockquote;
    element.range = NSMakeRange(scanner.startLocation, 0);
    
    return element;
}

- (MMElement *) _startCodeBlock
{
    MMScanner *scanner = self.scanner;
    
    NSUInteger indentation = [scanner skipIndentationUpTo:4];
    if (indentation != 4)
        return nil;
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeCodeBlock;
    element.range = NSMakeRange(scanner.startLocation, 0);
    
    return element;
}

- (MMElement *) _startHorizontalRule
{
    MMScanner *scanner = self.scanner;
    
    // skip initial whitescape
    [scanner skipCharactersFromSet:[NSCharacterSet whitespaceCharacterSet]];
    
    unichar character = [scanner nextCharacter];
    if (character != '*' && character != '-' && character != '_')
        return nil;
    
    unichar    nextChar = character;
    NSUInteger count    = 0;
    while (![scanner atEndOfLine] && nextChar == character)
    {
        count++;
        
        // The *, -, or _
        [scanner advance];
        nextChar = [scanner nextCharacter];
        
        // An optional space
        if (nextChar == ' ')
        {
            [scanner advance];
            nextChar = [scanner nextCharacter];
        }
    }
    
    // There must be at least 3 *, -, or _
    if (count < 3)
        return nil;
    
    // skip trailing whitespace
    [scanner skipCharactersFromSet:[NSCharacterSet whitespaceCharacterSet]];
    
    // must be at the end of the line at this point
    if (![scanner atEndOfLine])
        return nil;
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeHorizontalRule;
    element.range = NSMakeRange(scanner.startLocation, scanner.location - scanner.startLocation);
    
    return element;
}

- (MMElement *) _startListItem
{
    // Don't start a list item unless a list is already on the stack
    MMElement *topElement = [self.openElements lastObject];
    if (topElement.type != MMElementTypeBulletedList && topElement.type != MMElementTypeNumberedList)
        return nil;
    
    MMScanner *scanner = self.scanner;
    BOOL foundAnItem = NO;
    
    // Look for a bullet
    unichar nextChar = [scanner nextCharacter];
    if (nextChar == '*' || nextChar == '-' || nextChar == '+')
    {
        [scanner advance];
        foundAnItem = YES;
    }
    
    // Look for a numbered item
    if (!foundAnItem)
    {
        NSUInteger numOfNums = [scanner skipCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet]];
        if (numOfNums != 0)
        {
            unichar nextChar = [scanner nextCharacter];
            if (nextChar == '.')
            {
                [scanner advance];
                foundAnItem = YES;
            }
        }
    }
    
    if (!foundAnItem)
        return nil;
    
    [scanner skipCharactersFromSet:[NSCharacterSet whitespaceCharacterSet]];
    
    // If this isn't the first element in the list and it's preceded by a blank line, then all the
    // list items should have paragraphs.
    MMElement *list = topElement;
    if (list.children.count > 0)
    {
        // Check if this list already has paragraphs
        MMElement *firstItem  = [list.children objectAtIndex:0];
        MMElement *firstChild = [firstItem.children objectAtIndex:0];
        if (firstChild.type != MMElementTypeParagraph)
        {
            // It's only a new paragraph if it follows a blank line.
            MMElement *lastItem  = [list.children lastObject];
            MMElement *lastChild = [lastItem.children lastObject];
            if (lastChild.type == MMElementTypeNone && lastChild.range.length == 0)
            {
                [self _addParagraphsToItemsInList:list];
                
                // Move the blank line outside the paragraph
                MMElement *lastItem  = [list.children lastObject];
                MMElement *paragraph = [lastItem.children lastObject];
                MMElement *blankLine = [paragraph removeLastChild];
                if (blankLine)
                {
                    [self.textSegment addRange:NSMakeRange(0, 0)];
                }
            }
        }
    }
    
    MMElement *element = [MMElement new];
    element.type = MMElementTypeListItem;
    element.range = NSMakeRange(scanner.startLocation, 0);
    
    return element;
}

- (MMElement *) _startBulletedList
{
    MMScanner *scanner = self.scanner;
    
    NSUInteger indentation = [scanner skipIndentationUpTo:4];
    
    unichar nextChar = [scanner nextCharacter];
    if (!(nextChar == '*' || nextChar == '-' || nextChar == '+'))
        return nil;
    
    // Don't actually advance -- the list item will do that
    [scanner beginTransaction];
    [scanner advance];
    nextChar = [scanner nextCharacter];
    [scanner commitTransaction:NO];
    
    // Must have a space after the marker
    if (![[NSCharacterSet whitespaceCharacterSet] characterIsMember:nextChar])
        return nil;
    
    MMElement *element = [MMElement new];
    element.type        = MMElementTypeBulletedList;
    element.range       = NSMakeRange(scanner.startLocation, 0);
    element.indentation = indentation;
    
    return element;
}

- (MMElement *) _startNumberedList
{
    MMScanner *scanner = self.scanner;
    
    NSUInteger indentation = [scanner skipIndentationUpTo:4];
    
    [scanner beginTransaction];
    
    // At least one number
    NSUInteger numOfNums = [scanner skipCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet]];
    if (numOfNums == 0)
    {
        [scanner commitTransaction:NO];
        return nil;
    }
    
    // And a dot
    unichar nextChar = [scanner nextCharacter];
    if (nextChar != '.')
    {
        [scanner commitTransaction:NO];
        return nil;
    }
    [scanner advance];
    
    // Must have a space after the marker
    if (![[NSCharacterSet whitespaceCharacterSet] characterIsMember:[scanner nextCharacter]])
        return nil;
    
    // Don't advance -- the list item will do that
    [scanner commitTransaction:NO];
    
    MMElement *element = [MMElement new];
    element.type        = MMElementTypeNumberedList;
    element.range       = NSMakeRange(scanner.startLocation, 0);
    element.indentation = indentation;
    
    return element;
}

- (MMElement *) _startParagraph
{
    MMScanner *scanner = self.scanner;
    
    NSCharacterSet *spaceCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@" "];
    [scanner skipCharactersFromSet:spaceCharacterSet max:3];
    
    if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[scanner nextCharacter]])
        return nil;
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeParagraph;
    element.range = NSMakeRange(scanner.location, 0);
    
    return element;
}


@end
