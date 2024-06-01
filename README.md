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

## Supported languages

- `:native` native CPU assembly (output of `@code_native`)
- `:llvm` native LLVM IR (output of `@code_llvm`)
- `:typed` Typed Julia IR (output of `@code_typed`)
- `:ast` Julia AST (any `Expr`, relies on [`Revise.jl`](https://github.com/timholy/Revise.jl))

Their equivalents for each GPU package is also supported:

| Code type   | [`CUDA.jl`](https://github.com/JuliaGPU/CUDA.jl) | [`AMDGPU.jl`](https://github.com/JuliaGPU/AMDGPU.jl) | [`oneAPI.jl`](https://github.com/JuliaGPU/oneAPI.jl) | [`Metal.jl`](https://github.com/JuliaGPU/Metal.jl) |
|-------------|-----------------------|-----------------------|------------------------|----------------------|
| Julia Typed | `:cuda_typed`         | `:rocm_typed`         | `:one_typed`           | `:mtl_typed`         |
| LLVM IR     | `:cuda_llvm`          | `:rocm_llvm`          | `:one_llvm`            | `:mtl_llvm`          |
| Native	  | `:cuda_native`/`:ptx` | `:rocm_native`/`:gcn` | `:one_native`/`:spirv` | `:mtl_native`/`:agx` |

Additionally, SASS assembly from `CUDA` is also supported with `:sass`.

Each output should match the output `@device_code_typed`, `@device_code_llvm` and `@device_code_native`
defined by their respective GPU package, as well as accepting the same options.

Calls to kernels from [`KernelAbstractions.jl`](https://github.com/JuliaGPU/KernelAbstractions.jl)
will give the code of the actual underlying kernel seamlessly.
