```@meta
CurrentModule = CodeDiffs
```

# Extensions

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
    This also means that kernels launched indirectly by the function will be ignored.

!!! info

    Note that behind the scenes, `GPUCompiler.jl` only cares about the most recent methods.
    Hence the `world` keyword is unsupported for all GPU backends, as we cannot compile back in time.

### GPU kernel statistics

With the `:cuda_stats` code type, you can get an overview of your CUDA kernel through statistics
inferred from its PTX and SASS code:
```julia
julia> @code_for type=:cuda_stats some_kernel(a, b, c)
Kernel memory stats (static allocations):
 - Global    134 bytes
 - Constant  0 bytes
 - Shared    112 bytes
 - Local     864 bytes

SASS source stats:
 - Target SM         80
 - Registers usage   64
 - Instructions      6376
 - Workgroup sync    63
 - Warp sync         8
 - Function calls    51

PTX variable declarations:
 - Global:
   - b8    134
 - Shared:
   - b8    112
 - Local:
   - b8    864
 - Registers:
   - b16   276
   - b32   106
   - b64   2502
   - f64   214
   - pred  257
```

Note that dynamic allocation of shared memory is ignored for now.
Vector variables account for 2, 4 or 8 variables of the base type.

!!! info

    PTX uses virtual registers, therefore the compiler can declare 1000s of register variables, yet
    it is only in the SASS code that registers are allocated physically.
    In the example above, more than 22 KiB of registers are declared, yet the SASS output uses a
    maximum of 64 registers (and 864 bytes of local memory) per thread.

# Defining a new extension

Defining a new `code_type` involves four functions:
- `CodeDiffs.get_code_dispatch(::Val{code_type}, f, types; kwargs...)` (**not** `get_code`!)
  should return a printable object (usually a `String`) representing the code for `f(types)`.
  `kwargs` are the options passed to `@code_diff`.
- `CodeDiffs.cleanup_code(::Val{:code_type}, obj)` does some cleanup on the code object to
  make it more `diff`-able
- `CodeDiffs.code_highlighter(::Val{code_type})` returns a `f(io, obj)` to print the `obj`
  to as text in `io`. This is done twice: once without highlighting (`get(io, :color, false) == false`),
  and another with highlighting.
- `CodeDiffs.argconvert(::Val{code_type}, arg)` converts `arg` as needed (by default `arg` is unchanged)

Defining a new pre-processing step for functions and its arguments (like for KernelAbstractions.jl kernels)
involves two functions:
- `CodeDiffs.extract_extra_options(f, kwargs)` returns some additional `kwargs` which are passed to `get_code`
- `CodeDiffs.get_code(code_type, f, types; kwargs...)` allows to change `f` depending on its type.
  To avoid method ambiguities, do not put type constraints on `code_type`.

Defining a new object type which can be put as an argument to `@code_diff` or `@code_for`
invoves at one function: `CodeDiffs.code_for_diff(obj::YourType; kwargs...)`.
It must return two `String`s, one without and the other without highlighting.
When calling `@code_for obj`, [`code_for_diff(obj)`](@ref) will be called only if `obj` is
not a call expression or a quoted `Expr`.
`kwargs` are the options passed to `@code_for` or the options passed to `@code_diff` for
the side of `obj`.
