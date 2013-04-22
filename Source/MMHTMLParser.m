//
//  MMHTMLParser.m
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

#import "MMHTMLParser.h"


#import "MMElement.h"
#import "MMScanner.h"

@implementation MMHTMLParser

//==================================================================================================
#pragma mark -
#pragma mark Public Methods
//==================================================================================================

- (MMElement *)parseBlockTagWithScanner:(MMScanner *)scanner
{
    // which starts with a '<'
    if ([scanner nextCharacter] != '<')
        return nil;
    [scanner advance];
    
    NSSet *htmlBlockTags = [NSSet setWithObjects:
                            @"p", @"div", @"h1", @"h2", @"h3", @"h4", @"h5", @"h6",
                            @"blockquote", @"pre", @"table", @"dl", @"ol", @"ul",
                            @"script", @"noscript", @"form", @"fieldset", @"iframe",
                            @"math", @"ins", @"del", nil];
    NSString *tagName = [scanner nextWord];
    if (![htmlBlockTags containsObject:tagName])
        return nil;
    
    // Skip lines until we come across a blank line
    while (![scanner atEndOfLine])
    {
        [scanner advanceToNextLine];
    }
    
    MMElement *element = [MMElement new];
    element.type  = MMElementTypeHTML;
    element.range = NSMakeRange(scanner.startLocation, scanner.location-scanner.startLocation);
    
    return element;
}

- (MMElement *)parseInlineTagWithScanner:(MMScanner *)scanner
{
    if ([scanner nextCharacter] != '<')
        return nil;
    [scanner advance];
    
    if ([scanner nextCharacter] == '/')
        [scanner advance];
    
    NSRange tagNameRange = [self _parseNameWithScanner:scanner];
    if (tagNameRange.length == 0)
        return nil;
    
    [self _parseAttributesWithScanner:scanner];
    
    if ([scanner nextCharacter] != '>')
        return nil;
    [scanner advance];
    
    MMElement *element = [MMElement new];
    element.type        = MMElementTypeHTML;
    element.range       = NSMakeRange(scanner.startLocation, scanner.location-scanner.startLocation);
    element.stringValue = [scanner.string substringWithRange:tagNameRange];
    
    return element;
}


//==================================================================================================
#pragma mark -
#pragma mark Private Methods
//==================================================================================================

- (NSRange)_parseNameWithScanner:(MMScanner *)scanner
{
    NSMutableCharacterSet *nameSet = [NSMutableCharacterSet alphanumericCharacterSet];
    [nameSet addCharactersInString:@":"];
    
    NSRange result = NSMakeRange(scanner.location, 0);
    result.length = [scanner skipCharactersFromSet:nameSet];
    
    return result;
}

- (BOOL)_parseStringWithScanner:(MMScanner *)scanner
{
    unichar nextChar = [scanner nextCharacter];
    if (nextChar != '"' && nextChar != '\'')
        return NO;
    [scanner advance];
    
    while ([scanner nextCharacter] != nextChar)
    {
        if ([scanner atEndOfLine])
        {
            [scanner advanceToNextLine];
            continue;
        }
        
        if ([scanner atEndOfString])
            return NO;
        
        [scanner advance];
    }
    
    // skip over the closing quotation mark
    [scanner advance];
    
    return YES;
}

- (BOOL)_parseAttributeValueWithScanner:(MMScanner *)scanner
{
    NSMutableCharacterSet *characters = [[NSCharacterSet.whitespaceCharacterSet invertedSet] mutableCopy];
    [characters removeCharactersInString:@"\"'=><`"];
    
    return [scanner skipCharactersFromSet:characters] > 0;
}

- (void)_parseAttributesWithScanner:(MMScanner *)scanner
{
    while ([scanner skipWhitespaceAndNewlines] > 0)
    {
        NSRange range;
        
        range = [self _parseNameWithScanner:scanner];
        if (range.length == 0)
            break;
        
        [scanner skipWhitespace];
        
        if ([scanner nextCharacter] != '=')
            break;
        [scanner advance];
        
        [scanner skipWhitespace];
        
        if ([self _parseStringWithScanner:scanner])
            ;
        else if ([self _parseAttributeValueWithScanner:scanner])
            ;
        else
            break;
    }
}


@end
