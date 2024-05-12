
function method_instance(sig, world)
    @nospecialize(sig)
    world = UInt64(world)
    @static if VERSION < v"1.10"
        mth_match = Base._which(sig, world)
    else
        mth_match = Base._which(sig; world)
    end
    return Core.Compiler.specialize_method(mth_match)
end


function method_instance(f::Base.Callable, types::Type{<:Tuple}, world=Base.get_world_counter())
    @nospecialize(f, types)
    return method_instance(Base.signature_type(f, types), world)
end


function code_native(f::Base.Callable, types::Type{<:Tuple}, ::Nothing; kwargs...)
    @nospecialize(f, types)
    io_buf = IOBuffer()
    io_ctx = IOContext(io_buf, :color => false)
    InteractiveUtils.code_native(io_ctx, f, types; kwargs...)
    return String(take!(io_buf))
end


function code_native(
    f::Base.Callable, types::Type{<:Tuple}, world::Integer;
    dump_module=true, syntax=:intel, raw=false, debuginfo=:default, binary=false
)
    @nospecialize(f, types)
    mi = method_instance(f, types, world)

    @static if VERSION < v"1.10"
        params = Base.CodegenParams(debug_info_kind=Cint(0))
    else
        params = Base.CodegenParams(debug_info_kind=Cint(0), safepoint_on_entry=raw, gcstack_arg=raw)
    end

    if debuginfo === :default
        debuginfo = :source
    elseif debuginfo !== :source && debuginfo !== :none
        throw(ArgumentError("'debuginfo' must be either :source or :none"))
    end

    # See `InteractiveUtils._dump_function`
    @static if VERSION < v"1.10"
        f_str = InteractiveUtils._dump_function_linfo_native(mi, world, false, syntax, debuginfo, binary)
    else
        if dump_module
            f_str = InteractiveUtils._dump_function_native_assembly(mi, world, false, syntax, debuginfo, binary, raw, params)
        else
            f_str = InteractiveUtils._dump_function_native_disassembly(mi, world, false, syntax, debuginfo, binary)
        end
    end

    return f_str
end


"""
    code_native(f, types; world=nothing, kwargs...)

The native code of the method of `f` called with `types` (a `Tuple` type), as a string.
`world` defaults to the current world age.
`kwargs` are forwarded to `InteractiveUtils.code_native`.
"""
code_native(@nospecialize(f), @nospecialize(types); world=nothing, kwargs...) =
    code_native(f, types, world; kwargs...)


function code_llvm(f::Base.Callable, types::Type{<:Tuple}, ::Nothing; kwargs...)
    @nospecialize(f, types)
    io_buf = IOBuffer()
    io_ctx = IOContext(io_buf, :color => false)
    InteractiveUtils.code_llvm(io_ctx, f, types; kwargs...)
    return String(take!(io_buf))
end


function code_llvm(
    f::Base.Callable, types::Type{<:Tuple}, world::Integer;
    raw=false, dump_module=false, optimize=true, debuginfo=:default
)
    @nospecialize(f, types)
    mi = method_instance(f, types, world)

    @static if VERSION < v"1.10"
        params = Base.CodegenParams(debug_info_kind=Cint(0))
    else
        params = Base.CodegenParams(debug_info_kind=Cint(0), safepoint_on_entry=raw, gcstack_arg=raw)
    end

    if debuginfo === :default
        debuginfo = :source
    elseif debuginfo !== :source && debuginfo !== :none
        throw(ArgumentError("'debuginfo' must be either :source or :none"))
    end

    # See `InteractiveUtils._dump_function`
    @static if VERSION < v"1.10"
        f_str = InteractiveUtils._dump_function_linfo_llvm(
            mi, world, false, !raw, dump_module, optimize, debuginfo, params
        )
    else
        f_str = InteractiveUtils._dump_function_llvm(
            mi, world, false, !raw, dump_module, optimize, debuginfo, params
        )
    end

    return f_str
end


"""
    code_llvm(f, types; world=nothing, kwargs...)

The LLVM-IR code of the method of `f` called with `types` (a `Tuple` type), as a string.
`world` defaults to the current world age.
`kwargs` are forwarded to `InteractiveUtils.code_native`.
"""
code_llvm(@nospecialize(f), @nospecialize(types); world=nothing, kwargs...) =
    code_llvm(f, types, world; kwargs...)


"""
    code_typed(f, types; world=nothing, kwargs...)

The Julia-IR code (aka 'typed code') of the method of `f` called with `types`
(a `Tuple` type), as a `Core.CodeInfo`.
`world` defaults to the current world age.
`kwargs` are forwarded to `Base.code_typed`.

The function call should only match a single method.
"""
function code_typed(f, types; world=nothing, kwargs...)
    @nospecialize(f, types)
    if isnothing(world)
        code_info = Base.code_typed(f, types; kwargs...)
    else
        code_info = Base.code_typed(f, types; world, kwargs...)
    end
    return only(code_info)
end

function code_typed(mi::Core.MethodInstance; world=nothing, kwargs...)
    sig = mi.specTypes
    if isnothing(world)
        code_info = Base.code_typed_by_type(sig; kwargs...)
    else
        code_info = Base.code_typed_by_type(sig; world, kwargs...)
    end
    return only(code_info)
end


function method_to_ast(method::Method)
    ast = CodeTracking.definition(Expr, method)
    if isnothing(ast)
        if !haskey(Base.loaded_modules, Revise_PKG_ID)
            error("cannot retrieve the AST definition of `$(method.name)` as Revise.jl is not loaded")
        else
            error("could not retrieve the AST definition of `$(method.sig)` at world age $(method.primary_world)")
        end
    end
    return ast
end

method_to_ast(mi::Core.MethodInstance) = method_to_ast(mi.def)

function method_to_ast(f::Base.Callable, types::Type{<:Tuple}; world=nothing)
    @nospecialize(f, types)
    if !isnothing(world)
        error("Revise.jl does not keep track of previous definitions: \
               cannot get the AST from a previous world age")
    end
    mi = method_instance(f, types)
    return method_to_ast(mi)
end


"""
    code_ast(f, types; world=nothing, prettify=true, lines=false, alias=false)

The Julia AST of the method of `f` called with `types` (a `Tuple` type), as a `Expr`.
[`Revise.jl`](https://github.com/timholy/Revise.jl) is used to get those definitions, and
it must be loaded **before** the definition of `f`'s method to get the AST for.

`world` defaults to the current world age. Since `Revise.jl` does not keep track of all
definitions in all world ages, it is very likely that the only retrievable definition is
the most recent one.

If `prettify == true`, then [`MacroTools.prettify(code; lines, alias)`](https://fluxml.ai/MacroTools.jl/stable/utilities/#MacroTools.prettify)
is used to cleanup the AST. `lines == true` will keep the `LineNumberNode`s and `alias == true`
will replace mangled names (or `gensym`s) by more readable names.
"""
function code_ast(f::Base.Callable, types::Type{<:Tuple}; prettify=true, lines=false, alias=false, kwargs...)
    @nospecialize(f, types)
    code = method_to_ast(f, types; kwargs...)
    return code_ast(code; prettify, lines, alias)
end

function code_ast(code::QuoteNode; kwargs...)
    return code_ast(Expr(:quote, Expr(:block, code.value)); kwargs...)
end

function code_ast(code::Expr; prettify=true, lines=false, alias=false)
    if prettify
        code = MacroTools.prettify(code; lines, alias)
    end
    # Placing the `Expr`s in blocks is required to have a multiline display
    return MacroTools.block(code)
end


@nospecialize

"""
    get_code(::Val{code_type}, f, types; world=nothing, kwargs...)

The code object of `code_type` for `f`. Dispatch depends on `code_type`:
 - `:native`: [`code_native`](@ref)
 - `:llvm`: [`code_llvm`](@ref)
 - `:typed`: [`code_typed`](@ref)
 - `:ast`: [`code_ast`](@ref)
"""
get_code(code_type, f, types; kwargs...) = get_code_dispatch(code_type, f, types; kwargs...)

# By specializing the `code_type` only in `get_code_dispatch`, we prevent any method
# ambiguities (e.g. with the KernelAbstractions extension)
get_code_dispatch(::Val{:native}, f, types; kwargs...) = code_native(f, types; kwargs...)
get_code_dispatch(::Val{:llvm},   f, types; kwargs...) = code_llvm(f, types; kwargs...)
get_code_dispatch(::Val{:typed},  f, types; kwargs...) = code_typed(f, types; kwargs...)
get_code_dispatch(::Val{:ast},    f, types; kwargs...) = code_ast(f, types; kwargs...)

@specialize
