# CodeDiffs

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://Keluaa.github.io/CodeDiffs.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://Keluaa.github.io/CodeDiffs.jl/dev/)
[![Build Status](https://github.com/Keluaa/CodeDiffs.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/Keluaa/CodeDiffs.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/Keluaa/CodeDiffs.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/Keluaa/CodeDiffs.jl)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

Compare code and display the difference in the terminal side-by-side, based on
[DeepDiffs.jl](https://github.com/ssfrr/DeepDiffs.jl).
Supports syntax highlighting.

The `@code_diff` macro is the main entry point. If possible, the code type will be
detected automatically, otherwise add e.g. `type=:native` for native assembly comparison:
![](assets\basic_usage.gif)

Syntax highlighting for Julia AST is also supported:
![](assets\ast_diff.gif)

## Supported languages

- native CPU assembly (output of `@code_native`)
- LLVM IR (output of `@code_llvm`)
- Typed Julia IR (output of `@code_typed`)
- Julia AST (any `Expr`)
