# MMMarkdown
MMMarkdown is an Objective-C static library for converting [Markdown][] to HTML. It is compatible with OS X 10.6+ and iOS 5.0+, and is written using ARC.

Unlike other Markdown libraries, MMMarkdown implements an actual parser. It is not a port of the original Perl implementation and does not use regular expressions to transform the input into HTML. MMMarkdown tries to be efficient and minimize memory usage.

[Markdown]: http://daringfireball.net/projects/markdown/

## API
Using MMMarkdown is simple. The main API is a single class method:

    #import <MMMarkdown/MMMarkdown.h>
    
    NSError  *error;
    NSString *markdown   = @"# Example\nWhat a library!";
    NSString *htmlString = [MMMarkdown HTMLStringWithMarkdown:markdown error:&error];
    // Returns @"<h1>Example</h1>\n<p>What a library!</p>"

The markdown string that is passed in must be non-nil.

## Downloading
While the development branch (`master`) includes the headers and libraries from the latest release, it is recommended that you use the `release` branch unless you are working on MMMarkdown itself.

## Setup
Adding MMMarkdown to your Mac or iOS project is easy.

0. Add MMMarkdown as a git submodule. (`git submodule add https://github.com/mdiep/MMMarkdown <path>`)

0. Add `MMMarkdown.xcodeproj` to your project or workspace

0. Add `libMMMarkdown-Mac.a` or `libMMMarkdown-iOS.a` to the "Link Binary with Libraries" section of your project's "Build Phases".

0. Add `$(CONFIGURATION_BUILD_DIR)/MMMarkdown-Mac/public/` or `$(CONFIGURATION_BUILD_DIR)/MMMarkdown-iOS/public/` to the "Header Search Paths" in your project's "Build Settings".

## License
MMMarkdown is available under the [MIT License][].

[MIT License]: http://opensource.org/licenses/mit-license.php

## Roadmap
### 0.4 - Performance
This release will focus on the overall performance of MMMarkdown. It should be fast and require little memory.

### 0.5 - Configurability
Having ensured the correctness and performance of MMMarkdown, this release will expand the options accepted by the parser. Plans include a strict mode, which will complain about any parsing errors, and a mode that supports [MultiMarkdown][].

[MultiMarkdown]: http://fletcherpenney.net/multimarkdown/
