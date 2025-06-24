```@meta
CurrentModule = CodeDiffs
```

# GPU Extensions

## KernelAbstractions.jl

[`@code_diff`](@ref) will automatically detect calls to [KernelAbstractions.jl](https://github.com/JuliaGPU/KernelAbstractions.jl)
and get the code for the actual underlying kernel function (whatever the backend is).
To do this, the kernel call must be complete: both `workgroupsize` and `ndrange` must have
a value, either from when instantiating the kernel for a backend (`gpu_kernel = my_kernel(CUDABackend(), 1024)`)
or when calling the kernel (`gpu_kernel(a, b, c; ndrange=1000)`).

There is no support for AST comparison with KA.jl kernels.

## GPU kernels

[`@code_diff`](@ref) supports functions compiled in a GPU context with any of the GPU packages:

- [`CUDA.jl`](https://github.com/JuliaGPU/CUDA.jl)
- [`AMDGPU.jl`](https://github.com/JuliaGPU/AMDGPU.jl) 
- [`oneAPI.jl`](https://github.com/JuliaGPU/oneAPI.jl)
- [`Metal.jl`](https://github.com/JuliaGPU/Metal.jl)

Each compilation step has its own code type:
- `:cuda_typed`/`:rocm_typed`/`:one_typed`/`:mtl_typed` typed Julia IR for the GPU (output of `@device_code_typed`)
- `:cuda_llvm`/`:rocm_llvm`/`:one_llvm`/`:mtl_llvm` GPU LLVM IR (output of `@device_code_llvm`)
- `:cuda_native`/`:rocm_native`/`:one_native`/`:mtl_native` native GPU assembly (output of `@device_code_native`).
  Each have an alias using the assembly name: `:ptx`/`:gcn`/`:spirv`/`:agx`.

CUDA has one additional layer of assembly code, SASS, available with `:sass`.

!!! info

    Unlike with the `@device_code_*` macros, no kernel code is executed by [`@code_diff`](@ref).
    The `@device_code_*` macros work by capturing kernel launches, while `@code_diff` or `@code_for`
    work with the kernel function directly: this means that kernels launched indirectly by the
    function call will be ignored.

!!! info

    Note that behind the scenes, `GPUCompiler.jl` only cares about the most recent methods.
    Hence the `world` keyword is unsupported for all GPU backends, as we cannot compile back in time.

### GPU kernel statistics

With the `:cuda_stats` code type, you can get an overview of your CUDA kernel through statistics
inferred from its PTX and SASS code.

Other supported types are `:cuda_stats`, `:ptx_stats` and `:sass_stats` for CUDA kernels, and
`:gcn_stats` for AMDGPU kernels.
See [CodeDiffs.Stats.extract_stats](@ref) for more about them.

Example usage:
```julia
@code_for :cuda_stats some_kernel(a, b, c)
```
Output:
```@eval
using Markdown
using CodeDiffs
ptx_source  = readchomp("../../test/samples/extern_func_with_no_params.ptx")
sass_source = readchomp("../../test/samples/extern_func_with_no_params.sass")
cuda_stats = CodeDiffs.Stats.extract_stats(Val(:cuda_stats), (ptx_source, sass_source))
Markdown.MD(Markdown.julia, Markdown.Code("", sprint(Base.show, MIME"text/plain"(), cuda_stats)))
```
