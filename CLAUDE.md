# SketchyVim Project Information

## Overview
SketchyVim is a macOS application that transforms accessible input fields into full vim buffers by synchronizing them with a real vim buffer using the libvim library.

## Key Features
- Full vim functionality in any macOS text field (all modes and commands)
- Custom configuration via `svimrc` file
- Application blacklisting via `~/.config/svim/blacklist`
- Integration with external tools via `~/.config/svim/svim.sh` script
- Requires macOS accessibility permissions

## Project Structure
- `src/` - Main source code (Objective-C and C)
- `lib/libvim.a` - Pre-compiled libvim library
- `lib/libvim/` - libvim header files
- `examples/` - Example configuration files
- `bin/` - Build output directory

## Build System
- Uses makefile for building
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
- Full text replacement is the standard approach
- Text updates require a small delay (15ms) for cursor positioning

## Important Notes
- "Accessible" means input fields must conform to macOS accessibility standards
- Some applications may need to be blacklisted if they break the accessibility API
- Safari generally has better text field accessibility than Firefox
- C files use Core Foundation, Objective-C files import full Cocoa framework
