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

![](assets/basic_usage.gif)

Syntax highlighting for Julia AST is also supported:

![](assets/ast_diff.gif)

The `@code_for` macro is a convinence macro which will give you only one side of `@code_diff`'s
output, therefore it behaves like all `@code_native`/`@code_**` macros but with seamless
support for GPU and additional cleanup functionalities.

## Supported languages

- `:native` native CPU assembly (output of `@code_native`)
- `:llvm` native LLVM IR (output of `@code_llvm`)
- `:typed` Typed Julia IR (output of `@code_typed`)
- `:ast` Julia AST (any `Expr`, relies on [`Revise.jl`](https://github.com/timholy/Revise.jl))

From [`CUDA.jl`](https://github.com/JuliaGPU/CUDA.jl):

- `:sass` SASS assembly (output of `CUDA.@device_code_sass`)
- `:cuda_native`/`:ptx` PTX assembly (output of `CUDA.@device_code_ptx`)
- `:cuda_llvm` GPU LLVM IR (output of `CUDA.@device_code_llvm`)
- `:cuda_typed` typed Julia IR for the GPU (output of `CUDA.@device_code_typed`)

Calls to kernels from [`KernelAbstractions.jl`](https://github.com/JuliaGPU/KernelAbstractions.jl)
will give the code of the actual underlying kernel seamlessly.
