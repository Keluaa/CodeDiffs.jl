module CodeDiffsMetal

using CodeDiffs
using Metal
import Metal: GPUCompiler

gpu_compiler_kwargs() = Metal.COMPILER_KWARGS
const USE_CUSTOM_NATIVE_FUNC = true

include("gpu_common.jl")


function gpu_compiler_job(mi::Core.MethodInstance; kwargs...)
    config = Metal.compiler_config(Metal.device(); kwargs...)
    return Metal.CompilerJob(mi, config)
end


function code_gpu_native(job::GPUCompiler.CompilerJob; dbinfo=true, kwargs...)
    @nospecialize(job)
    return sprint((io, job) -> Metal.code_agx(io, job), job; context=:color=>false)
end


CodeDiffs.argconvert(::Val{:mtl_typed},  arg) = Metal.mtlconvert(arg)
CodeDiffs.argconvert(::Val{:mtl_llvm},   arg) = Metal.mtlconvert(arg)
CodeDiffs.argconvert(::Val{:agx},        arg) = Metal.mtlconvert(arg)
CodeDiffs.argconvert(::Val{:mtl_native}, arg) = Metal.mtlconvert(arg)

@nospecialize

CodeDiffs.get_code_dispatch(::Val{:mtl_typed},  f, types; kwargs...) = code_gpu_typed(f, types; kwargs...)
CodeDiffs.get_code_dispatch(::Val{:mtl_llvm},   f, types; kwargs...) = code_gpu_llvm(f, types; kwargs...)
CodeDiffs.get_code_dispatch(::Val{:agx},        f, types; kwargs...) = CodeDiffs.get_code_dispatch(Val{:mtl_native}(), f, types; kwargs...)
CodeDiffs.get_code_dispatch(::Val{:mtl_native}, f, types; kwargs...) = code_gpu_native(f, types; kwargs...)

@specialize

CodeDiffs.code_highlighter(::Val{:mtl_typed}) = CodeDiffs.code_highlighter(Val{:typed}())
CodeDiffs.code_highlighter(::Val{:mtl_llvm})  = CodeDiffs.code_highlighter(Val{:llvm}())
# no highlighting for AGX (unsupported by GPUCompiler.jl)

function CodeDiffs.cleanup_code(::Val{:mtl_typed}, c, dbinfo, cleanup_opts)
    if get(cleanup_opts, :expand_llvmcall, true)
        c = CodeDiffs.cleanup_inline_llvmcall_modules(c)
    end
    return c
end

CodeDiffs.cleanup_code(::Val{:mtl_llvm}, c, dbinfo, cleanup_opts) = CodeDiffs.replace_llvm_module_name(c)
CodeDiffs.cleanup_code(::Val{:agx}, c, dbinfo, cleanup_opts) = CodeDiffs.cleanup_code(Val{:mtl_native}(), c, dbinfo, cleanup_opts)
CodeDiffs.cleanup_code(::Val{:mtl_native}, c, dbinfo, cleanup_opts) = CodeDiffs.replace_llvm_module_name(c)

end
