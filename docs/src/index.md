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
 - Julia AST (an `Expr`), highlighting is done with OhMyREPL.jl's Julia syntax highlighting in Markdown code blocks
 - GPU typed Julia IR / LLVM IR / native assembly (see [GPU Extensions](@ref))

`CodeDiffs.jl` exports two macros:
 - [`@code_for`](@ref) will display the code for a function call. The output is
   cleaned and highlighted to maximize clarity.
 - [`@code_diff`](@ref) will compare the code of two function calls.

Both support all code types.
If possible, the code type will be detected automatically, otherwise add e.g.
`type=:llvm` for LLVM IR comparison:

```@repl 1
using CodeDiffs  # hide
f1(a) = a + 1
@code_diff type=:llvm debuginfo=:none color=false f1(Int64(1)) f1(Int8(1))
f2(a) = a - 1
@code_diff type=:llvm debuginfo=:none color=false f1(1) f2(1)
```

Setting the environment variable `"CODE_DIFFS_LINE_NUMBERS"` to `true` will display line
numbers on each side:

```@repl 1
ENV["CODE_DIFFS_LINE_NUMBERS"] = true
@code_diff type=:llvm debuginfo=:none color=false f1(1) f2(1)
```

# Main API

```@docs; canonical=false
@code_for
@code_diff
```
