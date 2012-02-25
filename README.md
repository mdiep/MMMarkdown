# MMMarkdown
MMMarkdown is an Objective-C [Markdown][] static library, compatible with OS X 10.6+ and iOS 5.0+. It is written using ARC.

[Markdown]: http://daringfireball.net/projects/markdown/

## API
    #import "MMMarkdown.h"
    
    NSString *markdown   = @"# Example\nWhat a library!";
    NSString *htmlString = [MMMarkdown HTMLStringWithMarkdown:markdown error:nil];
    // Returns "<h1>Example</h1><p>What a library!</p>"

## Setup

## License
MMMarkdown is available under the [MIT License][].

[MIT License]: http://opensource.org/licenses/mit-license.php