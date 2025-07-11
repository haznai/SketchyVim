# SketchyVim Project Information

## Overview
SketchyVim is a macOS application that transforms accessible input fields into full vim buffers by synchronizing them with a real vim buffer using the libvim library.

## Key Features
- Full vim functionality in any macOS text field (all modes and commands)
- Custom configuration via `svimrc` file
- Application blacklisting via `~/.config/svim/blacklist`
- Integration with external tools via `~/.config/svim/svim.sh` script
- Requires macOS accessibility permissions

## Important Notes
- "Accessible" means input fields must conform to macOS accessibility standards
- Some applications may need to be blacklisted if they break the accessibility API
- Safari generally has better text field accessibility than Firefox
- C files use Core Foundation, Objective-C files import full Cocoa framework

## Project Structure
- `src/` - Main source code (Objective-C and C)
- `lib/libvim.a` - Pre-compiled libvim library
- `lib/libvim/` - libvim header files
- `examples/` - Example configuration files
- `bin/` - Build output directory

## Build System
- Uses makefile for building (`just make` to run)
- Output binary: `bin/svim`
- Homebrew formula available at `FelixKratz/formulae`
- Supports x86, arm64, and universal builds

## Architecture & Text Synchronization

### Core Components
1. **ax.c/ax.h** - Accessibility API interface
   - Handles macOS accessibility element interactions
   - Manages text field detection and role identification
   - Synchronizes between vim buffer and text fields

2. **buffer.c/buffer.h** - Vim buffer management
   - Maintains vim buffer state and text content
   - Tracks cursor position and selection
   - Handles mode changes (insert, normal, visual, command)
   - Implements change detection between buffer states

3. **event_tap.c** - Keyboard event interception
   - Captures keyboard events system-wide
   - Routes events to vim or passes them through

### Text Synchronization Flow
1. **Input Field → Vim**: `ax_get_text()` reads text from field, `buffer_revsync_text()` updates vim
2. **Vim → Input Field**: `ax_set_text()` replaces entire field content with vim buffer
3. **Cursor Sync**: Separate cursor position synchronization via `ax_set_cursor()`

### Key Functions
- `ax_set_text()` (ax.c:77-91) - Replaces entire text field content using `AXUIElementSetAttributeValue`
- `buffer_update_raw_text()` (buffer.c:31-113) - Detects changes in vim buffer
- `buffer_sync()` (buffer.c:197-206) - Main synchronization orchestrator


### macOS Accessibility API Limitations
- No reliable partial text replacement API
	-  -> `AXReplaceRangeWithText` exists but is undocumented and unreliable
	- maybe the problem is that i dont get attributed strings, or rather, i only edit on the plain text level? maybe if i could get and pass attributed strings the formatting in `notes` would remain the same: https://developer.apple.com/documentation/foundation/attributedstring

- Full text replacement is the standard approach
- Text updates require a small delay (15ms) for cursor positioning

## Current Task: Text Formatting Preservation Investigation

### Objective
Investigating whether it's possible to preserve rich text formatting (fonts, colors, styles) when synchronizing between vim buffer and macOS text fields, particularly in applications like Notes.app that support rich text editing.

### Problem Statement
Currently, `ax_set_text()` uses plain `CFStringCreateWithCString()` which strips ALL formatting when syncing vim changes back to the text field. This causes rich formatting in Notes.app to be lost during vim editing sessions.

### Key Findings from Accessibility API Investigation

#### Available Rich Text Data
The macOS Accessibility API provides comprehensive formatting information through `kAXAttributedStringForRangeAttribute`:

1. **Semantic Formatting**:
   - Style names like "Title, Contains paragraphs, Expanded"
   - List structure with `AXListItemLevel`, `AXListItemPrefix`, `AXListItemIndex`

2. **Visual Formatting**:
   - Font family, name, and size (e.g., ".AppleSystemUIFontEmphasized", 23.33pt)
   - Text color as CGColor with RGB values
   - Text alignment values

3. **Structured Content**:
   - Different ranges have different attribute sets
   - Effective ranges show where formatting applies
   - Hierarchical list information preserved

#### Debug Implementation Details
Added comprehensive debugging in `ax_get_text()` (ax.c:31-156):
- `debug_print_attributed_text()` function extracts all formatting attributes
- Uses Core Foundation APIs (`CFAttributedStringGetAttributes`, `CFDictionaryGetKeysAndValues`)
- Samples attributes at multiple positions to show formatting ranges
- Compatible with C compilation (no Objective-C required)

#### Example Debug Output
```
[DEBUG] ==> Attributed Text Debug Info <==
[DEBUG] CFTypeRef Type: CFAttributedString (ID: 62)
[DEBUG] Attributed string plain text length: 80
[DEBUG] Plain text: 'todo
this is a list, hehee


this is monocode

this is a heading

this is bold'
[DEBUG] Attributed string length: 80
[DEBUG]   Position 0: 4 attributes, effective range (0, 5)
[DEBUG]     AXForegroundColor: <CGColor 0x600002e2c000> [<CGColorSpace 0x600002e3db00> (kCGColorSpaceICCBased; kCGColorSpaceModelRGB; Generic RGB Profile)] ( 0.271 0.271 0.271 1 )
[DEBUG]     AXFont: {
    AXFontFamily = ".AppleSystemUIFont";
    AXFontName = ".AppleSystemUIFontEmphasized";
    AXFontSize = "23.33333333333334";
    AXVisibleName = "System Font Emphasized";
}
[DEBUG]     AXATextAlignmentValue: <CFNumber 0x8fb1597241c3fc1e [0x1f6798120]>{value = +0, type = kCFNumberSInt64Type}
[DEBUG]     AXStyleName: <CFString 0x600001f6e380 [0x1f6798120]>{contents = "Title, Contains paragraphs, Expanded"}
[DEBUG]   Position 8: 6 attributes, effective range (5, 24)
[DEBUG]     AXListItemLevel: <CFNumber 0x8fb1597241c3fc1e [0x1f6798120]>{value = +0, type = kCFNumberSInt64Type}
[DEBUG]     AXForegroundColor: <CGColor 0x600002e2c060> [<CGColorSpace 0x600002e3db00> (kCGColorSpaceICCBased; kCGColorSpaceModelRGB; Generic RGB Profile)] ( 0.271 0.271 0.271 1 )
[DEBUG]     AXListItemPrefix: dash 0x600000a3d2a0 {} Len 4
[DEBUG]     AXFont: {
    AXFontFamily = ".AppleSystemUIFont";
    AXFontName = ".AppleSystemUIFont";
    AXFontSize = "15.16666666666667";
    AXVisibleName = "System Font Regular";
}
[DEBUG]     AXATextAlignmentValue: <CFNumber 0x8fb1597241c3fc1e [0x1f6798120]>{value = +0, type = kCFNumberSInt64Type}
[DEBUG]     AXListItemIndex: <CFNumber 0x8fb1597241c3fd1e [0x1f6798120]>{value = +2, type = kCFNumberSInt64Type}
[DEBUG] ==> End Attributed Text Debug <==
```

#### Current Limitations
- `ax_set_text()` only accepts plain strings, destroying all formatting
- No mechanism to reconstruct or preserve attribute ranges during vim sync
- Rich text applications lose formatting completely during vim editing

#### Potential Solutions
0. Look into the scroll solution and if i want to adapt it, maybe it's a good TypeWriter Mode hack :)
1. Store original attributed text structure before vim sync
2. Implement attributed string creation when setting text back
3. Map vim editing operations to preserve attribute ranges where possible
4. Consider partial text replacement strategies for small edits

## Development Workflow
- Now using justfiles for all commands
  - Replaced traditional makefiles with just (a command runner)
  - Simplifies build, test, and deployment processes
  - Provides more flexible and readable command definitions
