//
//  MMSpanTests.m
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


@interface MMSpanTests : MMTestCase

@end

@implementation MMSpanTests

//==================================================================================================
#pragma mark -
#pragma mark Tests
//==================================================================================================

- (void) testBackslashEscapes
{
    // double-escape everything
    NSString *markdown = @"\\\\ \\` \\* \\_ \\{ \\} \\[ \\] \\( \\) \\> \\# \\. \\! \\+ \\-";
    NSString *html = @"<p>\\ ` * _ { } [ ] ( ) > # . ! + -</p>";
    
    MMAssertMarkdownEqualsHTML(markdown, html);
}

- (void) testCodeSpans
{
    NSString *markdown = @"`*Test* \\\\ code`\n";
    NSString *html = @"<p><code>*Test* \\\\ code</code></p>";
    
    MMAssertMarkdownEqualsHTML(markdown, html);
}

- (void) testCodeSpans_withSpaces
{
    NSString *markdown = @"a ` b ` c";
    NSString *html = @"<p>a <code>b</code> c</p>";
    
    MMAssertMarkdownEqualsHTML(markdown, html);
}

- (void) testCodeSpans_doubleBackticks
{
    NSString *markdown = @"`` `foo` ``\n";
    NSString *html = @"<p><code>`foo`</code></p>";
    
    MMAssertMarkdownEqualsHTML(markdown, html);
}

- (void) testEm
{
    MMAssertMarkdownEqualsHTML(@"*foo*", @"<p><em>foo</em></p>");
}

- (void) testEmAcrossNewline
{
    MMAssertMarkdownEqualsHTML(@"*Foo\nbar*", @"<p><em>Foo\nbar</em></p>");
}

- (void) testStrong
{
    MMAssertMarkdownEqualsHTML(@"**foo**", @"<p><strong>foo</strong></p>");
}

- (void) testStrongAcrossNewline
{
    MMAssertMarkdownEqualsHTML(@"**Foo\nbar**", @"<p><strong>Foo\nbar</strong></p>");
}

- (void) testStrongEm
{
    MMAssertMarkdownEqualsHTML(@"***foo***", @"<p><strong><em>foo</em></strong></p>");
}


@end
