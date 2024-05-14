# vRISC - very Reduced Instruction Set

A _coding challenge_ (if you could call it that) of an ARM-Assembly like, interpreted language.

## Idea

The idea behind this _challenge_ is to learn new languages or rather have a starting point, but also do a somewhat more
challenging task within them, as this contains reading files, parsing their contents and create a proper runtime.

## Specifications

Here is a complete list of instructions:

### Arithmetic

| Instruction | Description |
| --- | --- |
| `add` | Adds two numbers together |
| `sub` | Subtracts a number from another one |
| `mul` | Multiplies two numbers together |
| `div` | Divides a number by another one |

All of these instructions have the same parameters:
`instr R, R/C, R/C` where `R` is a register and `R/C` is either a register or a constant. Note that this also allows adding two constants together.

### Control

| Instruction | Description |
| --- | --- |
| `b LABEL` | Unconditionally jumps to `LABEL` |
| `b{e,ge,g,le,l} LABEL`| Conditionally jumps to `LABEL` if the internal comparison register matches the condition. Description of each condition below. |
| `cmp R, R/C`| Subtracts the second parameter from the first and stores the result in an internal comparison register used for conditional branching. |
| `reserve R/C` | Reserves `R/C` amount of memory. Should _potentially_ be freed afterwords using the `free` instruction. Throws an error if more than stack size is trying to be reserved. |
| `free R/C`| Frees `R/C` amount of memory, after it was reserved using reserve. Throws an error if more memory should be freed than is available. |
| `ret` | Ends the program. Named after return for potential extensions to the language. |

Conditions: `e` for equals, `ge` for greater equals, `g` for greater than, `le` for lesser equals, `l` for less than

### Registers and labels

There are 16 directly addressable registers named `r0` to `r15`. Additionally there is an internal register that stores the result of an `cmp` operation.

Additionally there are labels. Labels are present before an instruction. I.e. `label1: add r0, r0, r0`.

### Configuration options

Configurations are essentially key value mappings with a dot (`.`) before the key. I.e. `.stack_size 4096`

Here the following configuration options exist:
| Option | Description |
| --- | --- |
| `stack_size SIZE` | where `SIZE` is a size in kilobytes. Defines how big the stack should possibly be. This size is allocated for the entire runtime, so don't make it too big! |
| `entry LABEL` | Defines the entry point for this program. If this option isn't present, the program starts at the first instruction. |