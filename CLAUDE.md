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

## Text Formatting Preservation: Investigation Summary

### Problem Statement
Notes.app and other rich text applications lose ALL formatting when SketchyVim syncs vim buffer changes back to the text field. This completely breaks the user experience in rich text environments.

### Core Issue: AXError -25201 (kAXErrorIllegalArgument)
Line-based vim operations (`o`, `dd`, `dj`, visual mode `d`) consistently fail with attributed strings, causing complete app breakage in Notes.app. Character-level edits in monospace blocks work fine.

### What We've Learned

#### 1. Accessibility API Capabilities
- **Reading**: Can extract full attributed strings with `AXAttributedStringForRange`
- **Writing**: `AXUIElementSetAttributeValue` accepts `CFAttributedStringRef` but has strict rules
- **Attributes Available**: Semantic (AXStyleName, AXListItem*) and Visual (AXFont, AXForegroundColor)

#### 2. Notes.app Behavior Patterns
- **Character edits in monospace blocks**: Attributed strings accepted ✓
- **Line operations on headings/lists**: Attributed strings rejected with -25201 ✗
- **Plain text fallback**: Completely breaks Notes.app ("f's the whole app") ✗

#### 3. Failed Approaches Attempted

**Approach 1: Semantic vs Visual Attribute Filtering**
- Tried filtering out semantic attributes (AXStyleName, AXListItem*) 
- Kept only visual attributes (AXFont, AXForegroundColor)
- Result: Still failed on line operations

**Approach 2: Length-Based Logic**
- Same length = use attributed strings (formatting preserved)
- Different length = use plain text (structural changes)
- Result: Plain text mode breaks Notes.app completely

**Approach 3: Vim Command Interception**
- Intercept `o` command, replace with `A` + system Enter keypress
- Intercept `dd` command, replace with native selection + delete
- Result: Overcomplicated, breaks vim semantics

**Approach 4: Post-Operation Detection**
- Detect newline structure changes after vim operations
- Switch between attributed/plain based on structural analysis
- Result: Complex heuristics, unreliable

**Approach 5: Proper Attribute Reconstruction**
- Store original attributed string with all ranges/attributes
- Reconstruct with `CFAttributedStringSetAttributes()` for same-length text
- Fall back to empty attributed strings for structural changes
- Result: Even empty attributed strings fail with -25201

### Key Insights

#### The Fundamental Mismatch
Notes.app has semantic understanding of document structure. When vim performs line operations:
1. Semantic attributes (headings, lists) have strict structural rules
2. These attributes cannot span or break at arbitrary newline positions
3. Line-based operations violate these semantic constraints
4. Notes.app rejects the entire attributed string rather than adapt

#### The "Never Plain Text" Constraint
- User requirement: "never ever want plain text mode, it f's the whole app"
- Plain text destroys Notes.app's rich text infrastructure
- Must find attributed string solution that works for ALL operations

### Current Status: All Approaches Failed
After 5 different implementation attempts, line operations still break with attributed strings, and plain text fallback is unacceptable.

### Plausible Next Steps

#### 1. Hybrid Text Replacement Strategy
Instead of full buffer replacement, implement targeted range replacement:
- Character edits: Replace specific ranges while preserving surrounding attributes
- Line operations: Use `AXReplaceStringInRange` (if available) for surgical changes
- Preserve semantic structure by not touching heading/list attribute boundaries

#### 2. Application-Specific Adaptation
- Detect when in Notes.app vs other applications
- Notes.app: Use specialized handling that respects semantic structure
- Other apps: Use current attributed string approach
- May require app-specific heuristics for what operations are "safe"

#### 3. Accessibility API Deep Dive
- Research undocumented accessibility APIs that might handle rich text better
- Investigate `AXReplaceRangeWithText` despite being unreliable
- Look into alternative attribute preservation methods

#### 4. Vim Buffer Synchronization Rethink
- Instead of vim→app sync, consider app→vim sync priority
- Let Notes.app handle line operations natively
- Sync vim buffer state after Notes.app completes the operation
- Would require fundamental architecture change

#### 5. Partial Workaround Acceptance
- Accept that some vim operations cannot preserve formatting
- Implement "formatting-safe" vim subset for rich text contexts
- Provide clear feedback when operations would break formatting
- Allow user to choose between full vim functionality vs formatting preservation

### Development Context
The codebase uses Core Foundation C APIs exclusively. All attributed string manipulation must be compatible with C compilation (no Objective-C NSAttributedString conveniences available).

## Development Workflow
- Now using justfiles for all commands
  - Replaced traditional makefiles with just (a command runner)
  - Simplifies build, test, and deployment processes
  - Provides more flexible and readable command definitions
