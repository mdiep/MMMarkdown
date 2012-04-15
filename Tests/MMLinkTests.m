//
//  MMEscapingTests.m
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


@interface MMLinkTests : MMTestCase

@end 

@implementation MMLinkTests

//==================================================================================================
#pragma mark -
#pragma mark Automatic Link Tests
//==================================================================================================

- (void) testBasicAutomaticLink
{
    NSString *markdown = @"<http://daringfireball.net>";
    NSString *html = @"<p><a href='http://daringfireball.net'>http://daringfireball.net</a></p>";
    
    MMAssertMarkdownEqualsHTML(markdown, html);
}

- (void) testAutomaticLinkWithAmpersand
{
    MMAssertMarkdownEqualsHTML(@"<http://example.com/?a=1&b=1>",
                               @"<p><a href=\"http://example.com/?a=1&amp;b=1\">http://example.com/?a=1&amp;b=1</a></p>");
}


//==================================================================================================
#pragma mark -
#pragma mark Inline Link Tests
//==================================================================================================

- (void) testBasicInlineLink
{
    MMAssertMarkdownEqualsHTML(@"[URL](/url/)", @"<p><a href=\"/url/\">URL</a></p>");
}

- (void) testInlineLinkWithSpans
{
    MMAssertMarkdownEqualsHTML(@"[***A Title***](/the-url/)", @"<p><a href=\"/the-url/\"><strong><em>A Title</em></strong></a></p>");
}

- (void) testInlineLinkWithEscapedBracket
{
    MMAssertMarkdownEqualsHTML(@"[\\]](/)", @"<p><a href=\"/\">]</a></p>");
}

- (void) testInlineLinkWithNestedBrackets
{
    MMAssertMarkdownEqualsHTML(@"[ A [ title ] ](/foo)", @"<p><a href=\"/foo\"> A [ title ] </a></p>");
}

- (void) testInlineLinkWithNestedParentheses
{
    MMAssertMarkdownEqualsHTML(@"[Apple](http://en.wikipedia.org/wiki/Apple_(disambiguation))",
                               @"<p><a href=\"http://en.wikipedia.org/wiki/Apple_(disambiguation)\">Apple</a></p>");
}

- (void) testInlineLinkWithURLInAngleBrackets
{
    MMAssertMarkdownEqualsHTML(@"[Foo](<bar>)", @"<p><a href=\"bar\">Foo</a></p>");
}

- (void) testInlineLinkWithTitle
{
    MMAssertMarkdownEqualsHTML(@"[URL](/url \"title\")",
                               @"<p><a href=\"/url\" title=\"title\">URL</a></p>");
}

- (void) testInlineLinkWithQuoteInTitle
{
    MMAssertMarkdownEqualsHTML(@"[Foo](/bar \"a \" in the title\")",
                               @"<p><a href=\"/bar\" title=\"a &quot; in the title\">Foo</a></p>");
}

- (void) testInlineLinkWithAmpersandInTitle
{
    MMAssertMarkdownEqualsHTML(@"[Foo](bar \"&baz\")", @"<p><a href=\"bar\" title=\"&amp;baz\">Foo</a></p>");
}

- (void) testInlineLinkWithInlineLinkInside
{
    MMAssertMarkdownEqualsHTML(@"[ [URL](/blah) ](/url)",
                               @"<p><a href=\"/url\"> [URL](/blah) </a></p>");
}

- (void) testInlineLinkWithNoHref
{
    MMAssertMarkdownEqualsHTML(@"[foo]()", @"<p><a href=\"\">foo</a></p>");
}

- (void) testNotAnInlineLink_loneBracket
{
    MMAssertMarkdownEqualsHTML(@"An empty [ by itself", @"<p>An empty [ by itself</p>");
}


//==================================================================================================
#pragma mark -
#pragma mark Reference Link Tests
//==================================================================================================

- (void) testBasicReferenceLink
{
    NSString *markdown = @"Foo [bar][1].\n"
                          "\n"
                          "[1]: /blah";
    NSString *html = @"<p>Foo <a href=\"/blah\">bar</a>.</p>";
    MMAssertMarkdownEqualsHTML(markdown, html);
}

- (void) testReferenceLinkWithOneSpace
{
    NSString *markdown = @"Foo [bar] [1].\n"
                          "\n"
                          "[1]: /blah";
    NSString *html = @"<p>Foo <a href=\"/blah\">bar</a>.</p>";
    MMAssertMarkdownEqualsHTML(markdown, html);
}

- (void) testReferenceLinkWithDifferentCapitalization
{
    NSString *markdown = @"[Foo][BaR]\n"
                          "\n"
                          "[bAr]: /blah";
    NSString *html = @"<p><a href=\"/blah\">Foo</a></p>";
    MMAssertMarkdownEqualsHTML(markdown, html);
}

- (void) testReferenceLinkWithTitle
{
    NSString *markdown = @"Foo [bar][1].\n"
                          "\n"
                          "[1]: /blah \"blah\"";
    NSString *html = @"<p>Foo <a href=\"/blah\" title=\"blah\">bar</a>.</p>";
    MMAssertMarkdownEqualsHTML(markdown, html);
}

- (void) testReferenceLinkWithQuoteInTitle
{
    NSString *markdown = @"[Foo][]\n"
                          "\n"
                          "[foo]: /bar \"a \" in the title\"";
    NSString *html = @"<p><a href=\"/bar\" title=\"a &quot; in the title\">Foo</a></p>";
    MMAssertMarkdownEqualsHTML(markdown, html);
}

- (void) testReferenceLinkWithNoReference
{
    MMAssertMarkdownEqualsHTML(@"[Foo][bar]", @"<p>[Foo][bar]</p>");
}


@end
