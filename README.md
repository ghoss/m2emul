# Modula-2 M-Code Interpreter and Virtual Machine
## Overview
This will become an interpreter and virtual machine for Lilith Modula-2 M-Code object files.

Work in progress.

## Current Development Status
* M-Code Loader fully functional (can load and stage modules and their dependencies).
* Runtime debugging is functional:
  * Single-step execution
  * Set breakpoint / execute to breakpoint
  * Register and stack display
  * Procedure call chain display
  * Inspection of data words (variables)
* Interpreter can already execute the ETHZ Modula-2 single pass compiler.
* Some M-Codes are still disabled for debugging however (due to ongoing tests).

## Key Features Compared To The Lilith Machine
### Functionality in General
* Supports the original M-Code instruction set implemented in the Lilith.
* Binary compatible with the Lilith's object code format and able to execute code generated by the ETHZ Modula-2 single pass and multipass compilers.
* Built-in runtime monitor and debugger.
### Specific Changes And Improvements
* Loads object files from underlying host filesystem (e.g. UNIX) and therefore does not rely on the original Honeywell D140 disk system. This is accomplished by a custom implementation of module "FileSystem" which performs low-level I/O via calls to the "supervisor" M-Code opcode.
* Provides its own dynamic loader for staging of object files and does not rely on the Medos-2 operating system loader in module "Program".
* Provides its own heap memory allocation functions, which again are tied in to the standard module "Storage" via supervisor calls.
* On the Lilith, all modules share the same 65K (16-bit) address space. **m2emul** provides more memory to programs while still maintaining the original 16-bit instruction set by assigning each module its own code space (max. 65KB per module).
### Planned Features
* Framebuffer compatible with original code for graphical output (currently, the emulator only runs in terminal-based text mode).

## Compiling And Installation
1. Download the .tar.gz packages from the "[Releases](https://github.com/ghoss/m2emul/releases)" page.
2. Extract and build:
    ```
    $ tar xzf m2emul-x.y.tar.gz
    $ cd m2emul-x.y
    $ ./configure
    $ make && make install
    ```

## Usage
```
USAGE: mule [-hV] [object_file]

-t      Enable trace mode (runtime debugging)
-h      Show this help information
-V      Show version information

-v      Verbose mode

object_file is the filename of a Lilith M-Code (OBJ) file.
```