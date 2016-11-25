//
//  MMChecklistTests.m
//  MMMarkdown
//
//  Created by Liam Xu on 25/11/2016.
//
//

#import <XCTest/XCTest.h>
#import "MMTestCase.h"

@interface MMChecklistTests : XCTestCase

@end

@implementation MMChecklistTests

#pragma mark - Tests

- (void)testBasicChecklist_bulletedWithDashes
{
    NSString *markdown = @"- [ ] One\n"
    "- [ ] Two\n"
    "- [ ] Three\n";
    NSString *html = @"<ul class=\"contains-task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /> One</li><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /> Two</li><li class=\"task-list-item\"> <input type=\"checkbox\" class=\"task-list-item-checkbox\" /> Three</li></ul>";
    
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist ,markdown, html);
}


- (void)testBasicChecklist_bulletedWithStars
{
    NSString *markdown = @"* [ ] One\n"
    "* [ ] Two\n"
    "* [ ] Three\n";
    NSString *html = @"<ul class=\"contains-task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /> One</li><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /> Two</li><li class=\"task-list-item\"> <input type=\"checkbox\" class=\"task-list-item-checkbox\" /> Three</li></ul>";
    
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist ,markdown, html);
}


- (void)testBasicChecklist_numbered
{
    NSString *markdown = @"0. [ ] One\n"
    "1. [ ] Two\n"
    "2. [ ] Three\n";
    NSString *html = @"<ol class=\"contains-task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /> One</li><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /> Two</li><li class=\"task-list-item\"> <input type=\"checkbox\" class=\"task-list-item-checkbox\" /> Three</li></ol>";
    
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist ,markdown, html);
}


- (void)testBasicChecklist_bulletedWithDashes_checked
{
    NSString *markdown = @"- [X] One\n"
    "- [x] Two\n"
    "- [ ] Three\n";
    NSString *html = @"<ul class=\"contains-task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" checked=\"\" /> One</li><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" checked=\"\" /> Two</li><li class=\"task-list-item\"> <input type=\"checkbox\" class=\"task-list-item-checkbox\" /> Three</li></ul>";
    
    
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist ,markdown, html);
}


- (void)testBasicChecklist_bulletedWithStars_checked
{
    NSString *markdown = @"* [ ] One\n"
    "* [x] Two\n"
    "* [X] Three\n";
    NSString *html = @"<ul class=\"contains-task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /> One</li><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" checked=\"\" /> Two</li><li class=\"task-list-item\"> <input type=\"checkbox\" class=\"task-list-item-checkbox\" checked=\"\" /> Three</li></ul>";
    
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist ,markdown, html);
}


- (void)testBasicChecklist_numbered_checked
{
    NSString *markdown = @"0. [x] One\n"
    "1. [ ] Two\n"
    "2. [X] Three\n";
    NSString *html = @"<ol class=\"contains-task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" checked=\"\"/> One</li><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /> Two</li><li class=\"task-list-item\"> <input type=\"checkbox\" class=\"task-list-item-checkbox\" checked=\"\"/> Three</li></ol>";
    
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist ,markdown, html);
}


- (void)testBasicChecklist_bulletedWithParagraphs
{
    NSString *markdown = @"- [ ] One\n"
    "\n"
    "- [ ] Two\n"
    "\n"
    "- [ ] Three\n";
    NSString *html = @"<ul class=\"contains-task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /> <p>One</p></li>"
    "<li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /> <p>Two</p></li>"
    "<li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /> <p>Three</p></li></ul>";
    
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist ,markdown, html);
}


- (void)testChecklist_carriageReturn
{
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"- [ ] One\r- [ ] Two\r", @"<ul class=\"contains-task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /> One</li>\n<li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /> Two</li></ul>");
}


- (void)testInvalidChecklist_emptylist
{
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"- [ ]\n- [ ]\n- [ ]\n", @"<ul>\n<li>[ ]</li>\n<li>[ ]</li>\n<li>[ ]</li>\n</ul>");
}

- (void)testValidChecklist_emptylist
{
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"- [ ] \n- [ ] \n- [ ] \n", @"<ul class=\"contains-task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /></li><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /></li><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /></li>\n</ul>");
}

- (void)testNestedChecklists
{
    NSString *markdown = @"- [ ] 1\n"
    "  - [ ] A\n"
    "  - [ ] B\n"
    "- [ ] 2\n"
    "- [ ] 3\n";
    
    NSString *html = @"<ul class=\"contains-task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /> 1\n<ul class=\"contains-task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /> A</li><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /> B</li></ul></li>"
    "<li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /> 2</li>"
    "<li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /> 3</li></ul>";
    
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, markdown, html);
}


- (void)testNestedChecklists_checked
{
    NSString *markdown = @"- [ ] 1\n"
    "  - [X] A\n"
    "  - [x] B\n"
    "- [ ] 2\n"
    "- [ ] 3\n";
    
    NSString *html = @"<ul class=\"contains-task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /> 1\n<ul class=\"contains-task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" checked=\"\"/> A</li><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" checked=\"\"/> B</li></ul></li>"
    "<li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /> 2</li>"
    "<li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /> 3</li></ul>";
    
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, markdown, html);
}



- (void)testNestedChecklists_multipleLevels_checked
{
    NSString *markdown = @"- [ ] 1\n"
    "  - [X] A\n"
    "    - [ ] X\n"
    "    - [X] Y\n"
    "  - [x] B\n"
    "- [ ] 2\n"
    "- [ ] 3\n";
    
    NSString *html = @"<ul class=\"contains-task-list\">"
    "<li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /> 1\n"
    "<ul class=\"contains-task-list\">"
        "<li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" checked=\"\"/> A\n"
            "<ul class=\"contains-task-list\">"
                "<li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\"/> X</li>"
                "<li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" checked=\"\"/> Y</li>"
            "</ul>"
        "</li>"
        "<li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" checked=\"\"/> B</li>"
    "</ul>"
    "</li>"
    "<li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /> 2</li>"
    "<li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /> 3</li></ul>";
    
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, markdown, html);
}


- (void)testChecklist_followedByHorizontalRule
{
    NSString *markdown = @"* [ ] One\n"
    "* [ ] Two\n"
    "* [ ] Three\n"
    "\n"
    " * * * ";
    NSString *html = @"<ul class=\"contains-task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /> One</li>"
    "<li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /> Two</li>"
    "<li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\" /> Three</li></ul>"
    "<hr />";
    
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, markdown, html);
}

- (void)testChecklist_invalidMarker
{
    // First element
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"*[]One\n",  @"<p>*[]One</p>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"-[]One\n",  @"<p>-[]One</p>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"+[]One\n",  @"<p>+[]One</p>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"1.[]One\n", @"<p>1.[]One</p>");
    
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"* []One\n",  @"<ul><li>[]One</li></ul>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"- []One\n",  @"<ul><li>[]One</li></ul>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"+ []One\n",  @"<ul><li>[]One</li></ul>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"1. []One\n", @"<ol><li>[]One</li></ol>");

    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"*[ ]One\n",  @"<p>*[ ]One</p>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"-[ ]One\n",  @"<p>-[ ]One</p>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"+[ ]One\n",  @"<p>+[ ]One</p>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"1.[ ]One\n", @"<p>1.[ ]One</p>");

    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"*[] One\n",  @"<p>*[] One</p>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"-[] One\n",  @"<p>-[] One</p>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"+[] One\n",  @"<p>+[] One</p>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"1.[] One\n", @"<p>1.[] One</p>");

    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"* [ ]One\n",  @"<ul><li>[ ]One</li></ul>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"- [ ]One\n",  @"<ul><li>[ ]One</li></ul>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"+ [ ]One\n",  @"<ul><li>[ ]One</li></ul>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"1. [ ]One\n", @"<ol><li>[ ]One</li></ol>");

    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"* [] One\n",  @"<ul><li>[] One</li></ul>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"- [] One\n",  @"<ul><li>[] One</li></ul>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"+ [] One\n",  @"<ul><li>[] One</li></ul>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"1. [] One\n", @"<ol><li>[] One</li></ol>");

    // Second element
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"*[ ] One\n*Two",   @"<p>*[ ] One\n*Two</p>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"-[ ] One\n-Two",   @"<p>-[ ] One\n-Two</p>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"+[ ] One\n+Two",   @"<p>+[ ] One\n+Two</p>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"1.[ ] One\n1.Two", @"<p>1.[ ] One\n1.Two</p>");
    
    // Check with tabs
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"*\t[]One\n",  @"<ul><li>[]One</li></ul>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"-\t[]One\n",  @"<ul><li>[]One</li></ul>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"+\t[]One\n",  @"<ul><li>[]One</li></ul>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"1.\t[]One\n", @"<ol><li>[]One</li></ol>");

    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"*\t[ ] One\n",  @"<ul><li>[ ] One</li></ul>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"-\t[ ] One\n",  @"<ul><li>[ ] One</li></ul>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"+\t[ ] One\n",  @"<ul><li>[ ] One</li></ul>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"1.\t[ ] One\n", @"<ol><li>[ ] One</li></ol>");

  
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"1. [\t] One\n", @"<ol><li>[    ] One</li></ol>");

}


- (void)testChecklist_validMarker
{
    
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"* [ ]\tOne\n",  @"<ul class=\"contains-task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\"></input> One</li></ul>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"- [ ]\tOne\n",  @"<ul class=\"contains-task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\"></input> One</li></ul>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"+ [ ]\tOne\n",  @"<ul class=\"contains-task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\"></input> One</li></ul>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"1. [ ]\tOne\n", @"<ol class=\"contains-task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\"></input> One</li></ol>");
    
#warning these suppose to be invalid checklist items according to Github
    
    //
    // these suppose to be invalid checklist items
    // but seems that _removeTabsFromString function made it works.
    //
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"* [\t] One\n",  @"<ul class=\"contains-task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\"></input> One</li></ul>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"- [\t] One\n",  @"<ul class=\"contains-task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\"></input> One</li></ul>");
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"+ [\t] One\n",  @"<ul class=\"contains-task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\"></input> One</li></ul>");
}


- (void)testChecklist_withLeadingSpace
{
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @" - [ ] One\n - [ ] Two", @"<ul class=\"contains-task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\"></input> One</li><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\"></input> Two</li></ul>");
}

- (void)testChecklist_withBold
{
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"- [ ] One **Bold**\n- [ ] Two", @"<ul class=\"contains-task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\"></input> One <strong>Bold</strong></li><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\"></input> Two</li></ul>");
}

- (void)testChecklist_withCode
{
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, @"- [ ] One `Code`\n- [ ] Two", @"<ul class=\"contains-task-list\"><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\"></input> One <code>Code</code></li><li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\"></input> Two</li></ul>");
}


- (void)testChecklistFollowingAnotherChecklist
{
    NSString *markdown =
    @"- [ ] A\n"
    "- [ ] B\n"
    "\n"
    "1. [ ] 1\n"
    "1. [ ] 2\n";
    NSString *HTML =
    @"<ul class=\"contains-task-list\">"
    "   <li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\"></input> A</li>"
    "   <li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\"></input> B</li>"
    "</ul>"
    "<ol class=\"contains-task-list\">"
    "   <li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\"></input> 1</li>"
    "   <li class=\"task-list-item\"><input type=\"checkbox\" class=\"task-list-item-checkbox\"></input> 2</li>"
    "</ol>";
    MMAssertExtendedMarkdownEqualsHTML(MMMarkdownExtensionsChecklist, markdown, HTML);
}

@end
