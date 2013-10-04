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
#import "MMHTMLParser.h"
#import "MMScanner.h"
#import "MMSpanParser.h"

static NSString * __HTMLEntityForCharacter(unichar character)
{
    switch (character)
    {
        case '&':
            return @"&amp;";
        case '<':
            return @"&lt;";
        case '>':
            return @"&gt;";
        default:
            return @"";
    }
}

@interface MMParser ()
@property (strong, nonatomic) MMHTMLParser *htmlParser;
@property (strong, nonatomic) MMSpanParser *spanParser;
@end

@implementation MMParser

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
        self.spanParser = [MMSpanParser new];
    }
    
    return self;
}


//==================================================================================================
#pragma mark -
#pragma mark Public Methods
//==================================================================================================

- (MMDocument *)parseMarkdown:(NSString *)markdown error:(__autoreleasing NSError **)error
{
    // It would be better to not replace all the tabs with spaces. But this will do for now.
    markdown = [self _removeTabsFromString:markdown];
    
    MMScanner  *scanner  = [MMScanner scannerWithString:markdown];
    MMDocument *document = [MMDocument documentWithMarkdown:markdown];
    
    document.elements = [self _parseElementsWithScanner:scanner];
    [self _updateLinksFromDefinitionsInDocument:document];
    
    return document;
}


//==================================================================================================
#pragma mark -
#pragma mark Private Methods
//==================================================================================================

// Add the remainder of the line as an inner range to the element.
//
// If the line contains the start of a multi-line HTML comment, then multiple lines will be added
// to the element.
- (void)_addTextLineToElement:(MMElement *)element withScanner:(MMScanner *)scanner
{
    NSCharacterSet *nonAngleSet = [[NSCharacterSet characterSetWithCharactersInString:@"<"] invertedSet];
    NSCharacterSet *nonDashSet  = [[NSCharacterSet characterSetWithCharactersInString:@"-"] invertedSet];
    
    NSRange lineRange = scanner.currentRange;
    
    // Check for an HTML comment, which could span blank lines
    [scanner beginTransaction];
    NSMutableArray *commentRanges = [NSMutableArray new];
    // Look for the start of a comment on the current line
    while (![scanner atEndOfLine])
    {
        [scanner skipCharactersFromSet:nonAngleSet];
        if ([scanner matchString:@"<!--"])
        {
            // Look for the end of the comment
            while (![scanner atEndOfString])
            {
                [scanner skipCharactersFromSet:nonDashSet];
                
                if ([scanner atEndOfLine])
                {
                    [commentRanges addObject:[NSValue valueWithRange:lineRange]];
                    [scanner advanceToNextLine];
                    lineRange = scanner.currentRange;
                    continue;
                }
                if ([scanner matchString:@"-->"])
                {
                    break;
                }
                [scanner advance];
            }
        }
        else
            [scanner advance];
    }
    [scanner commitTransaction:commentRanges.count > 0];
    if (commentRanges.count > 0)
    {
        for (NSValue *value in commentRanges)
        {
            [element addInnerRange:value.rangeValue];
        }
    }
    
    [element addInnerRange:lineRange];
    [scanner advanceToNextLine];
}

- (NSString *)_removeTabsFromString:(NSString *)aString
{
    NSMutableString *result = [aString mutableCopy];
    
    NSCharacterSet *tabAndNewline = [NSCharacterSet characterSetWithCharactersInString:@"\t\n"];
    
    NSRange searchRange = NSMakeRange(0, aString.length);
    NSRange resultRange;
    NSUInteger lineLocation;
    NSArray *strings = @[ @"", @" ", @"  ", @"   ", @"    " ];
    
    resultRange  = [result rangeOfCharacterFromSet:tabAndNewline options:0 range:searchRange];
    lineLocation = 0;
    while (resultRange.location != NSNotFound)
    {
        unichar character = [result characterAtIndex:resultRange.location];
        if (character == '\n')
        {
            lineLocation = 1 + resultRange.location;
            searchRange = NSMakeRange(lineLocation, result.length-lineLocation);
        }
        else
        {
            NSUInteger numOfSpaces = 4 - ((resultRange.location - lineLocation) % 4);
            [result replaceCharactersInRange:resultRange withString:[strings objectAtIndex:numOfSpaces]];
            searchRange = NSMakeRange(resultRange.location, result.length-resultRange.location);
        }
        resultRange = [result rangeOfCharacterFromSet:tabAndNewline options:0 range:searchRange];
    }
    
    return result;
}

- (NSArray *)_parseElementsWithScanner:(MMScanner *)scanner
{
    NSMutableArray *result = [NSMutableArray new];
    
    while (![scanner atEndOfString])
    {
        MMElement *element = [self _parseNextElementWithScanner:scanner];
        if (element)
        {
            [result addObject:element];
        }
        else
        {
            [scanner skipCharactersFromSet:[NSCharacterSet whitespaceCharacterSet]];
            if ([scanner atEndOfLine])
            {
                [scanner advanceToNextLine];
            }
        }
    }
    
    return result;
}


- (MMElement *)_parseNextElementWithScanner:(MMScanner *)scanner
{
    MMElement *element = [self _parseBlockElementWithScanner:scanner];
    
    if (element.innerRanges.count > 0)
    {
        MMScanner *innerScanner = [MMScanner scannerWithString:scanner.string lineRanges:element.innerRanges];
        if ([self _blockElementCanHaveChildren:element])
        {
            element.children = [self _parseElementsWithScanner:innerScanner];
        }
        else
        {
            element.children = [self.spanParser parseSpansWithScanner:innerScanner];
        }
    }
    
    return element;
}

- (BOOL)_blockElementCanHaveChildren:(MMElement *)anElement
{
    switch (anElement.type)
    {
        case MMElementTypeCodeBlock:
        case MMElementTypeParagraph:
        case MMElementTypeHeader:
            return NO;
            
        default:
            return YES;
    }
}

- (NSUInteger)_skipEmptyLinesWithScanner:(MMScanner *)scanner
{
    NSUInteger numOfLinesSkipped = 0;
    
    NSCharacterSet *whitespaceSet = [NSCharacterSet whitespaceCharacterSet];
    while (![scanner atEndOfString])
    {
        [scanner beginTransaction];
        [scanner skipCharactersFromSet:whitespaceSet];
        if (![scanner atEndOfLine])
        {
            [scanner commitTransaction:NO];
            break;
        }
        [scanner commitTransaction:YES];
        [scanner advanceToNextLine];
        numOfLinesSkipped++;
    }
    
    return numOfLinesSkipped;
}

- (MMElement *)_parseBlockElementWithScanner:(MMScanner *)scanner
{
    MMElement *element;
    
    [scanner beginTransaction];
    element = [self.htmlParser parseCommentWithScanner:scanner];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    [scanner beginTransaction];
    element = [self _parseHTMLWithScanner:scanner];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    [scanner beginTransaction];
    element = [self _parsePrefixHeaderWithScanner:scanner];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    [scanner beginTransaction];
    element = [self _parseUnderlinedHeaderWithScanner:scanner];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    [scanner beginTransaction];
    element = [self _parseBlockquoteWithScanner:scanner];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    // Check code first because its four-space behavior trumps most else
    [scanner beginTransaction];
    element = [self _parseCodeBlockWithScanner:scanner];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    // Check horizontal rules before lists since they both start with * or -
    [scanner beginTransaction];
    element = [self _parseHorizontalRuleWithScanner:scanner];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    [scanner beginTransaction];
    element = [self _parseListWithScanner:scanner atIndentationLevel:0];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    [scanner beginTransaction];
    element = [self _parseLinkDefinitionWithScanner:scanner];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    [scanner beginTransaction];
    element = [self _parseParagraphWithScanner:scanner];
    [scanner commitTransaction:element != nil];
    if (element)
        return element;
    
    return nil;
}

- (MMElement *)_parseHTMLWithScanner:(MMScanner *)scanner
{
    // At the beginning of the line
    if (![scanner atBeginningOfLine])
        return nil;
    
    return [self.htmlParser parseBlockTagWithScanner:scanner];
}

- (MMElement *)_parsePrefixHeaderWithScanner:(MMScanner *)scanner
{
    NSUInteger level = 0;
    while ([scanner nextCharacter] == '#' && level < 6)
    {
        level++;
        [scanner advance];
    }
    
    if (level == 0)
        return nil;
    
    [scanner skipCharactersFromSet:[NSCharacterSet whitespaceCharacterSet]];
    
    NSRange headerRange = scanner.currentRange;
    
    // Check for trailing #s
    while (headerRange.length > 0)
    {
        unichar character = [scanner.string characterAtIndex:NSMaxRange(headerRange)-1];
        if (character == '#')
            headerRange.length--;
        else
            break;
    }
    
    // Remove trailing whitespace
    NSCharacterSet *whitespaceSet = [NSCharacterSet whitespaceCharacterSet];
    while (headerRange.length > 0)
    {
        unichar character = [scanner.string characterAtIndex:NSMaxRange(headerRange)-1];
        if ([whitespaceSet characterIsMember:character])
            headerRange.length--;
        else
            break;
    }
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeHeader;
    element.range = NSMakeRange(scanner.startLocation, NSMaxRange(scanner.currentRange)-scanner.startLocation);
    element.level = level;
    [element addInnerRange:headerRange];
    
    [scanner advanceToNextLine];
    
    return element;
}

- (MMElement *)_parseUnderlinedHeaderWithScanner:(MMScanner *)scanner
{
    [scanner beginTransaction];
    
    // Make sure that the first line isn't empty
    [scanner skipCharactersFromSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([scanner atEndOfLine])
    {
        [scanner commitTransaction:NO];
        return nil;
    }
    
    [scanner advanceToNextLine];
    
    // There has to be more to the string
    if ([scanner atEndOfString])
    {
        [scanner commitTransaction:NO];
        return nil;
    }
    
    // The first character has to be a - or =
    unichar character = [scanner nextCharacter];
    if (character != '-' && character != '=')
    {
        [scanner commitTransaction:NO];
        return nil;
    }
    
    // Every other character must also be a - or =
    while (![scanner atEndOfLine])
    {
        if (character != [scanner nextCharacter])
        {
            // If it's not a - or =, check if it's just optional whitespace before the newline
            [scanner skipCharactersFromSet:[NSCharacterSet whitespaceCharacterSet]];
            if ([scanner atEndOfLine])
                break;
            
            [scanner commitTransaction:NO];
            return nil;
        }
        [scanner advance];
    }
    [scanner commitTransaction:NO];
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeHeader;
    element.level = character == '=' ? 1 : 2;
    [element addInnerRange:scanner.currentRange];
    
    [scanner advanceToNextLine]; // The header
    [scanner advanceToNextLine]; // The underlines
    
    element.range = NSMakeRange(scanner.startLocation, scanner.location-scanner.startLocation);
    
    return element;
}

- (MMElement *)_parseBlockquoteWithScanner:(MMScanner *)scanner
{
    // Skip up to 3 leading spaces
    NSCharacterSet *spaceCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@" "];
    [scanner skipCharactersFromSet:spaceCharacterSet max:3];
    
    // Must have a >
    if ([scanner nextCharacter] != '>')
        return nil;
    [scanner advance];
    
    // Can be followed by a space
    if ([scanner nextCharacter] == ' ')
        [scanner advance];
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeBlockquote;
    
    [element addInnerRange:scanner.currentRange];
    [scanner advanceToNextLine];
    
    // Parse each remaining line
    NSCharacterSet *whitespaceSet = [NSCharacterSet whitespaceCharacterSet];
    while (![scanner atEndOfString])
    {
        [scanner beginTransaction];
        [scanner skipCharactersFromSet:whitespaceSet];
        
        // It's a continuation of the blockquote unless it's a blank line
        if ([scanner atEndOfLine])
        {
            [scanner commitTransaction:NO];
            break;
        }
        
        // If there's a >, then skip it and an optional space
        if ([scanner nextCharacter] == '>')
        {
            [scanner advance];
            [scanner skipCharactersFromSet:whitespaceSet max:1];
        }
        
        [element addInnerRange:scanner.currentRange];
        
        [scanner commitTransaction:YES];
        [scanner advanceToNextLine];
    }
    
    element.range = NSMakeRange(scanner.startLocation, scanner.location-scanner.startLocation);
    
    return element;
}

- (MMElement *)_parseCodeBlockWithScanner:(MMScanner *)scanner
{
    NSUInteger indentation = [scanner skipIndentationUpTo:4];
    if (indentation != 4)
        return nil;
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeCodeBlock;
    
    [element addInnerRange:scanner.currentRange];
    [scanner advanceToNextLine];
    
    while (![scanner atEndOfString])
    {
        // Skip empty lines
        NSUInteger numOfEmptyLines = [self _skipEmptyLinesWithScanner:scanner];
        for (NSUInteger idx=0; idx<numOfEmptyLines; idx++)
        {
            [element addInnerRange:NSMakeRange(0, 0)];
        }
        
        // Need 4 spaces to continue the code block
        [scanner beginTransaction];
        NSUInteger indentation = [scanner skipIndentationUpTo:4];
        if (indentation < 4)
        {
            [scanner commitTransaction:NO];
            break;
        }
        [scanner commitTransaction:YES];
        
        [element addInnerRange:scanner.currentRange];
        [scanner advanceToNextLine];
    }
    
    // Remove any trailing blank lines
    while (element.innerRanges.count > 0 && [[element.innerRanges lastObject] rangeValue].length == 0)
    {
        [element removeLastInnerRange];
    }
    
    // Remove any trailing whitespace from the last line
    if (element.innerRanges.count > 0)
    {
        NSRange lineRange = [[element.innerRanges lastObject] rangeValue];
        [element removeLastInnerRange];
        
        NSCharacterSet *whitespaceSet = [NSCharacterSet whitespaceCharacterSet];
        while (lineRange.length > 0)
        {
            unichar character = [scanner.string characterAtIndex:NSMaxRange(lineRange)-1];
            if ([whitespaceSet characterIsMember:character])
                lineRange.length--;
            else
                break;
        }
        
        [element addInnerRange:lineRange];
    }
    
    // Add the text manually to avoid span parsing// Add the text manually here to avoid span parsing
    for (NSValue *value in element.innerRanges)
    {
        NSRange range = [value rangeValue];
        
        // &, <, and > need to be escaped
        NSCharacterSet *entities = [NSCharacterSet characterSetWithCharactersInString:@"&<>"];
        while (range.length > 0)
        {
            NSRange result    = [scanner.string rangeOfCharacterFromSet:entities options:0 range:range];
            NSRange textRange = result.location == NSNotFound ? range : NSMakeRange(range.location, result.location-range.location);
            
            // Add the text that was skipped over
            if (textRange.length > 0)
            {
                MMElement *text = [MMElement new];
                text.type  = MMElementTypeNone;
                text.range = textRange;
                [element addChild:text];
            }
            
            // Add the entity
            if (result.location != NSNotFound)
            {
                unichar    character = [scanner.string characterAtIndex:result.location];
                MMElement *entity    = [MMElement new];
                entity.type  = MMElementTypeEntity;
                entity.range = result;
                entity.stringValue = __HTMLEntityForCharacter(character);
                [element addChild:entity];
            }
            
            // Adjust the range
            if (result.location != NSNotFound)
            {
                range = NSMakeRange(NSMaxRange(result), NSMaxRange(range)-NSMaxRange(result));
            }
            else
            {
                range = NSMakeRange(NSMaxRange(textRange), NSMaxRange(range)-NSMaxRange(textRange));
            }
        }
        
        // Add a newline
        MMElement *newline = [MMElement new];
        newline.type  = MMElementTypeNone;
        newline.range = NSMakeRange(0, 0);
        [element addChild:newline];
    }
    element.innerRanges = nil;
    element.range = NSMakeRange(scanner.startLocation, scanner.location-scanner.startLocation);
    
    return element;
}

- (MMElement *)_parseHorizontalRuleWithScanner:(MMScanner *)scanner
{
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

- (BOOL)_parseListMarkerWithScanner:(MMScanner *)scanner
{
    // Look for a bullet
    [scanner beginTransaction];
    unichar nextChar = [scanner nextCharacter];
    if (nextChar == '*' || nextChar == '-' || nextChar == '+')
    {
        [scanner advance];
        if ([scanner nextCharacter] == ' ')
        {
            [scanner advance];
            [scanner commitTransaction:YES];
            return YES;
        }
    }
    [scanner commitTransaction:NO];
    
    // Look for a numbered item
    [scanner beginTransaction];
    NSUInteger numOfNums = [scanner skipCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet]];
    if (numOfNums != 0)
    {
        unichar nextChar = [scanner nextCharacter];
        if (nextChar == '.')
        {
            [scanner advance];
            if ([scanner nextCharacter] == ' ')
            {
                [scanner advance];
                [scanner commitTransaction:YES];
                return YES;
            }
        }
    }
    [scanner commitTransaction:NO];
    
    return NO;
}

- (MMElement *)_parseListItemWithScanner:(MMScanner *)scanner atIndentationLevel:(NSUInteger)level
{
    // Make sure there's enough leading space
    [scanner beginTransaction];
    NSUInteger toSkip  = 4 * level;
    NSUInteger skipped = [scanner skipIndentationUpTo:toSkip];
    if (skipped != toSkip)
    {
        [scanner commitTransaction:NO];
        return nil;
    }
    [scanner commitTransaction:YES];
    
    [scanner skipIndentationUpTo:3]; // Additional optional space
    
    BOOL foundAnItem = [self _parseListMarkerWithScanner:scanner];
    if (!foundAnItem)
        return nil;
    
    [scanner skipCharactersFromSet:[NSCharacterSet whitespaceCharacterSet]];
    
    MMElement *element = [MMElement new];
    element.type = MMElementTypeListItem;
    
    BOOL afterBlankLine = NO;
    NSCharacterSet *whitespaceSet = [NSCharacterSet whitespaceCharacterSet];
    while (![scanner atEndOfString])
    {
        // Skip over any empty lines
        [scanner beginTransaction];
        NSUInteger numOfEmptyLines = [self _skipEmptyLinesWithScanner:scanner];
        afterBlankLine = numOfEmptyLines != 0;
        
        // Check for the start of a new list item
        [scanner beginTransaction];
        [scanner skipIndentationUpTo:4*level + 3];
        BOOL newMarker = [self _parseListMarkerWithScanner:scanner];
        [scanner commitTransaction:NO];
        if (newMarker)
        {
            [scanner commitTransaction:NO];
            break;
        }
        
        // Check for a horizontal rule
        [scanner beginTransaction];
        BOOL newRule = [self _parseHorizontalRuleWithScanner:scanner] != nil;
        [scanner commitTransaction:NO];
        if (newRule)
        {
            [scanner commitTransaction:NO];
            break;
        }
        
        // Check for a nested list
        [scanner beginTransaction];
        MMElement *list = [self _parseListWithScanner:scanner atIndentationLevel:1+level];
        if (list)
        {
            [scanner commitTransaction:YES];
            if (element.children == nil)
                element.children = @[];
            if (element.innerRanges.count > 0)
            {
                MMScanner *innerScanner = [MMScanner scannerWithString:scanner.string lineRanges:element.innerRanges];
                element.children = [element.children arrayByAddingObjectsFromArray:[self _parseElementsWithScanner:innerScanner]];
                element.innerRanges = @[];
                
                // First add a newline so the nested list will start on its own line
                MMElement *newline = [MMElement new];
                newline.type  = MMElementTypeNone;
                newline.range = NSMakeRange(0, 0);
                element.children = [element.children arrayByAddingObject:newline];
            }
            element.children = [element.children arrayByAddingObject:list];
            continue;
        }
        [scanner commitTransaction:NO];
        
        if (afterBlankLine)
        {
            // Must be 4 spaces past the indentation level to start a new paragraph
            [scanner beginTransaction];
            NSUInteger newLevel    = 4*(1+level);
            NSUInteger indentation = [scanner skipIndentationUpTo:newLevel];
            if (indentation < newLevel)
            {
                [scanner commitTransaction:NO];
                [scanner commitTransaction:NO];
                break;
            }
            [scanner commitTransaction:YES];
            [scanner commitTransaction:YES];
            
            [element addInnerRange:NSMakeRange(0, 0)];
        }
        else
        {
            [scanner commitTransaction:YES];
            [scanner skipCharactersFromSet:whitespaceSet];
        }
        
        [self _addTextLineToElement:element withScanner:scanner];
    }
    
    element.range = NSMakeRange(scanner.startLocation, scanner.location-scanner.startLocation);
    
    return element;
}

- (MMElement *)_parseListWithScanner:(MMScanner *)scanner atIndentationLevel:(NSUInteger)level
{
    [scanner beginTransaction];
    // Check the amount of leading whitespace
    NSUInteger toSkip  = 4 * level;
    NSUInteger skipped = [scanner skipIndentationUpTo:toSkip];
    
    [scanner skipIndentationUpTo:3]; // Additional optional space
    unichar nextChar   = [scanner nextCharacter];
    BOOL    isBulleted = (nextChar == '*' || nextChar == '-' || nextChar == '+');
    BOOL    hasMarker  = [self _parseListMarkerWithScanner:scanner];
    [scanner commitTransaction:NO];
    
    if (toSkip != skipped || !hasMarker)
        return nil;
    
    MMElement *element = [MMElement new];
    element.type = isBulleted ? MMElementTypeBulletedList : MMElementTypeNumberedList;
    
    NSMutableArray *followedByBlankLine = [NSMutableArray new];
    
    while (![scanner atEndOfString])
    {
        // Skip over empty lines
        [scanner beginTransaction];
        NSUInteger numOfEmptyLines = [self _skipEmptyLinesWithScanner:scanner];
        BOOL hasBlankLine = (numOfEmptyLines != 0);
        
        // Check for a horizontal rule first -- they look like a list marker
        [scanner beginTransaction];
        MMElement *rule = [self _parseHorizontalRuleWithScanner:scanner];
        [scanner commitTransaction:NO];
        if (rule)
        {
            [scanner commitTransaction:NO];
            break;
        }
        
        [scanner beginTransaction];
        MMElement *item = [self _parseListItemWithScanner:scanner atIndentationLevel:level];
        if (!item)
        {
            [scanner commitTransaction:NO];
            [scanner commitTransaction:NO];
            break;
        }
        [scanner commitTransaction:YES];
        [scanner commitTransaction:YES];
        
        [followedByBlankLine addObject:@(hasBlankLine)];
        [element addChild:item];
        
        // Parse the spans inside the item
        if (!item.children)
            item.children = @[];
        if (item.innerRanges.count > 0)
        {
            MMScanner *innerScanner = [MMScanner scannerWithString:scanner.string lineRanges:item.innerRanges];
            item.children = [item.children arrayByAddingObjectsFromArray:[self _parseElementsWithScanner:innerScanner]];
        }
    }
    
    // Remove the first item because it will be whether there was an empty line before the first
    // item. We want to know if there's a blank line after. Removing the first item shifts
    // everything. Add a NO at the end because the last item is never followed by a blank line.
    [followedByBlankLine removeObjectAtIndex:0];
    [followedByBlankLine addObject:@(NO)];
    
    // Figure out if the items should have paragraphs. If it's not before/after a blank line, and it
    // doesn't have multiple paragraphs, then remove the paragraphs.
    __block BOOL isAfterBlankLine = NO;
    [element.children enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        BOOL isBeforeBlankLine = [[followedByBlankLine objectAtIndex:idx] boolValue];
        MMElement *item = obj;
        
        if (!isBeforeBlankLine && !isAfterBlankLine)
        {
            // check if it has multiple consecutive paragraphs
            BOOL shouldHavePs = NO;
            BOOL isAfterPType = NO;
            for (MMElement *child in item.children)
            {
                // This is somewhat deceptively named, but I couldn't come up with anything better.
                // Having any 2 elements in a row that are one of these types is enough to add
                // paragraphs to the list item.
                BOOL isPType = child.type == MMElementTypeParagraph
                            || child.type == MMElementTypeBlockquote
                            || child.type == MMElementTypeCodeBlock;
                if (isPType && isAfterPType)
                {
                    shouldHavePs = YES;
                    break;
                }
                isAfterPType = isPType;
            }
            
            if (!shouldHavePs)
            {
                NSMutableArray *newChildren = [NSMutableArray new];
                for (MMElement *child in item.children)
                {
                    if (child.type == MMElementTypeParagraph)
                        [newChildren addObjectsFromArray:child.children];
                    else
                        [newChildren addObject:child];
                }
                item.children = newChildren;
            }
        }
        
        isAfterBlankLine = isBeforeBlankLine;
    }];
    
    element.range = NSMakeRange(scanner.startLocation, scanner.location-scanner.startLocation);
    
    return element;
}

- (MMElement *)_parseLinkDefinitionWithScanner:(MMScanner *)scanner
{
    NSUInteger location;
    NSUInteger length;
    NSCharacterSet *whitespaceSet = [NSCharacterSet whitespaceCharacterSet];
    
    [scanner skipIndentationUpTo:3];
    
    // find the identifier
    location = scanner.location;
    length   = [scanner skipNestedBracketsWithDelimiter:'['];
    if (length == 0)
        return nil;
    
    NSRange idRange = NSMakeRange(location+1, length-2);
    
    // and the semicolon
    if ([scanner nextCharacter] != ':')
        return nil;
    [scanner advance];
    
    // skip any whitespace
    [scanner skipCharactersFromSet:whitespaceSet];
    
    // find the url
    location = scanner.location;
    [scanner skipCharactersFromSet:[whitespaceSet invertedSet]];
    
    NSRange   urlRange  = NSMakeRange(location, scanner.location-location);
    NSString *urlString = [scanner.string substringWithRange:urlRange];
    
    // Check if the URL is surrounded by angle brackets
    if ([urlString hasPrefix:@"<"] && [urlString hasSuffix:@">"])
    {
        urlString = [urlString substringWithRange:NSMakeRange(1, urlString.length-2)];
    }
    
    // skip trailing whitespace
    [scanner skipCharactersFromSet:whitespaceSet];
    
    // If at the end of the line, then try to find the title on the next line
    [scanner beginTransaction];
    if ([scanner atEndOfLine])
    {
        [scanner advanceToNextLine];
        [scanner skipCharactersFromSet:whitespaceSet];
    }
    
    // check for a title
    NSRange titleRange = NSMakeRange(NSNotFound, 0);
    unichar nextChar  = [scanner nextCharacter];
    if (nextChar == '"' || nextChar == '\'' || nextChar == '(')
    {
        [scanner advance];
        unichar endChar = (nextChar == '(') ? ')' : nextChar;
        NSUInteger titleLocation = scanner.location;
        NSUInteger titleLength   = [scanner skipToLastCharacterOfLine];
        if ([scanner nextCharacter] == endChar)
        {
            [scanner advance];
            titleRange = NSMakeRange(titleLocation, titleLength);
        }
    }
    
    [scanner commitTransaction:titleRange.location != NSNotFound];
    
    // skip trailing whitespace
    [scanner skipCharactersFromSet:whitespaceSet];
    
    // make sure we're at the end of the line
    if (![scanner atEndOfLine])
        return nil;
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeDefinition;
    element.range = NSMakeRange(scanner.startLocation, scanner.location-scanner.startLocation);
    element.identifier = [scanner.string substringWithRange:idRange];
    element.href       = urlString;
    
    if (titleRange.location != NSNotFound)
    {
        element.title = [scanner.string substringWithRange:titleRange];
    }
    
    return element;
}

- (MMElement *)_parseParagraphWithScanner:(MMScanner *)scanner
{
    NSCharacterSet *spaceCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@" "];
    [scanner skipCharactersFromSet:spaceCharacterSet max:3];
    
    if ([[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[scanner nextCharacter]])
        return nil;
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeParagraph;
    
    NSCharacterSet *whitespaceSet = [NSCharacterSet whitespaceCharacterSet];
    while (![scanner atEndOfString])
    {
        // Skip whitespace if it's the only thing on the line
        [scanner beginTransaction];
        [scanner skipCharactersFromSet:whitespaceSet];
        if ([scanner atEndOfLine])
        {
            [scanner commitTransaction:YES];
            [scanner advanceToNextLine];
            break;
        }
        [scanner commitTransaction:NO];
        
        // Check for a blockquote
        [scanner beginTransaction];
        [scanner skipCharactersFromSet:whitespaceSet];
        if ([scanner nextCharacter] == '>')
        {
            [scanner commitTransaction:YES];
            break;
        }
        [scanner commitTransaction:NO];
        
        MMElement *header;
        // Check for an underlined header
        [scanner beginTransaction];
        header = [self _parseUnderlinedHeaderWithScanner:scanner];
        [scanner commitTransaction:NO];
        if (header)
            break;
        
        // Also check for a prefixed header
        [scanner beginTransaction];
        header = [self _parsePrefixHeaderWithScanner:scanner];
        [scanner commitTransaction:NO];
        if (header)
            break;
        
        [self _addTextLineToElement:element withScanner:scanner];
    }
    
    element.range = NSMakeRange(scanner.startLocation, scanner.location-scanner.startLocation);
    
    return element;
}

- (void)_updateLinksFromDefinitionsInDocument:(MMDocument *)document
{
    NSMutableArray      *references  = [NSMutableArray new];
    NSMutableDictionary *definitions = [NSMutableDictionary new];
    NSMutableArray      *queue       = [NSMutableArray new];
    
    [queue addObjectsFromArray:document.elements];
    
    // First, find the references and definitions
    while (queue.count > 0)
    {
        MMElement *element = [queue objectAtIndex:0];
        [queue removeObjectAtIndex:0];
        [queue addObjectsFromArray:element.children];
        
        switch (element.type)
        {
            case MMElementTypeDefinition:
                [definitions setObject:element forKey:[element.identifier lowercaseString]];
                break;
            case MMElementTypeImage:
            case MMElementTypeLink:
                if (element.identifier && !element.href)
                {
                    [references addObject:element];
                }
                break;
            default:
                break;
        }
    }
    
    // Set the hrefs for all the references
    for (MMElement *link in references)
    {
        MMElement *definition = [definitions objectForKey:[link.identifier lowercaseString]];
        
        // If there's no definition, change the link to a text element and remove its children
        if (!definition)
        {
            link.type = MMElementTypeNone;
            while (link.children.count > 0)
            {
                [link removeLastChild];
            }
        }
        // otherwise, set the href and title
        {
            link.href  = definition.href;
            link.title = definition.title;
        }
    }
}


@end
