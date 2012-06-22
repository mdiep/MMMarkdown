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

- (void) testInlineHTMLWithSpansInAttribute
{
    MMAssertMarkdownEqualsHTML(@"<a href=\"#\" title=\"*blah*\">foo</a>",
                               @"<p><a href=\"#\" title=\"*blah*\">foo</a></p>");
}

#if RUN_KNOWN_FAILURES
- (void) testInlineHTMLWithSpansInUnquotedAttribute
{
    MMAssertMarkdownEqualsString(@"<a href=\"#\" title=*blah*>foo</a>",
                                 @"<p><a href=\"#\" title=*blah*>foo</a></p>");
}
#endif

- (void) testInlineHTMLWithSpansAndValuelessAttribute
{
    MMAssertMarkdownEqualsHTML(@"<input type=\"checkbox\" name=\"*foo*\" checked />",
                               @"<p><input type=\"checkbox\" name=\"*foo*\" checked /></p>");
}

#if RUN_KNOWN_FAILURES
- (void) testInlineHTMLThatSpansANewlineWithSpansInAttribute
{
    MMAssertMarkdownEqualsHTML(@"<a href=\"#\"\n   title=\"*blah*\">foo</a>",
                               @"<p><a href=\"#\"\n   title=\"*blah*\">foo</a></p>");
}
#endif

- (void) testInlineHTMLWithAngleInAttribute
{
    MMAssertMarkdownEqualsHTML(@"<a href=\"#\" title=\">\">foo</a>",
                               @"<p><a href=\"#\" title=\">\">foo</a></p>");
}

#if RUN_KNOWN_FAILURES
- (void) testInlineHTMLWithInsTag
{
    // <ins> can be both block- and span-level
    MMAssertMarkdownEqualsHTML(@"<ins>Some text.</ins>", @"<p><ins>Some text.</ins></p>");
}
#endif

#if RUN_KNOWN_FAILURES
- (void) testInlineHTMLWithDelTag
{
    // <del> can be both block- and span-level
    MMAssertMarkdownEqualsHTML(@"<del>Some text.</del>", @"<p><del>Some text.</del></p>");
}
#endif


//==================================================================================================
#pragma mark -
#pragma mark Block HTML Tests
//==================================================================================================

- (void) testBlockHTML_basic
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

- (void) testBlockHTML_withSingleQuotedAttribute
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

- (void) testBlockHTML_withDoubleQuotedAttribute
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

- (void) testBlockHTMLWithInsTag
{
    MMAssertMarkdownEqualsHTML(@"<ins>\nSome text.\n</ins>", @"<ins>\nSome text.\n</ins>");
}

- (void) testBlockHTMLWithDelTag
{
    MMAssertMarkdownEqualsHTML(@"<del>\nSome text.\n</del>", @"<del>\nSome text.\n</del>");
}

- (void) testBlockHTMLOnASingleLine
{
    MMAssertMarkdownEqualsHTML(@"<div>A test.</div>", @"<div>A test.</div>");
}

#if RUN_KNOWN_FAILURES
- (void) testBlockHTMLBlankLineBetweenCloseTags
{
    // Primitive HTML handling might end the HTML block after the first div, since it's a close tag
    // followed by a blank line. But the block should extend to the end of the opening div.
    NSString *html = @"<div>\n"
                      "<div>\n"
                      "A\n"
                      "</div>\n"
                      "\n"
                      "</div>\n";
    MMAssertMarkdownEqualsHTML(html, html);
}
#endif

- (void) testBlockHTMLCommentWithSpans
{
    // An SGML comment starts and ends with "--", so you can't have an odd number of dashes before
    // the closing angle bracket.
    MMAssertMarkdownEqualsHTML(@"<!------> *hello*-->", @"<!------> *hello*-->");
}


@end
