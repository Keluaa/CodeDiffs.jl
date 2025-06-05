module CodeDiffsAMDGPU

using CodeDiffs
using AMDGPU
import AMDGPU: GPUCompiler

if pkgversion(AMDGPU) < v"0.8.11"
    gpu_compiler_kwargs() = [:kernel, :name]
else
    gpu_compiler_kwargs() = [:kernel, :name, :unsafe_fp_atomics]
end

include("gpu_common.jl")


function gpu_compiler_job(mi::Core.MethodInstance; kwargs...)
    config = AMDGPU.Compiler.compiler_config(AMDGPU.device(); kwargs...)
    return AMDGPU.Compiler.CompilerJob(mi, config)
end


CodeDiffs.argconvert(::Val{:rocm_typed},  arg) = AMDGPU.rocconvert(arg)
CodeDiffs.argconvert(::Val{:rocm_llvm},   arg) = AMDGPU.rocconvert(arg)
CodeDiffs.argconvert(::Val{:gcn},         arg) = AMDGPU.rocconvert(arg)
CodeDiffs.argconvert(::Val{:rocm_native}, arg) = AMDGPU.rocconvert(arg)

@nospecialize

CodeDiffs.get_code_dispatch(::Val{:rocm_typed},  f, types; kwargs...) = code_gpu_typed(f, types; kwargs...)
CodeDiffs.get_code_dispatch(::Val{:rocm_llvm},   f, types; kwargs...) = code_gpu_llvm(f, types; kwargs...)
CodeDiffs.get_code_dispatch(::Val{:gcn},         f, types; kwargs...) = CodeDiffs.get_code_dispatch(Val{:rocm_native}(), f, types; kwargs...)
CodeDiffs.get_code_dispatch(::Val{:rocm_native}, f, types; kwargs...) = code_gpu_native(f, types; kwargs...)

@specialize

CodeDiffs.code_highlighter(::Val{:rocm_typed})  = CodeDiffs.code_highlighter(Val{:typed}())
CodeDiffs.code_highlighter(::Val{:rocm_llvm})   = (io, str) -> highlight_using_pygments(io, str, "llvm")
CodeDiffs.code_highlighter(::Val{:gcn})         = (io, str) -> highlight_using_pygments(io, str, "gcn")
CodeDiffs.code_highlighter(::Val{:rocm_native}) = CodeDiffs.code_highlighter(Val{:gcn}())

function highlight_using_pygments(io::IO, str::AbstractString, lexer)
    if @static(pkgversion(GPUCompiler) < v"1.2.0" && lexer == "gcn")
        write(io, str)
    else
        GPUCompiler.highlight(io, str, lexer)
    end
end

CodeDiffs.cleanup_code(::Val{:rocm_typed},  c, dbinfo, cleanup_opts) = CodeDiffs.cleanup_code(Val{:gpu_typed}(), c, dbinfo, cleanup_opts)
CodeDiffs.cleanup_code(::Val{:rocm_llvm},   c, dbinfo, cleanup_opts) = CodeDiffs.cleanup_code(Val{:gpu_llvm}(), c, dbinfo, cleanup_opts)
CodeDiffs.cleanup_code(::Val{:rocm_native}, c, dbinfo, cleanup_opts) = CodeDiffs.cleanup_code(Val{:gcn}(), c, dbinfo, cleanup_opts)

end
