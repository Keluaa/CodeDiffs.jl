module CodeDiffsCUDA

using CodeDiffs
using CUDA


if pkgversion(CUDA.GPUCompiler) < v"0.26.2"
    const gpu_method_instance = CUDA.GPUCompiler.methodinstance
else
    const gpu_method_instance = CUDA.GPUCompiler.generic_methodinstance
end


function gpu_compiler_job(mi::Core.MethodInstance; kwargs...)
    config = CUDA.compiler_config(CUDA.device(); kwargs...)
    return CUDA.CompilerJob(mi, config)
end

function gpu_compiler_job(f, types, world=nothing; kwargs...)
    @nospecialize(f, types)
    tt = Base.to_tuple_type(types)
    ft = Core.Typeof(f)
    if isnothing(world)
        mi = gpu_method_instance(ft, tt)
    else
        mi = gpu_method_instance(ft, tt, world)
    end
    return gpu_compiler_job(mi; kwargs...)
end


if !hasmethod(CodeDiffs.code_typed, Tuple{CUDA.GPUCompiler.CompilerJob})
    # Loading multiple of the GPU extensions at once would create method overwrites
    function CodeDiffs.code_typed(job::CUDA.GPUCompiler.CompilerJob; kwargs...)
        @nospecialize(job)
        interp = CUDA.GPUCompiler.get_interpreter(job)
        return CodeDiffs.code_typed(job.source; world=job.world, interp, kwargs...)
    end
end


function code_cuda_typed(job::CUDA.CompilerJob; kwargs...)
    @nospecialize(job)
    return CodeDiffs.code_typed(job; kwargs...)
end


function code_cuda_llvm(job::CUDA.CompilerJob; kwargs...)
    @nospecialize(job)
    return sprint((io, job) -> CUDA.GPUCompiler.code_llvm(io, job; kwargs...), job; context=:color=>false)
end


function code_ptx(job::CUDA.CompilerJob; kwargs...)
    @nospecialize(job)
    return sprint((io, job) -> CUDA.GPUCompiler.code_native(io, job; kwargs...), job; context=:color=>false)
end


function code_sass(job::CUDA.CompilerJob; kwargs...)
    @nospecialize(job)
    return sprint((io, job) -> CUDA.code_sass(io, job; kwargs...), job; context=:color=>false)
end


for func in (:code_cuda_typed, :code_cuda_llvm, :code_ptx, :code_sass)
    cuda_func = startswith(string(func), "cuda_") ? Symbol(:code_, string(func)[6:end]) : Symbol(:code_, func)
    cuda_func_str = string(cuda_func)

    eval(quote
        """
            $($func)(f, types; world=nothing, kwargs...)
            $($func)(job::CUDA.CompilerJob; kwargs...)

        Compare the output of `CUDA.$($cuda_func_str)` with the the different inputs.

        Apart from the method accepting `CUDA.CompilerJob`s, `kwargs` are kwargs to both
        `CUDA.compiler_config` (e.g. `:always_inline`, `:minthreads`, `:blocks_per_sm`, etc...)
        and `CUDA.$($cuda_func_str)` (e.g. `:raw`).
        """
        function $func(f, types; world=nothing, kwargs...)
            @nospecialize(f, types)

            compiler_kwargs, kwargs = CUDA.split_kwargs_runtime(kwargs, CUDA.COMPILER_KWARGS)
            job = gpu_compiler_job(f, types, world; compiler_kwargs...)

            return $func(job; kwargs...)
        end
    end)
end


CodeDiffs.argconvert(::Val{:cuda_typed},  arg) = CUDA.cudaconvert(arg)
CodeDiffs.argconvert(::Val{:cuda_llvm},   arg) = CUDA.cudaconvert(arg)
CodeDiffs.argconvert(::Val{:ptx},         arg) = CUDA.cudaconvert(arg)
CodeDiffs.argconvert(::Val{:cuda_native}, arg) = CUDA.cudaconvert(arg)
CodeDiffs.argconvert(::Val{:sass},        arg) = CUDA.cudaconvert(arg)

@nospecialize

CodeDiffs.get_code_dispatch(::Val{:cuda_typed},  f, types; kwargs...) = code_cuda_typed(f, types; kwargs...)
CodeDiffs.get_code_dispatch(::Val{:cuda_llvm},   f, types; kwargs...) = code_cuda_llvm(f, types; kwargs...)
CodeDiffs.get_code_dispatch(::Val{:ptx},         f, types; kwargs...) = code_ptx(f, types; kwargs...)
CodeDiffs.get_code_dispatch(::Val{:cuda_native}, f, types; kwargs...) = CodeDiffs.get_code_dispatch(Val{:ptx}(), f, types; kwargs...)
CodeDiffs.get_code_dispatch(::Val{:sass},        f, types; kwargs...) = code_sass(f, types; kwargs...)

@specialize


CodeDiffs.code_highlighter(::Val{:cuda_typed})  = CodeDiffs.code_highlighter(Val{:typed}())
CodeDiffs.code_highlighter(::Val{:cuda_llvm})   = (io, str) -> highlight_using_pygments(io, str, "llvm")
CodeDiffs.code_highlighter(::Val{:ptx})         = (io, str) -> highlight_using_pygments(io, str, "ptx")
CodeDiffs.code_highlighter(::Val{:cuda_native}) = CodeDiffs.code_highlighter(Val{:ptx}())

function highlight_using_pygments(io::IO, str::AbstractString, lexer)
    CUDA.GPUCompiler.highlight(io, str, lexer)
end

end
