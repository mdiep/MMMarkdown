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


@interface MMEscapingTests : MMTestCase

@end

@implementation MMEscapingTests

//==================================================================================================
#pragma mark -
#pragma mark Tests
//==================================================================================================

- (void) testEncodeAmpersand
{
    [self checkMarkdown:@"A & B" againstHTML:@"<p>A &amp; B</p>"];
}

- (void) testEncodeLeftAngleBracket
{
    [self checkMarkdown:@"2 << 0 < 2 << 1" againstHTML:@"<p>2 &lt;&lt; 0 &lt; 2 &lt;&lt; 1</p>"];
}

- (void) testHTMLEntityReferences
{
    [self checkMarkdown:@"A &amp; B" againstHTML:@"<p>A &amp; B</p>"];
    [self checkMarkdown:@"A &#38; B" againstHTML:@"<p>A &#38; B</p>"];
}


@end
