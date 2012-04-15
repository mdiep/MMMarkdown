//
//  MMScanner.h
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

#import <Foundation/Foundation.h>


@interface MMScanner : NSObject

@property (strong, nonatomic, readonly) NSString *string;

@property (assign, nonatomic, readonly) NSUInteger startLocation;
@property (assign, nonatomic, readonly) NSRange    lineRange;
@property (assign, nonatomic) NSUInteger location;

+ (id) scannerWithString:(NSString *)aString;
- (id) initWithString:(NSString *)aString;

- (void) beginTransaction;
- (void) commitTransaction:(BOOL)shouldSave;

- (BOOL) atBeginningOfLine;
- (BOOL) atEndOfLine;
- (BOOL) atEndOfString;

- (unichar) nextCharacter;
- (NSString *) substringBeforeCharacter:(unichar)character;

- (void) advance;
- (void) advanceToNextLine;

- (NSUInteger) skipCharactersFromSet:(NSCharacterSet *)aSet;
- (NSUInteger) skipCharactersFromSet:(NSCharacterSet *)aSet max:(NSUInteger)maxToSkip;
- (NSUInteger) skipIndentationUpTo:(NSUInteger)maxSpacesToSkip;
- (NSUInteger) skipNestedBracketsWithDelimiter:(unichar)delimiter;
- (NSUInteger) skipToEndOfLine;
- (NSUInteger) skipToLastCharacterOfLine;

@end
