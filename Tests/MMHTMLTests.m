//
//  MMHTMLTests.m
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


@interface MMHTMLTests : MMTestCase

@end

@implementation MMHTMLTests

//==================================================================================================
#pragma mark -
#pragma mark Inline HTML Tests
//==================================================================================================

- (void) testInlineHTML
{
    MMAssertMarkdownEqualsHTML(@"A <i>test</i> with HTML.", @"<p>A <i>test</i> with HTML.</p>");
}


//==================================================================================================
#pragma mark -
#pragma mark Block HTML Tests
//==================================================================================================

- (void) testHTML_basic
{
    NSString *markdown = @"A paragraph.\n"
                          "\n"
                          "<div>\n"
                          "HTML!\n"
                          "</div>\n"
                          "\n"
                          "Another paragraph.\n";
    NSString *html = @"<p>A paragraph.</p>\n"
                      "\n"
                      "<div>\n"
                      "HTML!\n"
                      "</div>\n"
                      "\n"
                      "<p>Another paragraph.</p>";
    MMAssertMarkdownEqualsHTML(markdown, html);
}

- (void) testHTML_withSingleQuotedAttribute
{
    NSString *markdown = @"A paragraph.\n"
                          "\n"
                          "<div class='foo'>\n"
                          "HTML!\n"
                          "</div>\n"
                          "\n"
                          "Another paragraph.\n";
    NSString *html = @"<p>A paragraph.</p>\n"
                      "\n"
                      "<div class='foo'>\n"
                      "HTML!\n"
                      "</div>\n"
                      "\n"
                      "<p>Another paragraph.</p>";
    MMAssertMarkdownEqualsHTML(markdown, html);
}

- (void) testHTML_withDoubleQuotedAttribute
{
    NSString *markdown = @"A paragraph.\n"
                          "\n"
                          "<div class=\"foo\">\n"
                          "HTML!\n"
                          "</div>\n"
                          "\n"
                          "Another paragraph.\n";
    NSString *html = @"<p>A paragraph.</p>\n"
                      "\n"
                      "<div class=\"foo\">\n"
                      "HTML!\n"
                      "</div>\n"
                      "\n"
                      "<p>Another paragraph.</p>";
    MMAssertMarkdownEqualsHTML(markdown, html);
}


@end
