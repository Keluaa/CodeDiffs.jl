module CodeDiffsCUDA

using CodeDiffs
using CUDA
import CUDA: GPUCompiler
import KernelAbstractions as KA

gpu_compiler_kwargs() = CUDA.COMPILER_KWARGS

include("gpu_common.jl")


function CodeDiffs.extract_ka_backend_kwargs(kernel::KA.Kernel{CUDABackend})
    # Those two parameters are passed to the `@cuda` kernel constructor in `CUDA.CUDAKernels`
    backend = KA.backend(kernel)
    if KA.workgroupsize(kernel) <: KA.StaticSize
        workgroupsize = prod(KA.get(KA.workgroupsize(kernel)))
    else
        workgroupsize = nothing
    end
    return (; always_inline=backend.always_inline, maxthreads=workgroupsize)
end


function gpu_compiler_job(mi::Core.MethodInstance; kwargs...)
    config = CUDA.compiler_config(CUDA.device(); kwargs...)
    return CUDA.CompilerJob(mi, config)
end


function code_sass(job::CUDA.CompilerJob; dbinfo=true, kwargs...)
    @nospecialize(job)
    return sprint((io, job) -> CUDA.code_sass(io, job; kwargs...), job; context=:color=>false)
end


function code_sass(f, types; world=nothing, dbinfo=true, kwargs...)
    @nospecialize(f, types)
    compiler_kwargs, kwargs = split_kwargs(kwargs, gpu_compiler_kwargs())
    job = gpu_compiler_job(f, types, world; compiler_kwargs...)
    return code_sass(job; kwargs...)
end


CodeDiffs.argconvert(::Val{:cuda_typed},  arg) = CUDA.cudaconvert(arg)
CodeDiffs.argconvert(::Val{:cuda_llvm},   arg) = CUDA.cudaconvert(arg)
CodeDiffs.argconvert(::Val{:ptx},         arg) = CUDA.cudaconvert(arg)
CodeDiffs.argconvert(::Val{:cuda_native}, arg) = CUDA.cudaconvert(arg)
CodeDiffs.argconvert(::Val{:sass},        arg) = CUDA.cudaconvert(arg)
CodeDiffs.argconvert(::Val{:cuda_stats},  arg) = CUDA.cudaconvert(arg)

@nospecialize

CodeDiffs.get_code_dispatch(::Val{:cuda_typed},  f, types; kwargs...) = code_gpu_typed(f, types; kwargs...)
CodeDiffs.get_code_dispatch(::Val{:cuda_llvm},   f, types; kwargs...) = code_gpu_llvm(f, types; kwargs...)
CodeDiffs.get_code_dispatch(::Val{:ptx},         f, types; kwargs...) = CodeDiffs.get_code_dispatch(Val{:cuda_native}(), f, types; kwargs...)
CodeDiffs.get_code_dispatch(::Val{:cuda_native}, f, types; kwargs...) = code_gpu_native(f, types; kwargs...)
CodeDiffs.get_code_dispatch(::Val{:sass},        f, types; kwargs...) = code_sass(f, types; kwargs...)

function CodeDiffs.get_code_dispatch(::Val{:cuda_stats}, f, types; stats_opts=(;), kwargs...)
    ptx_source  = CodeDiffs.get_code_dispatch(Val(:ptx),  f, types; kwargs...)
    sass_source = CodeDiffs.get_code_dispatch(Val(:sass), f, types; kwargs...)
    return CodeDiffs.extract_stats(Val(:cuda_stats), (ptx_source, sass_source), stats_opts)
end

@specialize


CodeDiffs.code_highlighter(::Val{:cuda_typed})  = CodeDiffs.code_highlighter(Val{:typed}())
CodeDiffs.code_highlighter(::Val{:cuda_llvm})   = (io, str) -> highlight_using_pygments(io, str, "llvm")
CodeDiffs.code_highlighter(::Val{:ptx})         = (io, str) -> highlight_using_pygments(io, str, "ptx")
CodeDiffs.code_highlighter(::Val{:cuda_native}) = CodeDiffs.code_highlighter(Val{:ptx}())

function highlight_using_pygments(io::IO, str::AbstractString, lexer)
    if @static(pkgversion(GPUCompiler) < v"1.2.0" && lexer == "ptx")
        write(io, str)
    else
        GPUCompiler.highlight(io, str, lexer)
    end
end


CodeDiffs.cleanup_code(::Val{:cuda_typed},  c, dbinfo, cleanup_opts) = CodeDiffs.cleanup_code(Val{:gpu_typed}(), c, dbinfo, cleanup_opts)
CodeDiffs.cleanup_code(::Val{:cuda_llvm},   c, dbinfo, cleanup_opts) = CodeDiffs.cleanup_code(Val{:gpu_llvm}(), c, dbinfo, cleanup_opts)
CodeDiffs.cleanup_code(::Val{:cuda_native}, c, dbinfo, cleanup_opts) = CodeDiffs.cleanup_code(Val{:ptx}(), c, dbinfo, cleanup_opts)

end
