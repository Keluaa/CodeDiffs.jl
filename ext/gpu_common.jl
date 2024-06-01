
# `GPUCompiler` and `gpu_compiler_kwargs` must be defined before importing this file

function split_kwargs(kwargs, wanted::Vector{Symbol})
    extracted = filter( in(wanted) ∘ first, kwargs)
    remaining = filter(!in(wanted) ∘ first, kwargs)
    return extracted, remaining
end


if pkgversion(GPUCompiler) < v"0.26.2"
    const gpu_method_instance = GPUCompiler.methodinstance
else
    const gpu_method_instance = GPUCompiler.generic_methodinstance
end


function gpu_compiler_job(f, types, world=nothing; kwargs...)
    @nospecialize(f, types)
    tt = Base.to_tuple_type(types)
    ft = Core.Typeof(f)
    if isnothing(world)
        mi = gpu_method_instance(ft, tt)
    else
        error("GPUCompiler.jl ignores the `world` age and works only with the latest methods")
        # mi = gpu_method_instance(ft, tt, world)
    end
    return gpu_compiler_job(mi; kwargs...)
end


for code_func in (:code_gpu_typed, :code_gpu_llvm, :code_gpu_native)
    eval(quote
        function $code_func(f, types; world=nothing, kwargs...)
            @nospecialize(f, types)
            compiler_kwargs, kwargs = split_kwargs(kwargs, gpu_compiler_kwargs())
            job = gpu_compiler_job(f, types, world; compiler_kwargs...)
            return $code_func(job; kwargs...)
        end
    end)
end


function code_gpu_typed(job::GPUCompiler.CompilerJob; kwargs...)
    @nospecialize(job)
    interp = GPUCompiler.get_interpreter(job)
    return CodeDiffs.code_typed(job.source; world=job.world, interp, kwargs...)
end


function code_gpu_llvm(job::GPUCompiler.CompilerJob; kwargs...)
    @nospecialize(job)
    return sprint((io, job) -> GPUCompiler.code_llvm(io, job; kwargs...), job; context=:color=>false)
end


@static !@isdefined(USE_CUSTOM_NATIVE_FUNC) && \
function code_gpu_native(job::GPUCompiler.CompilerJob; kwargs...)
    @nospecialize(job)
    return sprint((io, job) -> GPUCompiler.code_native(io, job; kwargs...), job; context=:color=>false)
end
