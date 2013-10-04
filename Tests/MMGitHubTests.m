//
//  MMGitHubTests.m
//  MMMarkdown
//
//  Copyright (c) 2013 Matt Diephouse.
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


#define MMAssertGitHubMarkdownEqualsHTML(markdown, html) \
    do { \
        @try {\
            id a1value = (markdown); \
            id a2value = (html); \
            \
            NSError *error; \
            NSString *output = [MMMarkdown HTMLStringWithGitHubFlavoredMarkdown:a1value error:&error]; \
            NSString *html2  = a2value;\
            \
            /* Add root elements for parsing */ \
            output = [NSString stringWithFormat:@"<test>%@</test>", output]; \
            html2  = [NSString stringWithFormat:@"<test>%@</test>", html2]; \
            \
            NSXMLDocument *actual   = [[NSXMLDocument alloc] initWithXMLString:output options:0 error:nil]; \
            NSXMLDocument *expected = [[NSXMLDocument alloc] initWithXMLString:html2  options:0 error:nil]; \
            \
            if (actual != expected) { \
                if ([(id)actual isEqual:(id)expected]) \
                    continue; \
                [self failWithException:([NSException failureInEqualityBetweenObject:actual \
                                                                           andObject:expected \
                                                                              inFile:[NSString stringWithUTF8String:__FILE__] \
                                                                              atLine:__LINE__ \
                            withDescription:@"Markdown output doesn't match expected HTML"])]; \
            } \
        }\
        @catch (id anException) {\
            [self failWithException:([NSException failureInRaise:[NSString stringWithFormat:@"(%s) == (%s)", #markdown, #html] \
                          exception:anException \
                             inFile:[NSString stringWithUTF8String:__FILE__] \
                             atLine:__LINE__ \
                    withDescription:@"Markdown output doesn't match expected HTML"])]; \
        }\
    } while(0)

@interface MMGitHubTests : MMTestCase

@end

@implementation MMGitHubTests

//==================================================================================================
#pragma mark -
#pragma mark Multiple Underscores in Words Tests
//==================================================================================================

- (void)testMultipleUnderscoresInWords
{
    MMAssertGitHubMarkdownEqualsHTML(@"perform_complicated_task", @"<p>perform_complicated_task</p>");
    MMAssertGitHubMarkdownEqualsHTML(@"do_this_and_do_that_and_another_thing", @"<p>do_this_and_do_that_and_another_thing</p>");
}

- (void)testEmAtBeginningOfString
{
    MMAssertGitHubMarkdownEqualsHTML(@"_test_", @"<p><em>test</em></p>");
}

- (void)testEmEndsInWord
{
    MMAssertGitHubMarkdownEqualsHTML(@"_test_of", @"<p>_test_of</p>");
}

- (void)testEmWithUnderscoreInTheWord
{
    MMAssertGitHubMarkdownEqualsHTML(@"_a_test_", @"<p><em>a_test</em></p>");
}

//==================================================================================================
#pragma mark -
#pragma mark URL Autolinking Tests
//==================================================================================================

- (void)testURLAutolinkingWithStandardMarkdown
{
    MMAssertMarkdownEqualsHTML(@"https://github.com", @"<p>https://github.com</p>");
}

- (void)testURLAutolinkingInsideLink
{
    MMAssertGitHubMarkdownEqualsHTML(
        @"[https://github.com](https://github.com)",
        @"<p><a href='https://github.com'>https://github.com</a></p>"
    );
}

- (void)testURLAutolinkingWithHTTPS
{
    MMAssertGitHubMarkdownEqualsHTML(
        @"Check out https://github.com/mdiep.",
        @"<p>Check out <a href='https://github.com/mdiep'>https://github.com/mdiep</a>.</p>"
    );
}

- (void)testURLAutolinkingWithHTTP
{
    MMAssertGitHubMarkdownEqualsHTML(
        @"Go to http://github.com and sign up!",
        @"<p>Go to <a href='http://github.com'>http://github.com</a> and sign up!</p>"
    );
}

- (void)testURLAutolinkingWithFTP
{
    MMAssertGitHubMarkdownEqualsHTML(
        @"Download ftp://example.com/blah.txt.",
        @"<p>Download <a href='ftp://example.com/blah.txt'>ftp://example.com/blah.txt</a>.</p>"
    );
}

- (void)testURLAutolinkingWithEmailAddress
{
    MMAssertGitHubMarkdownEqualsHTML(
        @"Email me at matt@diephouse.com.",
        @"<p>Email me at <a href='mailto:matt@diephouse.com'>matt@diephouse.com</a>.</p>"
    );
}

- (void)testURLAutolinkingWithEmailAddressStartingWithUnderscore
{
    MMAssertGitHubMarkdownEqualsHTML(
        @"_blah_blah@blah.com",
        @"<p><a href='mailto:_blah_blah@blah.com'>_blah_blah@blah.com</a></p>"
    );
}

- (void)testURLAutolinkingWithEmailAddressInItalics
{
    MMAssertGitHubMarkdownEqualsHTML(@"_matt@diephouse.com_", @"<p><em><a href='mailto:matt@diephouse.com'>matt@diephouse.com</a></em></p>");
}

- (void)testURLAutolinkingWithWWW
{
    MMAssertGitHubMarkdownEqualsHTML(@"www.github.com", @"<p><a href='http://www.github.com'>www.github.com</a></p>");
    MMAssertGitHubMarkdownEqualsHTML(@"www.github.com/mdiep", @"<p><a href='http://www.github.com/mdiep'>www.github.com/mdiep</a></p>");
}

- (void)testURLAutolinkingWithParentheses
{
    MMAssertGitHubMarkdownEqualsHTML(
        @"foo http://www.pokemon.com/Pikachu_(Electric) bar",
        @"<p>foo <a href='http://www.pokemon.com/Pikachu_(Electric)'>http://www.pokemon.com/Pikachu_(Electric)</a> bar</p>"
    );
    
    MMAssertGitHubMarkdownEqualsHTML(
        @"foo http://www.pokemon.com/Pikachu_(Electric)) bar",
        @"<p>foo <a href='http://www.pokemon.com/Pikachu_(Electric)'>http://www.pokemon.com/Pikachu_(Electric)</a>) bar</p>"
    );
}

//==================================================================================================
#pragma mark -
#pragma mark Strikethrough Tests
//==================================================================================================

- (void)testStrikethroughWithStandardMarkdown
{
    MMAssertMarkdownEqualsHTML(@"~~Mistaken text.~~", @"<p>~~Mistaken text.~~</p>");
}

- (void)testStrikethroughBasic
{
    MMAssertGitHubMarkdownEqualsHTML(@"~~Mistaken text.~~", @"<p><del>Mistaken text.</del></p>");
}

- (void)testStrikethroughWithStrong
{
    MMAssertGitHubMarkdownEqualsHTML(@"~~**Mistaken text.**~~", @"<p><del><strong>Mistaken text.</strong></del></p>");
}

//==================================================================================================
#pragma mark -
#pragma mark Fenced Code Block Tests
//==================================================================================================

- (void)testFencedCodeBlockWithStandardMarkdown
{
    MMAssertMarkdownEqualsHTML(@"```\nblah\n```", @"<p><code>\nblah\n</code></p>");
}

- (void)testBasicFencedCodeBlock
{
    MMAssertGitHubMarkdownEqualsHTML(@"```\nblah\n```", @"<pre><code>blah\n</code></pre>");
}

- (void)testFencedCodeBlockWithEntity
{
    MMAssertGitHubMarkdownEqualsHTML(@"```\na&b\n```", @"<pre><code>a&amp;b\n</code></pre>");
}

- (void)testFencedCodeBlockAfterBlankLine
{
    MMAssertGitHubMarkdownEqualsHTML(@"Test\n\n```\nblah\n```", @"<p>Test</p><pre><code>blah\n</code></pre>");
}

- (void)testFencedCodeBlockWithoutBlankLine
{
    MMAssertGitHubMarkdownEqualsHTML(@"Test\n```\nblah\n```", @"<p>Test</p><pre><code>blah\n</code></pre>");
}

- (void)testFencedCodeBlockWithLanguage
{
    MMAssertGitHubMarkdownEqualsHTML(@"```objc\nblah\n```", @"<pre><code>blah\n</code></pre>");
}

- (void)testFencedCodeBlockInsideBlockquote
{
    MMAssertGitHubMarkdownEqualsHTML(@"> ```\n> test\n> ```", @"<blockquote><pre><code>test\n</code></pre></blockquote>");
}

@end
