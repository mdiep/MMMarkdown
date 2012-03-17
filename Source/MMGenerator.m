//
//  MMGenerator.m
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

#import "MMGenerator.h"


#import "MMDocument.h"
#import "MMElement.h"

// This value is used to estimate the length of the HTML output. The length of the markdown document
// is multplied by it to create an NSMutableString with an initial capacity.
static const Float64 kHTMLDocumentLengthMultiplier = 1.25;

static NSString * __HTMLStartTagForElement(MMElement *anElement)
{
    switch (anElement.type)
    {
        case MMElementTypeHeader:
            return [NSString stringWithFormat:@"<h%u>", anElement.level];
        case MMElementTypeParagraph:
            return @"<p>";
        case MMElementTypeBulletedList:
            return @"<ul>\n";
        case MMElementTypeNumberedList:
            return @"<ol>\n";
        case MMElementTypeListItem:
            return @"<li>";
        case MMElementTypeBlockquote:
            return @"<blockquote>\n";
        case MMElementTypeCodeBlock:
            return @"<pre><code>";
        case MMElementTypeHorizontalRule:
            return @"\n<hr />\n";
        case MMElementTypeStrongAndEm:
            return @"<strong><em>";
        case MMElementTypeCodeSpan:
            return @"<code>";
        case MMElementTypeLink:
            return [NSString stringWithFormat:@"<a href=\"%@\">", anElement.href];
        default:
            return nil;
    }
}

static NSString * __HTMLEndTagForElement(MMElement *anElement)
{
    switch (anElement.type)
    {
        case MMElementTypeHeader:
            return [NSString stringWithFormat:@"</h%u>\n", anElement.level];
        case MMElementTypeParagraph:
            return @"</p>\n";
        case MMElementTypeBulletedList:
            return @"</ul>\n";
        case MMElementTypeNumberedList:
            return @"</ol>\n";
        case MMElementTypeListItem:
            return @"</li>\n";
        case MMElementTypeBlockquote:
            return @"</blockquote>\n";
        case MMElementTypeCodeBlock:
            return @"\n</code></pre>\n";
        case MMElementTypeStrongAndEm:
            return @"</em></strong>";
        case MMElementTypeCodeSpan:
            return @"</code>";
        case MMElementTypeLink:
            return @"</a>";
        default:
            return nil;
    }
}

@interface MMGenerator ()
- (void) _generateHTMLForElement:(MMElement *)anElement
                      inDocument:(MMDocument *)aDocument
                            HTML:(NSMutableString *)theHTML
                        location:(NSUInteger *)aLocation;
@end

@implementation MMGenerator

//==================================================================================================
#pragma mark -
#pragma mark Public Methods
//==================================================================================================

- (NSString *) generateHTML:(MMDocument *)aDocument
{
    NSString   *markdown = aDocument.markdown;
    NSUInteger  location = 0;
    NSUInteger  length   = markdown.length;
    
    NSMutableString *HTML = [NSMutableString stringWithCapacity:length * kHTMLDocumentLengthMultiplier];
    
    for (MMElement *element in aDocument.elements)
    {
        if (element.type == MMElementTypeHTML)
        {
            [HTML appendString:[aDocument.markdown substringWithRange:element.range]];
        }
        else
        {
            [self _generateHTMLForElement:element
                               inDocument:aDocument
                                 HTML:HTML
                             location:&location];
        }
    }
    
    return HTML;
}


//==================================================================================================
#pragma mark -
#pragma mark Public Methods
//==================================================================================================

- (void) _generateHTMLForElement:(MMElement *)anElement
                      inDocument:(MMDocument *)aDocument
                            HTML:(NSMutableString *)theHTML
                        location:(NSUInteger *)aLocation
{
    NSString *startTag = __HTMLStartTagForElement(anElement);
    NSString *endTag   = __HTMLEndTagForElement(anElement);
    
    if (startTag)
        [theHTML appendString:startTag];
    
    for (MMElement *child in anElement.children)
    {
        if (child.type == MMElementTypeNone)
        {
            NSString *markdown = aDocument.markdown;
            if (child.range.length == 0)
            {
                [theHTML appendString:@"\n"];
            }
            else
            {
                [theHTML appendString:[markdown substringWithRange:child.range]];
            }
        }
        else
        {
            [self _generateHTMLForElement:child
                               inDocument:aDocument
                                     HTML:theHTML
                                 location:aLocation];
        }
    }
    
    if (endTag)
        [theHTML appendString:endTag];
}


@end
