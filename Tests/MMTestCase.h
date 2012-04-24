//
//  MMTestCase.h
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

#import <SenTestingKit/SenTestingKit.h>


#import "MMMarkdown.h"

#define MMAssertMarkdownEqualsHTML(markdown, html) \
    do { \
        @try {\
            id a1value = (markdown); \
            id a2value = (html); \
            \
            NSError *error; \
            NSString *output = [MMMarkdown HTMLStringWithMarkdown:a1value error:&error]; \
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
                            withDescription:@"HTML doesn't match expected value"])]; \
            } \
        }\
        @catch (id anException) {\
            [self failWithException:([NSException failureInRaise:[NSString stringWithFormat:@"(%s) == (%s)", #markdown, #html] \
                          exception:anException \
                             inFile:[NSString stringWithUTF8String:__FILE__] \
                             atLine:__LINE__ \
                    withDescription:@"HTML doesn't match expected value"])]; \
        }\
    } while(0)

@interface MMTestCase : SenTestCase

@end
