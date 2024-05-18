```@meta
CurrentModule = CodeDiffs
```

# KernelAbstractions.jl

[`@code_diff`](@ref) will automatically detect calls to [KernelAbstractions.jl](https://github.com/JuliaGPU/KernelAbstractions.jl)
and get the code for the actual underlying kernel function (whatever the backend is).
To do this, the kernel call must be complete: both `workgroupsize` and `ndrange` must have
a value, either from when instantiating the kernel for a backend (`gpu_kernel = my_kernel(CUDABackend(), 1024)`)
or when calling the kernel (`gpu_kernel(a, b, c; ndrange=1000)`).

There is no support for AST comparison with KA.jl kernels.

# CUDA.jl

Functions compiled in a GPU context with [`CUDA.jl`](https://github.com/JuliaGPU/CUDA.jl)
are supported.
Each compilation step has its own code type:
- `:cuda_typed` typed Julia IR for the GPU (output of `CUDA.@device_code_typed`)
- `:cuda_llvm` GPU LLVM IR (output of `CUDA.@device_code_llvm`)
- `:cuda_native`/`:ptx` PTX assembly (output of `CUDA.@device_code_ptx`)
- `:sass` SASS assembly (output of `CUDA.@device_code_sass`)

**Important**: unlike with `CUDA.@device_code_**` macros, no kernel code is executed by
[`@code_diff`](@ref). This also means that kernels launched indirectly

# Defining a new extension

Defining a new `code_type` involves three functions:
- `CodeDiffs.get_code_dispatch(::Val{code_type}, f, types; kwargs...)` (**not** `get_code`!)
  should return a printable object (usually a `String`) representing the code for `f(types)`.
  `kwargs` are the options passed to `@code_diff`.
- `CodeDiffs.cleanup_code(::Val{:code_type}, obj)` does some cleanup on the code object to
  make it more `diff`-able
- `CodeDiffs.code_highlighter(::Val{code_type})` returns a `f(io, obj)` to print the `obj`
  to as text in `io`. This is done twice: once without highlighting (`get(io, :color, false) == false`),
  and another with highlighting.

Defining a new pre-processing step for functions and its arguments (like for KA.jl kernels)
involves three functions:
- `CodeDiffs.argconvert(f, arg)` transforms `arg` depending on `f` (by default `arg` is unchanged)
- `CodeDiffs.extract_extra_options(f, kwargs)` returns some additional `kwargs` which are passed to `get_code`
- `CodeDiffs.get_code(code_type, f, types; kwargs...)` allows to change `f` depending on its type.
  To avoid method ambiguities, do not put type constraints on `code_type`.
