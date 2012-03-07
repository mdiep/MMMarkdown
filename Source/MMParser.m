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

@interface MMParser ()
- (BOOL) _checkElement:(MMElement *)anElement
           withScanner:(MMScanner *)aScanner
            inDocument:(MMDocument *)aDocument;
- (NSArray *) _checkOpenElements:(NSArray *)openElements
                     withScanner:(MMScanner *)aScanner
                      inDocument:(MMDocument *)aDocument;
- (void) _parseLineWithScanner:(MMScanner *)aScanner
                    inDocument:(MMDocument *)aDocument
                  openElements:(NSMutableArray *)openElements;
@end

@implementation MMParser

//==================================================================================================
#pragma mark -
#pragma mark Public Methods
//==================================================================================================

- (MMDocument *) parseMarkdown:(NSString *)markdown error:(__autoreleasing NSError **)error
{
    MMScanner  *scanner  = [MMScanner scannerWithString:markdown];
    MMDocument *document = [MMDocument documentWithMarkdown:markdown];
    
    NSMutableArray *openElements = [NSMutableArray new];
    
    // Parse the markdown line-by-line.
    while (![scanner atEndOfString])
    {
        [self _parseLineWithScanner:scanner
                         inDocument:document
                       openElements:openElements];
        
        [scanner advanceToNextLine];
    }
    
    [self _closeElements:openElements atLocation:markdown.length];
    
    return document;
}


//==================================================================================================
#pragma mark -
#pragma mark Private Methods
//==================================================================================================

- (BOOL) _checkBlockquoteElement:(MMElement *)anElement
                     withScanner:(MMScanner *)aScanner
                      inDocument:(MMDocument *)aDocument
{
    if ([aScanner atEndOfLine])
        return NO;
    
    [aScanner skipCharactersFromSet:[NSCharacterSet whitespaceCharacterSet]];
    
    if ([aScanner nextCharacter] != '>')
        return NO;
    [aScanner advance];
    
    [aScanner skipCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] max:1];
    
    return YES;
}

- (BOOL) _checkCodeElement:(MMElement *)anElement
               withScanner:(MMScanner *)aScanner
                inDocument:(MMDocument *)aDocument
{
    NSUInteger indentation = [aScanner skipIndentationUpTo:4];
    if (indentation != 4)
        return NO;
    
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

- (BOOL) _checkListItemElement:(MMElement *)anElement
                   withScanner:(MMScanner *)aScanner
                    inDocument:(MMDocument *)aDocument
{
    // Make sure there's enough indentation
    NSUInteger indentation = [aScanner skipIndentationUpTo:anElement.parent.indentation];
    if (indentation != anElement.parent.indentation)
        return NO;
    
    // Figure out what the last line was in the item and how many lists are currently open
    MMElement  *lastElement = [anElement.children lastObject];
    NSUInteger  listCount   = 1;
    while (lastElement.children.count > 0)
    {
        if (lastElement.type == MMElementTypeNumberedList || lastElement.type == MMElementTypeBulletedList)
            listCount++;
        lastElement = [lastElement.children lastObject];
    }
    
    // Check for indentation if after a blank line
    if (lastElement && lastElement.type == MMElementTypeNone && lastElement.range.length == 0)
    {
        BOOL indentation = [aScanner skipIndentationUpTo:4];
        
        // 4 spaces may mean a new paragraph in the list item
        if (indentation == 4)
        {
            // Check if this list already has paragraphs
            MMElement *list       = anElement.parent;
            MMElement *firstItem  = [list.children objectAtIndex:0];
            MMElement *firstChild = [firstItem.children objectAtIndex:0];
            if (firstChild.type != MMElementTypeParagraph)
            {
                // It's only a new paragraph if it follows a blank line.
                MMElement *child = [anElement.children lastObject];
                if (child.type == MMElementTypeNone && child.range.length == 0)
                {
                    MMElement *list = anElement.parent;
                    [self _addParagraphsToItemsInList:list];
                    
                    // Move the blank line outside the paragraph
                    MMElement *paragraph = [anElement.children objectAtIndex:0];
                    MMElement *blankLine = [paragraph removeLastChild];
                    [anElement addChild:blankLine];
                }
            }
            
            return YES;
        }
        
        // After an empty line, but no indentation means the item is done
        return NO;
    }
    
    // Check for a new list item, possibly indented
    [aScanner beginTransaction]; // We may want to keep this transaction
    indentation = [aScanner skipIndentationUpTo:4];
    [aScanner beginTransaction]; // We don't want to keep this transaction
    indentation += [aScanner skipIndentationUpTo:4*(listCount-1)];
    
    if (indentation % 4 == 0)
    {
        BOOL foundAnItem = NO;
        
        // Look for a bullet
        unichar nextChar = [aScanner nextCharacter];
        if (nextChar == '*' || nextChar == '-' || nextChar == '+')
        {
            foundAnItem = YES;
        }
        
        // Look for a numbered item
        if (!foundAnItem)
        {
            NSUInteger numOfNums = [aScanner skipCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet]];
            if (numOfNums != 0)
            {
                unichar nextChar = [aScanner nextCharacter];
                if (nextChar == '.')
                {
                    foundAnItem = YES;
                }
            }
        }
        
        if (foundAnItem)
        {
            [aScanner commitTransaction:NO];
            
            if (indentation == 0)
            {
                [aScanner commitTransaction:NO];
                return NO;
            }
            
            [aScanner commitTransaction:YES];
            
            // If there's an open paragraph, close it before starting the new list
            MMElement *lastChild = [anElement.children lastObject];
            if (listCount == 1 && lastChild && lastChild.type == MMElementTypeParagraph)
            {
                NSRange range = lastChild.range;
                range.length = aScanner.startLocation - range.location;
                lastChild.range = range;
                
                // Also add a blank line so the new list starts on its own line
                MMElement *blankLine = [MMElement new];
                blankLine.type  = MMElementTypeNone;
                blankLine.range = NSMakeRange(0, 0);
                [anElement addChild:blankLine];
            }
            
            return YES;
        }
    }
    
    [aScanner commitTransaction:NO];
    [aScanner commitTransaction:NO];
    
    // List items only end after blank lines or before new list items
    [aScanner skipCharactersFromSet:[NSCharacterSet whitespaceCharacterSet]];
    return YES;
}

- (BOOL) _checkListElement:(MMElement *)anElement
               withScanner:(MMScanner *)aScanner
                inDocument:(MMDocument *)aDocument
{
    [aScanner beginTransaction];
    BOOL item = [self _checkListItemElement:[anElement.children lastObject] withScanner:aScanner inDocument:aDocument];
    [aScanner commitTransaction:NO];
    if (item)
        return YES;
    
    // Check for a new list item
    
    [aScanner skipCharactersFromSet:[NSCharacterSet whitespaceCharacterSet]];
    
    unichar nextChar = [aScanner nextCharacter];
    if (nextChar == '*' || nextChar == '-' || nextChar == '+')
    {
        // Maybe this is a horizontal rule, not a bullet
        [aScanner beginTransaction];
        MMElement *rule = [self _startHorizontalRuleWithScanner:aScanner inDocument:aDocument];
        [aScanner commitTransaction:NO];
        if (rule != nil)
            return NO;
        
        return YES;
    }
    
    [aScanner beginTransaction];
    NSUInteger numOfNums = [aScanner skipCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet]];
    if (numOfNums != 0)
    {
        unichar nextChar = [aScanner nextCharacter];
        if (nextChar == '.')
        {
            [aScanner commitTransaction:NO];
            return YES;
        }
    }
    [aScanner commitTransaction:NO];
    
    return NO;
}

- (BOOL) _checkParagraphElement:(MMElement *)anElement
                    withScanner:(MMScanner *)aScanner
                     inDocument:(MMDocument *)aDocument
{
    [aScanner skipCharactersFromSet:[NSCharacterSet whitespaceCharacterSet]];
    
    if ([aScanner atEndOfLine])
        return NO;
    
    return YES;
}

- (BOOL) _checkElement:(MMElement *)anElement
           withScanner:(MMScanner *)aScanner
            inDocument:(MMDocument *)aDocument
{
    switch (anElement.type)
    {
        case MMElementTypeBlockquote:
            return [self _checkBlockquoteElement:anElement withScanner:aScanner inDocument:aDocument];
        case MMElementTypeCode:
            return [self _checkCodeElement:anElement withScanner:aScanner inDocument:aDocument];
        case MMElementTypeBulletedList:
        case MMElementTypeNumberedList:
            return [self _checkListElement:anElement withScanner:aScanner inDocument:aDocument];
        case MMElementTypeListItem:
            return [self _checkListItemElement:anElement withScanner:aScanner inDocument:aDocument];
        case MMElementTypeParagraph:
            return [self _checkParagraphElement:anElement withScanner:aScanner inDocument:aDocument];
        default:
            break;
    }
    return NO;
}

- (NSArray *) _checkOpenElements:(NSArray *)openElements
                     withScanner:(MMScanner *)aScanner
                      inDocument:(MMDocument *)aDocument
{
    NSUInteger idx   = 0;
    NSUInteger count = openElements.count;
    
    for (; idx < count; idx++)
    {
        MMElement *element = [openElements objectAtIndex:idx];
        if (element.range.length != 0)
            break;
        
        [aScanner beginTransaction];
        BOOL stillOpen = [self _checkElement:element withScanner:aScanner inDocument:aDocument];
        [aScanner commitTransaction:stillOpen];
        
        if (!stillOpen)
            break;
    }
    
    if (idx == count)
        return [NSArray array];
    
    return [openElements subarrayWithRange:NSMakeRange(idx, count-idx)];
}

- (void) _closeElements:(NSArray *)elementsToClose
             atLocation:(NSUInteger)aLocation
{
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
        case MMElementTypeCode:
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
        case MMElementTypeCode:
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

- (void) _parseLineWithScanner:(MMScanner *)aScanner
                    inDocument:(MMDocument *)aDocument
                  openElements:(NSMutableArray *)openElements
{
    NSUInteger startLocation = aScanner.location;
    
    // Check the open elements to see if they've been closed
    NSArray *elementsToClose = [self _checkOpenElements:openElements withScanner:aScanner inDocument:aDocument];
    
    // Close any block elements and remove any span elements left on the stack
    [self _closeElements:elementsToClose atLocation:startLocation];
    [openElements removeObjectsInArray:elementsToClose];
    
    // Check for additional block elements
    [self _startNewElementsWithScanner:aScanner inDocument:aDocument openElements:openElements];
    
    // Remove trailing blank lines. This needs to happen after starting new elements, because those
    // elements may use the blank lines in deciding what to be.
    [self _removeTrailingBlankLinesFromElements:elementsToClose];
    
    MMElement *topElement    = [openElements lastObject];
    BOOL       shouldAddText = YES;
    
    // Don't add 2 blank lines in a row
    if ([aScanner atEndOfLine])
    {
        MMElement *sibling = topElement ? [topElement.children lastObject] : [aDocument.elements lastObject];
        if (sibling.type == MMElementTypeNone && sibling.range.length == 0)
        {
            shouldAddText = NO;
        }
    }
    
    if (shouldAddText)
    {
        MMElement *element = [MMElement new];
        element.type  = MMElementTypeNone;
        element.range = aScanner.lineRange;
        if (topElement)
            [topElement addChild:element];
        else
            [aDocument addElement:element];
    }
}

- (NSArray *) _startNewElementsWithScanner:(MMScanner *)aScanner
                                inDocument:(MMDocument *)aDocument
                              openElements:(NSMutableArray *)openElements
{
    NSMutableArray *newElements = [NSMutableArray new];
    
    MMElement *topElement = [openElements lastObject];
    while (!topElement || [self _blockElementCanHaveChildren:topElement])
    {
        MMElement *element = [self _startElementWithScanner:aScanner inDocument:aDocument openElements:openElements];
        
        if (!element)
            break;
        
        [newElements addObject:element];
        
        // Add the new elements to the hierarchy
        if (topElement)
            [topElement addChild:element];
        else
            [aDocument addElement:element];
        
        // If the element is still open, add it to the stack
        if (element.range.length == 0)
        {
            [openElements addObject:element];
            topElement = element;
        }
        else
            topElement = nil;
    }
    
    return newElements;
}

- (MMElement *) _startElementWithScanner:(MMScanner *)aScanner
                              inDocument:(MMDocument *)aDocument
                            openElements:(NSArray *)openElements
{
    MMElement *element;
    
    [aScanner beginTransaction];
    element = [self _startHTMLWithScanner:aScanner inDocument:aDocument];
    [aScanner commitTransaction:element != nil];
    if (element)
        return element;
    
    [aScanner beginTransaction];
    element = [self _startHeaderWithScanner:aScanner inDocument:aDocument];
    [aScanner commitTransaction:element != nil];
    if (element)
        return element;
    
    [aScanner beginTransaction];
    element = [self _startBlockquoteWithScanner:aScanner inDocument:aDocument];
    [aScanner commitTransaction:element != nil];
    if (element)
        return element;
    
    [aScanner beginTransaction];
    element = [self _startListItemWithScanner:aScanner inDocument:aDocument openElements:openElements];
    [aScanner commitTransaction:element != nil];
    if (element)
        return element;
    
    // Check code first because its four-space behavior trumps most else
    [aScanner beginTransaction];
    element = [self _startCodeWithScanner:aScanner inDocument:aDocument];
    [aScanner commitTransaction:element != nil];
    if (element)
        return element;
    
    // Check horizontal rules before lists since they both start with * or -
    [aScanner beginTransaction];
    element = [self _startHorizontalRuleWithScanner:aScanner inDocument:aDocument];
    [aScanner commitTransaction:element != nil];
    if (element)
        return element;
    
    [aScanner beginTransaction];
    element = [self _startBulletedListWithScanner:aScanner inDocument:aDocument];
    [aScanner commitTransaction:element != nil];
    if (element)
        return element;
    
    [aScanner beginTransaction];
    element = [self _startNumberedListWithScanner:aScanner inDocument:aDocument];
    [aScanner commitTransaction:element != nil];
    if (element)
        return element;
    
    MMElement *topElement = [openElements lastObject];
    if (!topElement || [self _blockElementCanHaveParagraph:topElement])
    {
        [aScanner beginTransaction];
        element = [self _startParagraphWithScanner:aScanner inDocument:aDocument];
        [aScanner commitTransaction:element != nil];
        if (element)
            return element;
    }
    
    return nil;
}

- (MMElement *) _startHTMLWithScanner:(MMScanner *)aScanner inDocument:(MMDocument *)aDocument
{
    NSUInteger startLocation = aScanner.location;
    
    // At the beginning of the line
    if (![aScanner atBeginningOfLine])
        return nil;
    
    // which starts with a '<'
    if ([aScanner nextCharacter] != '<')
        return nil;
    [aScanner advance];
    
    NSSet *htmlBlockTags = [NSSet setWithObjects:
                            @"p", @"div", @"h1", @"h2", @"h3", @"h4", @"h5", @"h6",
                            @"blockquote", @"pre", @"table", @"dl", @"ol", @"ul",
                            @"script", @"noscript", @"form", @"fieldset", @"iframe",
                            @"math", @"ins", @"del", nil];
    NSString *tagName = [aScanner substringBeforeCharacter:'>'];
    if (![htmlBlockTags containsObject:tagName])
        return nil;
    
    // Skip lines until we come across a blank line
    while (![aScanner atEndOfLine])
    {
        [aScanner advanceToNextLine];
    }
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeHTML;
    element.range = NSMakeRange(startLocation, aScanner.location-startLocation);
        
    return element;
}

- (MMElement *) _startHeaderWithScanner:(MMScanner *)aScanner inDocument:(MMDocument *)aDocument
{
    NSUInteger level = 0;
    while ([aScanner nextCharacter] == '#' && level < 6)
    {
        level++;
        [aScanner advance];
    }
    
    if (level == 0)
        return nil;
    
    [aScanner skipCharactersFromSet:[NSCharacterSet whitespaceCharacterSet]];
    
    MMElement *textElement = [MMElement new];
    textElement.type  = MMElementTypeNone;
    textElement.range = [aScanner lineRange];
    
    [aScanner skipToEndOfLine];
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeHeader;
    element.range = NSMakeRange(aScanner.startLocation, NSMaxRange(textElement.range)-aScanner.startLocation);
    element.level = level;
    [element addChild:textElement];
    
    return element;
}

- (MMElement *) _startBlockquoteWithScanner:(MMScanner *)aScanner inDocument:(MMDocument *)aDocument
{
    NSCharacterSet *spaceCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@" "];
    [aScanner skipCharactersFromSet:spaceCharacterSet max:3];
    
    if ([aScanner nextCharacter] != '>')
        return nil;
    [aScanner advance];
    
    [aScanner skipCharactersFromSet:spaceCharacterSet max:1];
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeBlockquote;
    element.range = NSMakeRange(aScanner.startLocation, 0);
    
    return element;
}

- (MMElement *) _startCodeWithScanner:(MMScanner *)aScanner inDocument:(MMDocument *)aDocument
{
    NSUInteger indentation = [aScanner skipIndentationUpTo:4];
    if (indentation != 4)
        return nil;
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeCode;
    element.range = NSMakeRange(aScanner.startLocation, 0);
    
    return element;
}

- (MMElement *) _startHorizontalRuleWithScanner:(MMScanner *)aScanner inDocument:(MMDocument *)aDocument
{
    // skip initial whitescape
    [aScanner skipCharactersFromSet:[NSCharacterSet whitespaceCharacterSet]];
    
    unichar character = [aScanner nextCharacter];
    if (character != '*' && character != '-' && character != '_')
        return nil;
    
    unichar    nextChar = character;
    NSUInteger count    = 0;
    while (![aScanner atEndOfLine] && nextChar == character)
    {
        count++;
        
        // The *, -, or _
        [aScanner advance];
        nextChar = [aScanner nextCharacter];
        
        // An optional space
        if (nextChar == ' ')
        {
            [aScanner advance];
            nextChar = [aScanner nextCharacter];
        }
    }
    
    // There must be at least 3 *, -, or _
    if (count < 3)
        return nil;
    
    // skip trailing whitespace
    [aScanner skipCharactersFromSet:[NSCharacterSet whitespaceCharacterSet]];
    
    // must be at the end of the line at this point
    if (![aScanner atEndOfLine])
        return nil;
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeHorizontalRule;
    element.range = NSMakeRange(aScanner.startLocation, aScanner.location - aScanner.startLocation);
    
    return element;
}

- (MMElement *) _startListItemWithScanner:(MMScanner *)aScanner
                               inDocument:(MMDocument *)aDocument
                             openElements:(NSArray *)openElements
{
    // Don't start a list item unless a list is already on the stack
    MMElement *topElement = [openElements lastObject];
    if (topElement.type != MMElementTypeBulletedList && topElement.type != MMElementTypeNumberedList)
        return nil;
    
    BOOL foundAnItem = NO;
    
    // Look for a bullet
    unichar nextChar = [aScanner nextCharacter];
    if (nextChar == '*' || nextChar == '-' || nextChar == '+')
    {
        [aScanner advance];
        foundAnItem = YES;
    }
    
    // Look for a numbered item
    if (!foundAnItem)
    {
        NSUInteger numOfNums = [aScanner skipCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet]];
        if (numOfNums != 0)
        {
            unichar nextChar = [aScanner nextCharacter];
            if (nextChar == '.')
            {
                [aScanner advance];
                foundAnItem = YES;
            }
        }
    }
    
    if (!foundAnItem)
        return nil;
    
    [aScanner skipCharactersFromSet:[NSCharacterSet whitespaceCharacterSet]];
    
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
                MMElement *paragraph = [lastItem.children lastObject];
                MMElement *blankLine = [paragraph removeLastChild];
                if (blankLine)
                {
                    [lastItem addChild:blankLine];
                }
            }
        }
    }
    
    MMElement *element = [MMElement new];
    element.type = MMElementTypeListItem;
    element.range = NSMakeRange(aScanner.startLocation, 0);
    
    return element;
}

- (MMElement *) _startBulletedListWithScanner:(MMScanner *)aScanner inDocument:(MMDocument *)aDocument
{
    NSUInteger indentation = [aScanner skipIndentationUpTo:4];
    
    unichar nextChar = [aScanner nextCharacter];
    if (!(nextChar == '*' || nextChar == '-' || nextChar == '+'))
        return nil;
    // Don't advance -- the list item will do that
    
    MMElement *element = [MMElement new];
    element.type        = MMElementTypeBulletedList;
    element.range       = NSMakeRange(aScanner.startLocation, 0);
    element.indentation = indentation;
    
    return element;
}

- (MMElement *) _startNumberedListWithScanner:(MMScanner *)aScanner inDocument:(MMDocument *)aDocument
{
    NSUInteger indentation = [aScanner skipIndentationUpTo:4];
    
    [aScanner beginTransaction];
    
    // At least one number
    NSUInteger numOfNums = [aScanner skipCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet]];
    if (numOfNums == 0)
    {
        [aScanner commitTransaction:NO];
        return nil;
    }
    
    // And a dot
    unichar nextChar = [aScanner nextCharacter];
    if (nextChar != '.')
    {
        [aScanner commitTransaction:NO];
        return nil;
    }
    
    // Don't advance -- the list item will do that
    [aScanner commitTransaction:NO];
    
    MMElement *element = [MMElement new];
    element.type        = MMElementTypeNumberedList;
    element.range       = NSMakeRange(aScanner.startLocation, 0);
    element.indentation = indentation;
    
    return element;
}

- (MMElement *) _startParagraphWithScanner:(MMScanner *)aScanner inDocument:(MMDocument *)aDocument
{
    NSCharacterSet *spaceCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@" "];
    [aScanner skipCharactersFromSet:spaceCharacterSet max:3];
    
    if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[aScanner nextCharacter]])
        return nil;
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeParagraph;
    element.range = NSMakeRange(aScanner.location, 0);
    
    return element;
}


@end
