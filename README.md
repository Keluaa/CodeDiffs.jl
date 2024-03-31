# CodeDiffs

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://Keluaa.github.io/CodeDiffs.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://Keluaa.github.io/CodeDiffs.jl/dev/)
[![Build Status](https://github.com/Keluaa/CodeDiffs.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/Keluaa/CodeDiffs.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/Keluaa/CodeDiffs.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/Keluaa/CodeDiffs.jl)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

Compare code and display the difference in the terminal side-by-side.
Supports syntax highlighting.

The [`@code_diff`](@ref) macro is the main entry point. If possible, the code type will be
detected automatically, otherwise add e.g. `type=:native` for native assembly comparison:
```julia
julia> f1(a) = a + 1
f1 (generic function with 1 method)

julia> @code_diff type=:llvm debuginfo=:none f1(Int64(1)) f1(Int8(1))
; Function Attrs: uwtable              ┃ ; Function Attrs: uwtable
define i64 @f1(i64 signext %0) #0 {   ⟪╋⟫define i64 @f1(i8 signext %0) #0 {
top:                                   ┃ top:
  %1 = add i64 %0, 1                  ⟪╋⟫  %2 = add nsw i64 %1, 1
  ret i64 %1                          ⟪╋⟫  ret i64 %2
                                       ┣⟫  %1 = sext i8 %0 to i64
}                                      ┃ }
                                       ┃

julia> f2(a) = a - 1
f2 (generic function with 1 method)

julia> @code_diff type=:llvm debuginfo=:none f1(1) f2(1)
; Function Attrs: uwtable              ┃ ; Function Attrs: uwtable
define i64 @f1(i64 signext %0) #0 {   ⟪╋⟫define i64 @f2(i64 signext %0) #0 {
top:                                   ┃ top:
  %1 = add i64 %0, 1                  ⟪╋⟫  %1 = add i64 %0, -1
  ret i64 %1                           ┃   ret i64 %1
}                                      ┃ }
                                       ┃
```

## Supported languages

 - native CPU assembly (output of `@code_native`)
 - LLVM IR (output of `@code_llvm`)
 - Typed Julia IR (output of `@code_typed`)
 - Julia AST (any `Expr`)
