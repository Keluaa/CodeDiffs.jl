module CodeDiffsAMDGPU

using CodeDiffs
using AMDGPU
import AMDGPU: GPUCompiler

gpu_compiler_kwargs() = [:kernel]

include("gpu_common.jl")


function gpu_compiler_job(mi::Core.MethodInstance; kernel=false)
    config = AMDGPU.compiler_config(AMDGPU.device(); kernel)
    return AMDGPU.CompilerJob(mi, config)
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

CodeDiffs.code_highlighter(::Val{:rocm_typed}) = CodeDiffs.code_highlighter(Val{:typed}())
CodeDiffs.code_highlighter(::Val{:rocm_llvm})  = CodeDiffs.code_highlighter(Val{:llvm}())
# no highlighting for GCN (unsupported by GPUCompiler.jl)

CodeDiffs.cleanup_code(::Val{:rocm_llvm}, c) = CodeDiffs.replace_llvm_module_name(c)
CodeDiffs.cleanup_code(::Val{:gcn}, c) = CodeDiffs.cleanup_code(Val{:rocm_native}(), c)
CodeDiffs.cleanup_code(::Val{:rocm_native}, c) = CodeDiffs.replace_llvm_module_name(c)

end
