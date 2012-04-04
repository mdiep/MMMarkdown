//
//  MMListTests.m
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

#import "MMTestCase.h"


@interface MMBlockTests : MMTestCase

@end

@implementation MMBlockTests

//==================================================================================================
#pragma mark -
#pragma mark Code Block Tests
//==================================================================================================

- (void) testCodeBlocks_blankLinesInBetween
{
    NSString *markdown = @"    Some Code\n"
                          "\n"
                          "    More Code\n";
    NSString *html = @"<pre><code>Some Code\n"
                      "\n"
                      "More Code\n"
                      "</code></pre>";
    
    MMAssertMarkdownEqualsHTML(markdown, html);
}

- (void) testCodeBlocks_blankLinesInBetween_betweenParagraphs
{
    NSString *markdown = @"Foo\n"
                          "\n"
                          "    Some\n"
                          "\n"
                          "    Code\n"
                          "\n"
                          "    Here\n"
                          "\n"
                          "Bar\n";
    NSString *html = @"<p>Foo</p>\n"
                      "\n"
                      "<pre><code>Some\n"
                      "\n"
                      "Code\n"
                      "\n"
                      "Here\n"
                      "</code></pre>\n"
                      "\n"
                      "<p>Bar</p>";
    
    MMAssertMarkdownEqualsHTML(markdown, html);
}

- (void) testCodeBlocks_withTabs
{
    // Tabs inside code blocks should be converted to spaces
    NSString *markdown = @"\t+\tSome Code\n";
    NSString *html = @"<pre><code>+   Some Code\n"
                      "</code></pre>";
    
    MMAssertMarkdownEqualsHTML(markdown, html);
}


//==================================================================================================
#pragma mark -
#pragma mark Paragraph Tests
//==================================================================================================

- (void) testParagraphs_hangingIndent
{
    // Tabs should be converted to spaces
    NSString *markdown = @"A Paragraph\n    Here\n";
    NSString *html = @"<p>A Paragraph\n"
                      "    Here</p>";
    
    MMAssertMarkdownEqualsHTML(markdown, html);
}

- (void) testParagraphs_withTabs
{
    // Tabs should be converted to spaces
    NSString *markdown = @"A\tParagraph\n\tHere\n";
    NSString *html = @"<p>A   Paragraph\n"
                      "    Here</p>";
    
    MMAssertMarkdownEqualsHTML(markdown, html);
}


@end
