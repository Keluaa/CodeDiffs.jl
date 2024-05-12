module CodeDiffsKernelAbstractions

using CodeDiffs
using KernelAbstractions
import KernelAbstractions: Kernel


CodeDiffs.argconvert(@nospecialize(f::Kernel), arg) = KernelAbstractions.argconvert(f, arg)


function CodeDiffs.extract_extra_options(@nospecialize(f::Kernel), kwargs)
    return (; 
        ndrange = get(kwargs, :ndrange, nothing),
        workgroupsize = get(kwargs, :workgroupsize, nothing),
        kernel_instance = f
    )
end


function CodeDiffs.get_code(code_type::Val, f::Kernel, types::Type{<:Tuple};
    ndrange=nothing, workgroupsize=nothing, kernel_instance=nothing, kwargs...
)
    @nospecialize(f, types)

    # TODO: deduce the appropriate `code_type` from the KA backend? (e.g. `:typed` + `CUDABackend` = `:cuda_typed`)

    # Same logic as for `KernelAbstractions.ka_code_typed`
    ndrange, workgroupsize, iterspace, dynamic = KernelAbstractions.launch_config(f, ndrange, workgroupsize)

    if f isa Kernel{KernelAbstractions.CPU}
        block = @inbounds KernelAbstractions.blocks(iterspace)[1]
        ctx = KernelAbstractions.mkcontext(kernel, block, ndrange, iterspace, dynamic)
    else
        ctx = KernelAbstractions.mkcontext(kernel, ndrange, iterspace)
    end

    kernel_args = Tuple{typeof(ctx), types.parameters...}
    return CodeDiffs.get_code(code_type, f, kernel_args; kwargs...)
end


function filter_named_tuple_type(ntt::Type{<:NamedTuple}, to_exclude)
    @nospecialize(ntt)
    names = Symbol[]
    types = Any[]
    for (name, type) in zip(ntt.parameters[1], ntt.parameters[2].parameters)
        name in to_exclude && continue
        push!(names, name)
        push!(types, type)
    end
    return NamedTuple{Tuple(names), Tuple{types...}}
end


function CodeDiffs.get_code(code_type::Val, kwc::(typeof(Core.kwcall)), types::Type{<:Tuple{<:NamedTuple, <:Kernel, Vararg}};
    ndrange=nothing, workgroupsize=nothing, kernel_instance::Kernel, kwargs...
)
    @nospecialize(kwc, types)
    # Since the arguments `types` to the kwcall only contain the type of the kernel, we
    # don't have a `Kernel` instance: therefore we must capture it with `extract_extra_options`
    # and pass it as a kwarg.

    # Same logic as for `KernelAbstractions.ka_code_typed`
    ndrange, workgroupsize, iterspace, dynamic = KernelAbstractions.launch_config(kernel_instance, ndrange, workgroupsize)

    if kernel_instance isa Kernel{KernelAbstractions.CPU}
        block = @inbounds KernelAbstractions.blocks(iterspace)[1]
        ctx = KernelAbstractions.mkcontext(kernel_instance, block, ndrange, iterspace, dynamic)
    else
        ctx = KernelAbstractions.mkcontext(kernel_instance, ndrange, iterspace)
    end

    # Consume the kwargs specfic to KernelAbstractions
    new_kwargs_t = filter_named_tuple_type(types.parameters[1], (:ndrange, :workgroupsize))

    if isempty(new_kwargs_t.parameters[1])
        # No more kwargs: direct call to the internal function
        kernel_args = Tuple{typeof(ctx), types.parameters[3:end]...}
        return CodeDiffs.get_code(code_type, kernel_instance.f, kernel_args; kwargs...)
    else
        # Keep the structure of the kwcall: `Core.kwcall(kwargs, f, args...)`
        kernel_args = Tuple{new_kwargs_t, typeof(kernel_instance.f), typeof(ctx), types.parameters[3:end]...}
        return CodeDiffs.get_code(code_type, kwc, kernel_args; kwargs...)
    end
end

end
