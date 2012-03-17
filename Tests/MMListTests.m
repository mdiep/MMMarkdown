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


@interface MMListTests : MMTestCase

@end

@implementation MMListTests

//==================================================================================================
#pragma mark -
#pragma mark Tests
//==================================================================================================

- (void) testBasicList_bulletedWithStars
{
    NSString *markdown = @"* One\n"
                          "* Two\n"
                          "* Three\n";
    NSString *html = @"<ul><li>One</li><li>Two</li><li>Three</li></ul>";
    
    [self checkMarkdown:markdown againstHTML:html];
}

- (void) testBasicList_bulletedWithDashes
{
    NSString *markdown = @"- One\n"
                          "- Two\n"
                          "- Three\n";
    NSString *html = @"<ul><li>One</li><li>Two</li><li>Three</li></ul>";
    
    [self checkMarkdown:markdown againstHTML:html];
}

- (void) testBasicList_numbered
{
    NSString *markdown = @"0. One\n"
                          "1. Two\n"
                          "0. Three\n";
    NSString *html = @"<ol><li>One</li><li>Two</li><li>Three</li></ol>";
    
    [self checkMarkdown:markdown againstHTML:html];
}

- (void) testList_bulletedWithParagraphs
{
    NSString *markdown = @"- One\n"
                          "\n"
                          "- Two\n"
                          "\n"
                          "- Three\n";
    NSString *html = @"<ul><li><p>One</p></li>"
                      "<li><p>Two</p></li>"
                      "<li><p>Three</p></li></ul>";
    
    [self checkMarkdown:markdown againstHTML:html];
}

- (void) testList_multipleParagraphs
{
    NSString *markdown = @"- One\n"
                          "\n"
                          "    More\n"
                          "- Two\n"
                          "- Three\n";
    NSString *html = @"<ul><li><p>One</p><p>More</p></li>"
                      "<li><p>Two</p></li>"
                      "<li><p>Three</p></li></ul>";
    
    [self checkMarkdown:markdown againstHTML:html];
}

- (void) testList_hangingIndents
{
    NSString *markdown = @"*   Lorem ipsum dolor sit amet, consectetuer adipiscing elit.\n"
                          "Aliquam hendrerit mi posuere lectus. Vestibulum enim wisi,\n"
                          "viverra nec, fringilla in, laoreet vitae, risus.\n"
                          "*   Donec sit amet nisl. Aliquam semper ipsum sit amet velit.\n"
                          "Suspendisse id sem consectetuer libero luctus adipiscing.\n";
    NSString *html = @"<ul>\n"
                      "<li>Lorem ipsum dolor sit amet, consectetuer adipiscing elit.\n"
                      "Aliquam hendrerit mi posuere lectus. Vestibulum enim wisi,\n"
                      "viverra nec, fringilla in, laoreet vitae, risus.</li>\n"
                      "<li>Donec sit amet nisl. Aliquam semper ipsum sit amet velit.\n"
                      "Suspendisse id sem consectetuer libero luctus adipiscing.</li>\n"
                      "</ul>\n";
    
    [self checkMarkdown:markdown againstHTML:html];
}

- (void) testNestedLists
{
    NSString *markdown = @"- One\n"
                          "    * A\n"
                          "    * B\n"
                          "- Two\n"
                          "- Three\n";
    NSString *html = @"<ul><li>One\n<ul><li>A</li><li>B</li></ul></li>"
                      "<li>Two</li>"
                      "<li>Three</li></ul>";
    
    [self checkMarkdown:markdown againstHTML:html];
}

- (void) testNestedLists_multipleParagraphs
{
    NSString *markdown = @"- One\n"
                          "\n"
                          "- Two\n"
                          "    * A\n"
                          "    * B\n"
                          "\n"
                          "- Three\n";
    NSString *html = @"<ul><li><p>One</p></li>"
                      "<li><p>Two</p><ul><li>A</li><li>B</li></ul></li>"
                      "<li><p>Three</p></li></ul>";
    
    [self checkMarkdown:markdown againstHTML:html];
}

- (void) testNestedLists_multipleLevels
{
    NSString *markdown = @"- One\n"
                          "\n"
                          "- Two\n"
                          "    * A\n"
                          "        - I\n"
                          "    * B\n"
                          "\n"
                          "- Three\n";
    NSString *html = @"<ul><li><p>One</p></li>"
                      "<li><p>Two</p><ul><li>A\n<ul><li>I</li></ul></li><li>B</li></ul></li>"
                      "<li><p>Three</p></li></ul>";
    
    [self checkMarkdown:markdown againstHTML:html];
}

- (void) testNestedLists_trailingNested
{
    NSString *markdown = @"- One\n"
                          "- Two\n"
                          "    * A\n"
                          "    * B\n"
                          "\n"
                          "New Paragraph\n";
    NSString *html = @"<ul><li>One</li>"
                      "<li>Two\n<ul><li>A</li><li>B</li></ul></li></ul>"
                      "<p>New Paragraph</p>";
    
    [self checkMarkdown:markdown againstHTML:html];
    
}

- (void) testList_followedByHorizontalRule
{
    NSString *markdown = @"* One\n"
                          "* Two\n"
                          "* Three\n"
                          "\n"
                          " * * * ";
    NSString *html = @"<ul><li>One</li>"
                      "<li>Two</li>"
                      "<li>Three</li></ul>"
                      "<hr />";
    
    [self checkMarkdown:markdown againstHTML:html];
}

- (void) testList_mustHaveWhitespaceAfterMarker
{
    // First element
    [self checkMarkdown:@"*One\n" againstHTML:@"<p>*One</p>"];
    [self checkMarkdown:@"-One\n" againstHTML:@"<p>-One</p>"];
    [self checkMarkdown:@"+One\n" againstHTML:@"<p>+One</p>"];
    [self checkMarkdown:@"1.One\n" againstHTML:@"<p>1.One</p>"];
    
    // Second element
    [self checkMarkdown:@"* One\n*Two" againstHTML:@"<ul><li>One\n*Two</li></ul>"];
    [self checkMarkdown:@"- One\n-Two" againstHTML:@"<ul><li>One\n-Two</li></ul>"];
    [self checkMarkdown:@"+ One\n+Two" againstHTML:@"<ul><li>One\n+Two</li></ul>"];
    [self checkMarkdown:@"1. One\n1.Two" againstHTML:@"<ol><li>One\n1.Two</li></ol>"];

    // Check with tabs
    [self checkMarkdown:@"*\tOne\n" againstHTML:@"<ul><li>One</li></ul>"];
    [self checkMarkdown:@"-\tOne\n" againstHTML:@"<ul><li>One</li></ul>"];
    [self checkMarkdown:@"+\tOne\n" againstHTML:@"<ul><li>One</li></ul>"];
    [self checkMarkdown:@"1.\tOne\n" againstHTML:@"<ol><li>One</li></ol>"];
}


@end
