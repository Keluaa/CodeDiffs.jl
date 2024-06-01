module CodeDiffsCUDA

using CodeDiffs
using CUDA
import CUDA: GPUCompiler

gpu_compiler_kwargs() = CUDA.COMPILER_KWARGS

include("gpu_common.jl")


function gpu_compiler_job(mi::Core.MethodInstance; kwargs...)
    config = CUDA.compiler_config(CUDA.device(); kwargs...)
    return CUDA.CompilerJob(mi, config)
end


function code_sass(job::CUDA.CompilerJob; kwargs...)
    @nospecialize(job)
    return sprint((io, job) -> CUDA.code_sass(io, job; kwargs...), job; context=:color=>false)
end


function code_sass(f, types; world=nothing, kwargs...)
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

@nospecialize

CodeDiffs.get_code_dispatch(::Val{:cuda_typed},  f, types; kwargs...) = code_gpu_typed(f, types; kwargs...)
CodeDiffs.get_code_dispatch(::Val{:cuda_llvm},   f, types; kwargs...) = code_gpu_llvm(f, types; kwargs...)
CodeDiffs.get_code_dispatch(::Val{:ptx},         f, types; kwargs...) = CodeDiffs.get_code_dispatch(Val{:cuda_native}(), f, types; kwargs...)
CodeDiffs.get_code_dispatch(::Val{:cuda_native}, f, types; kwargs...) = code_gpu_native(f, types; kwargs...)
CodeDiffs.get_code_dispatch(::Val{:sass},        f, types; kwargs...) = code_sass(f, types; kwargs...)

@specialize


CodeDiffs.code_highlighter(::Val{:cuda_typed})  = CodeDiffs.code_highlighter(Val{:typed}())
CodeDiffs.code_highlighter(::Val{:cuda_llvm})   = (io, str) -> highlight_using_pygments(io, str, "llvm")
CodeDiffs.code_highlighter(::Val{:ptx})         = (io, str) -> highlight_using_pygments(io, str, "ptx")
CodeDiffs.code_highlighter(::Val{:cuda_native}) = CodeDiffs.code_highlighter(Val{:ptx}())

function highlight_using_pygments(io::IO, str::AbstractString, lexer)
    CUDA.GPUCompiler.highlight(io, str, lexer)
end


CodeDiffs.cleanup_code(::Val{:cuda_llvm}, c) = CodeDiffs.replace_llvm_module_name(c)

CodeDiffs.cleanup_code(::Val{:cuda_native}, c) = CodeDiffs.cleanup_code(Val{:ptx}(), c)
function CodeDiffs.cleanup_code(::Val{:ptx}, c)
    # PTX problems:
    # Additional functions (e.g. those introduced by exceptions) have random positions in
    # the PTX header, and have as well parameters named after the function and can inherit
    # the `globalUniqueGeneratedNames` value.
    c = CodeDiffs.replace_llvm_module_name(c)
    # I don't know what `callseq` indicates in comments, but the numbers after change at every call
    return replace(c, r" // callseq .+$"m => "")
end

function CodeDiffs.cleanup_code(::Val{:sass}, c)
    # SASS problems:
    # Registers seem to be assigned randomly, changing from one call to another with the
    # same input, as well as some immediate values (maybe related to the functions order in PTX?).
    # Some instructions (only `MOV` from what I saw) might be ordered differently, or even
    # in different numbers (max of what I could see is 1, but still surprising).
    return CodeDiffs.replace_llvm_module_name(c)
end

end
