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


@interface MMHTMLCode : MMTestCase

@end

@implementation MMHTMLCode

#pragma mark - Inline HTML Tests

- (void)testSingleLineCode
{
//  MMAssertMarkdownEqualsHTML(@"<http://example.com/?a=1&b=1>",
//                             @"<p><a href=\"http://example.com/?a=1&amp;b=1\">http://example.com/?a=1&amp;b=1</a></p>");
    MMAssertMarkdownEqualsHTML(@"```hello```", @"<p><code>hello</code></p>");
}

- (void)testMultiLineCode
{
  //  MMAssertMarkdownEqualsHTML(@"<http://example.com/?a=1&b=1>",
  //                             @"<p><a href=\"http://example.com/?a=1&amp;b=1\">http://example.com/?a=1&amp;b=1</a></p>");
  MMAssertMarkdownEqualsStringWithGithub(@"```\n" "print 'hello world'\n" "```", @"<pre><code>print 'hello world'\n"
          "</code></pre>\n");
}


@end
