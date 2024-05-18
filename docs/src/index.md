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
numbers on each side:

```jldoctest f1_vs_f2
julia> ENV["CODE_DIFFS_LINE_NUMBERS"] = true
true

julia> @code_diff type=:llvm debuginfo=:none color=false f1(1) f2(1)
1 define i64 @f1(i64 signext %0) #0 { ⟪╋⟫define i64 @f2(i64 signext %0) #0 { 1
2 top:                                 ┃ top:                                2
3   %1 = add i64 %0, 1                ⟪╋⟫  %1 = add i64 %0, -1               3
4   ret i64 %1                         ┃   ret i64 %1                        4
5 }                                    ┃ }                                   5
```

# Comparison entry points

```@docs
@code_diff
code_diff
code_for_diff
CodeDiff
```

# Code fetching

```@docs
code_native
code_llvm
code_typed
code_ast
get_code
```

# Highlighting

```@docs
code_highlighter
```

# Cleanup

```@docs
cleanup_code
replace_llvm_module_name
function_unique_gen_name_regex
```

# Diff display

```@docs
optimize_line_changes!
side_by_side_diff
```
