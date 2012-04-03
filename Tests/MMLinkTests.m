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
    
    [self checkMarkdown:markdown againstHTML:html];
}


//==================================================================================================
#pragma mark -
#pragma mark Inline Link Tests
//==================================================================================================

- (void) testBasicInlineLink
{
    [self checkMarkdown:@"[URL](/url/)" againstHTML:@"<p><a href=\"/url/\">URL</a></p>"];
}

- (void) testInlineLinkWithSpans
{
    [self checkMarkdown:@"[**A Title**](/the-url/)" againstHTML:@"<p><a href=\"/the-url/\"><strong>A Title</strong></a></p>"];
}

- (void) testInlineLinkWithEscapedBracket
{
    [self checkMarkdown:@"[\\]](/)" againstHTML:@"<p><a href=\"/\">]</a></p>"];
}

- (void) testInlineLinkWithNestedBrackets
{
    [self checkMarkdown:@"[ A [ title ] ](/foo)" againstHTML:@"<p><a href=\"/foo\"> A [ title ] </a></p>"];
}

- (void) testInlineLinkWithNestedParentheses
{
    [self checkMarkdown:@"[Apple](http://en.wikipedia.org/wiki/Apple_(disambiguation))"
            againstHTML:@"<p><a href=\"http://en.wikipedia.org/wiki/Apple_(disambiguation)\">Apple</a></p>"];
}

- (void) testInlineLinkWithTitle
{
    [self checkMarkdown:@"[URL](/url \"title\")"
            againstHTML:@"<p><a href=\"/url\" title=\"title\">URL</a></p>"];
}

- (void) testInlineLinkWithInlineLinkInside
{
    [self checkMarkdown:@"[ [URL](/blah) ](/url)"
            againstHTML:@"<p><a href=\"/url\"> [URL](/blah) </a></p>"];
}

- (void) testNotAnInlineLink_loneBracket
{
    [self checkMarkdown:@"An empty [ by itself" againstHTML:@"<p>An empty [ by itself</p>"];
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
    [self checkMarkdown:markdown againstHTML:html];
}

- (void) testReferenceLinkWithOneSpace
{
    NSString *markdown = @"Foo [bar] [1].\n"
                          "\n"
                          "[1]: /blah";
    NSString *html = @"<p>Foo <a href=\"/blah\">bar</a>.</p>";
    [self checkMarkdown:markdown againstHTML:html];
}

- (void) testReferenceLinkWithTitle
{
    NSString *markdown = @"Foo [bar][1].\n"
                          "\n"
                          "[1]: /blah \"blah\"";
    NSString *html = @"<p>Foo <a href=\"/blah\" title=\"blah\">bar</a>.</p>";
    [self checkMarkdown:markdown againstHTML:html];
}


@end
