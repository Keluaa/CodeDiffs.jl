module CodeDiffsOneAPI

using CodeDiffs
using oneAPI
import oneAPI: GPUCompiler

gpu_compiler_kwargs() = oneAPI.COMPILER_KWARGS

include("gpu_common.jl")


function gpu_compiler_job(mi::Core.MethodInstance; kwargs...)
    config = oneAPI.compiler_config(oneAPI.device(); kwargs...)
    return oneAPI.CompilerJob(mi, config)
end


CodeDiffs.argconvert(::Val{:one_typed},  arg) = oneAPI.kernel_convert(arg)
CodeDiffs.argconvert(::Val{:one_llvm},   arg) = oneAPI.kernel_convert(arg)
CodeDiffs.argconvert(::Val{:spirv},      arg) = oneAPI.kernel_convert(arg)
CodeDiffs.argconvert(::Val{:one_native}, arg) = oneAPI.kernel_convert(arg)

@nospecialize

CodeDiffs.get_code_dispatch(::Val{:one_typed},  f, types; kwargs...) = code_gpu_typed(f, types; kwargs...)
CodeDiffs.get_code_dispatch(::Val{:one_llvm},   f, types; kwargs...) = code_gpu_llvm(f, types; kwargs...)
CodeDiffs.get_code_dispatch(::Val{:spirv},      f, types; kwargs...) = CodeDiffs.get_code_dispatch(Val{:one_native}(), f, types; kwargs...)
CodeDiffs.get_code_dispatch(::Val{:one_native}, f, types; kwargs...) = code_gpu_native(f, types; kwargs...)

@specialize

CodeDiffs.code_highlighter(::Val{:one_typed}) = CodeDiffs.code_highlighter(Val{:typed}())
CodeDiffs.code_highlighter(::Val{:one_llvm})  = CodeDiffs.code_highlighter(Val{:llvm}())
# no highlighting for SPIRV (unsupported by GPUCompiler.jl)

CodeDiffs.cleanup_code(::Val{:one_llvm}, c) = CodeDiffs.replace_llvm_module_name(c)
CodeDiffs.cleanup_code(::Val{:spirv}, c) = CodeDiffs.cleanup_code(Val{:one_native}(), c)
CodeDiffs.cleanup_code(::Val{:one_native}, c) = CodeDiffs.replace_llvm_module_name(c)

end
