```@meta
CurrentModule = CodeDiffs
```

# CodeDiffs

Compare different types of code and display it in the terminal.
For cleaner results, syntax highlighting is separated from the difference calculation.

Supports:
 - native CPU assembly (output of `@code_native`, highlighted by `InteractiveUtils.print_native`)
 - LLVM IR (output of `@code_llvm`, highlighted by `InteractiveUtils.print_llvm`)
 - Typed Julia IR (output of `@code_typed`, highlighted through the `Base.show` method of `Core.CodeInfo`)
 - Julia AST (an `Expr`), highlighting is done with:
   - OhMyREPL.jl's Julia syntax highlighting in Markdown code blocks
   - (Julia ≥ v1.11) [JuliaSyntaxHighlighting.jl](https://github.com/JuliaLang/JuliaSyntaxHighlighting.jl)

The [`@code_diff`](@ref) macro is the main entry point. If possible, the code type will be
detected automatically, otherwise add e.g. `type=:llvm` for LLVM IR comparison:

```jldoctest f1_vs_f2; setup=:(using CodeDiffs)
julia> f1(a) = a + 1
f1 (generic function with 1 method)

julia> @code_diff type=:llvm debuginfo=:none color=false f1(Int64(1)) f1(Int8(1))
define i64 @f1(i64 signext %0) #0 {   ⟪╋⟫define i64 @f1(i8 signext %0) #0 {
top:                                   ┃ top:
                                       ┣⟫  %1 = sext i8 %0 to i64
  %1 = add i64 %0, 1                  ⟪╋⟫  %2 = add nsw i64 %1, 1
  ret i64 %1                          ⟪╋⟫  ret i64 %2
}                                      ┃ }

julia> f2(a) = a - 1
f2 (generic function with 1 method)

julia> @code_diff type=:llvm debuginfo=:none color=false f1(1) f2(1)
define i64 @f1(i64 signext %0) #0 {   ⟪╋⟫define i64 @f2(i64 signext %0) #0 {
top:                                   ┃ top:
  %1 = add i64 %0, 1                  ⟪╋⟫  %1 = add i64 %0, -1
  ret i64 %1                           ┃   ret i64 %1
}                                      ┃ }
```

Setting the environment variable `"CODE_DIFFS_LINE_NUMBERS"` to `true` will display line
numbers on each side.
An example with `type=:native` for native assembly comparison:

```jldoctest f1_vs_f2
julia> ENV["CODE_DIFFS_LINE_NUMBERS"] = true
true

julia> @code_diff type=:native debuginfo=:none color=false f1(1) f2(1)
 1     .text                           ┃     .text                          1 
 2     .file    "f1"                  ⟪╋⟫    .file    "f2"                  2 
 3     .globl    f1                  …⟪╋⟫    .globl    f2                  …3 
 4     .p2align    4, 0x90             ┃     .p2align    4, 0x90            4 
 5     .type    f1,@function          ⟪╋⟫    .type    f2,@function          5 
 6 f1:                           # @f…⟪╋⟫f2:                           # @f…6 
 7     .cfi_startproc                  ┃     .cfi_startproc                 7 
 8 # %bb.0:                          … ┃ # %bb.0:                          …8 
 9     push    rbp                     ┃     push    rbp                    9 
10     .cfi_def_cfa_offset 16          ┃     .cfi_def_cfa_offset 16         10
11     .cfi_offset rbp, -16            ┃     .cfi_offset rbp, -16           11
12     mov    rbp, rsp                 ┃     mov    rbp, rsp                12
13     .cfi_def_cfa_register rbp       ┃     .cfi_def_cfa_register rbp      13
14     lea    rax, [rcx + 1]          ⟪╋⟫    lea    rax, [rcx - 1]          14
15     pop    rbp                      ┃     pop    rbp                     15
16     ret                             ┃     ret                            16
17 .Lfunc_end0:                        ┃ .Lfunc_end0:                       17
18     .size    f1, .Lfunc_end0-f1    ⟪╋⟫    .size    f2, .Lfunc_end0-f2    18
19     .cfi_endproc                    ┃     .cfi_endproc                   19
20                                   … ┃                                   …20
21     .section    ".note.GNU-stack",… ┃     .section    ".note.GNU-stack",…21
```

Note that lines which do not fit in the column width are trimmed and end with `…`. The
column width is adjusted to your whole terminal.

# Main functions

```@docs
CodeDiff
compare_code_native
compare_code_llvm
compare_code_typed
compare_ast
code_diff(::AbstractString, ::AbstractString)
code_diff(::Markdown.MD, ::Markdown.MD)
@code_diff
```

# Display functions

```@docs
optimize_line_changes!
replace_llvm_module_name
side_by_side_diff
```

# Internals

```@docs
LLVM_MODULE_NAME_REGEX
```
