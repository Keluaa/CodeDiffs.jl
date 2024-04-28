
"""
    LLVM_MODULE_NAME_REGEX

Should match the LLVM module of any function which does not have any of `'",;-` or spaces
in it.

It is `'get_function_name'`, in `'julia/src/codegen.cpp'` which builds the function name
for the LLVM module used to get the function code. The regex is built to match any output
from that function.
Since the `'globalUniqueGeneratedNames'` counter (the number at the end of the module name)
is incremented at each call to `'get_function_name'`, and since `code_llvm` or `code_native`
forces a compilation, it should be guaranteed that the match with the highest number at
the end is the name of our function in `code`.
"""
const LLVM_MODULE_NAME_REGEX = r"(?>julia|japi3|japi1)_([^\"\s,;\-']*)_(\d+)"


"""
    replace_llvm_module_name(code::AbstractString)

Remove in `code` the trailing numbers in the LLVM module names, e.g. `"julia_f_2007" => "f"`.
This allows to remove false differences when comparing raw code, since each call to
`code_native` (or `code_llvm`) triggers a new compilation using an unique LLVM module name,
therefore each consecutive call is different even though the actual code does not
change.

```jldoctest; setup = :(using InteractiveUtils; import CodeDiffs: replace_llvm_module_name)
julia> f() = 1
f (generic function with 1 method)

julia> buf = IOBuffer();

julia> code_native(buf, f, Tuple{})  # Equivalent to `@code_native f()`

julia> code₁ = String(take!(buf));

julia> code_native(buf, f, Tuple{})

julia> code₂ = String(take!(buf));

julia> code₁ == code₂  # Different LLVM module names...
false

julia> replace_llvm_module_name(code₁) == replace_llvm_module_name(code₂)  # ...but same code
true
```
"""
replace_llvm_module_name(code::AbstractString) = replace(code, LLVM_MODULE_NAME_REGEX => s"\1")


"""
    replace_llvm_module_name(code::AbstractString, function_name)

Replace only LLVM module names for `function_name`.
"""
function replace_llvm_module_name(code::AbstractString, function_name)
    function_name = string(function_name)
    if Sys.islinux() && startswith(function_name, '@')
        # See 'get_function_name' in 'julia/src/codegen.cpp'
        function_name = function_name[2:end]
    end
    func_re = Regex("(?>julia|japi3|japi1)_\\Q$(function_name)\\E_(\\d+)")
    return replace(code, func_re => function_name)
end


compare_code(code₁::AbstractString, code₂::AbstractString, highlight_func; kwargs...) =
    compare_code(String(code₁), String(code₂), highlight_func; kwargs...)

function compare_code(code₁::String, code₂::String, highlight_func; color=true)
    io_buf = IOBuffer()
    highlight_ctx = IOContext(io_buf, :color => true)

    code₁ = replace_llvm_module_name(code₁)
    if color
        highlight_func(highlight_ctx, code₁)
        code₁_colored = String(take!(io_buf))
    else
        code₁_colored = code₁
    end

    code₂ = replace_llvm_module_name(code₂)
    if color
        highlight_func(highlight_ctx, code₂)
        code₂_colored = String(take!(io_buf))
    else
        code₂_colored = code₂
    end

    if endswith(code₁, '\n') && endswith(code₂, '\n')
        code₁ = rstrip(==('\n'), code₁)
        code₁_colored = rstrip(==('\n'), code₁_colored)
        code₂ = rstrip(==('\n'), code₂)
        code₂_colored = rstrip(==('\n'), code₂_colored)
    end

    diff = CodeDiff(code₁, code₂, code₁_colored, code₂_colored)
    optimize_line_changes!(diff)
    return diff
end


function show_as_string(a, color::Bool)
    io_buf = IOBuffer()

    Base.show(IOContext(io_buf, :color => false), MIME"text/plain"(), a)
    a_str = String(take!(io_buf))

    if color
        Base.show(IOContext(io_buf, :color => true), MIME"text/plain"(), a)
        a_colored = String(take!(io_buf))
    else
        a_colored = a_str
    end

    return a_str, a_colored
end


function show_as_string(s::AbstractString, color::Bool)
    io_buf = IOBuffer()

    # For `AnnotatedString` => get the unannotated string
    a_str = String(s)

    if color
        # Use `print` instead of `Base.show(io, MIME"text/plain", s)` to avoid quotes and
        # escape sequences.
        print(IOContext(io_buf, :color => true), s)
        a_colored = String(take!(io_buf))
    else
        a_colored = a_str
    end

    return a_str, a_colored
end


function compare_show(code₁, code₂; color=true, force_no_ansi=false)
    code₁_str, code₁_colored = show_as_string(code₁, color)
    code₂_str, code₂_colored = show_as_string(code₂, color)

    if force_no_ansi
        code₁_str = replace(code₁_str, ANSI_REGEX => "")
        code₂_str = replace(code₂_str, ANSI_REGEX => "")
    end

    # Hack to make sure `deepdiff` creates a `StringLineDiff`
    if !occursin('\n', code₁_str)
        code₁_str *= '\n'
        code₁_colored *= '\n'
    end
    if !occursin('\n', code₂_str)
        code₂_str *= '\n'
        code₂_colored *= '\n'
    end

    if endswith(code₁_str, '\n') && endswith(code₂_str, '\n') &&
            count(==('\n'), code₁_str) > 1 && count(==('\n'), code₂_str) > 1
        # Strip the last newline only if there is more than one
        code₁_str = rstrip(==('\n'), code₁_str)
        code₂_str = rstrip(==('\n'), code₂_str)
        code₁_colored = rstrip(==('\n'), code₁_colored)
        code₂_colored = rstrip(==('\n'), code₂_colored)
    end

    diff = CodeDiff(code₁_str, code₂_str, code₁_colored, code₂_colored)
    optimize_line_changes!(diff)
    return diff
end


function method_instance(sig, world)
    @nospecialize(sig)
    @static if VERSION < v"1.10"
        mth_match = Base._which(sig, world)
    else
        mth_match = Base._which(sig; world)
    end
    return Core.Compiler.specialize_method(mth_match)
end


function method_instance(f, types, world)
    @nospecialize(f, types)
    return method_instance(Base.signature_type(f, types), world)
end


"""
    compare_code_native(code₁, code₂; color=true)

Return a [`CodeDiff`](@ref) between `code₁` and `code₂`.
Codes are cleaned-up with [`replace_llvm_module_name`](@ref) beforehand.

If `color == true`, then both codes are highlighted using `InteractiveUtils.print_native`.
"""
function compare_code_native(code₁::AbstractString, code₂::AbstractString; color=true)
    return compare_code(code₁, code₂, InteractiveUtils.print_native; color)
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
    compare_code_native(
        f₁::Base.Callable, types₁::Type{<:Tuple},
        f₂::Base.Callable, types₂::Type{<:Tuple};
        color=true, world_1=nothing, world_2=nothing, kwargs...
    )

Call `InteractiveUtils.code_native(f₁, types₁)` and `InteractiveUtils.code_native(f₂, types₂)`
and return their [`CodeDiff`](@ref). `kwargs` are passed to `code_native`.

`world_1` and `world_2` are the world ages in which to compare `f₁` and `f₂`.
It defaults to the current world age.
"""
function compare_code_native(
    f₁::Base.Callable, types₁::Type{<:Tuple},
    f₂::Base.Callable, types₂::Type{<:Tuple};
    color=true, world_1=nothing, world_2=nothing, kwargs...
)
    @nospecialize(f₁, types₁, f₂, types₂)
    code₁ = code_native(f₁, types₁, world_1; kwargs...)
    code₂ = code_native(f₂, types₂, world_2; kwargs...)
    return compare_code_native(code₁, code₂; color)
end


"""
    compare_code_llvm(code₁, code₂; color=true)

Return a [`CodeDiff`](@ref) between `code₁` and `code₂`.
Codes are cleaned-up with [`replace_llvm_module_name`](@ref) beforehand.

If `color == true`, then both codes are highlighted using `InteractiveUtils.print_llvm`.
"""
function compare_code_llvm(code₁::AbstractString, code₂::AbstractString; color=true)
    return compare_code(code₁, code₂, InteractiveUtils.print_llvm; color)
end


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
    compare_code_llvm(
        f₁::Base.Callable, types₁::Type{<:Tuple},
        f₂::Base.Callable, types₂::Type{<:Tuple};
        color=true, world_1=nothing, world_2=nothing, kwargs...
    )

Call `InteractiveUtils.code_llvm(f₁, types₁)` and `InteractiveUtils.code_llvm(f₂, types₂)`
and return their [`CodeDiff`](@ref). `kwargs` are passed to `code_llvm`.

`world_1` and `world_2` are the world ages in which to compare `f₁` and `f₂`.
It defaults to the current world age.
"""
function compare_code_llvm(
    f₁::Base.Callable, types₁::Type{<:Tuple},
    f₂::Base.Callable, types₂::Type{<:Tuple};
    color=true, world_1=nothing, world_2=nothing, kwargs...
)
    @nospecialize(f₁, types₁, f₂, types₂)
    code₁ = code_llvm(f₁, types₁, world_1; kwargs...)
    code₂ = code_llvm(f₂, types₂, world_2; kwargs...)
    return compare_code_llvm(code₁, code₂; color)
end


"""
    compare_code_typed(code_info₁::Pair, code_info₂::Pair; color=true)
    compare_code_typed(code_info₁::Core.CodeInfo, code_info₂::Core.CodeInfo; color=true)

Return a [`CodeDiff`](@ref) between `code_info₁` and `code_info₂`.

If `color == true`, then both codes are highlighted.
"""
function compare_code_typed(
    code_info₁::CI, code_info₂::CI; color=true
) where {CI <: Union{Core.CodeInfo, Pair{Core.CodeInfo, <:Type}}}
    return compare_show(code_info₁, code_info₂; color)
end


function code_typed(f, types, world=nothing; kwargs...)
    @nospecialize(f, types)
    if isnothing(world)
        code_info = Base.code_typed(f, types; kwargs...)
    else
        code_info = Base.code_typed(f, types; world, kwargs...)
    end
    return only(code_info)
end


"""
    compare_code_typed(
        f₁::Base.Callable, types₁::Type{<:Tuple},
        f₂::Base.Callable, types₂::Type{<:Tuple};
        color=true, world_1=nothing, world_2=nothing, kwargs...
    )

Call `Base.code_typed(f₁, types₁)` and `Base.code_typed(f₂, types₂)` and return their
[`CodeDiff`](@ref). `kwargs` are passed to `code_typed`.

Both function calls should only match a single method.

`world_1` and `world_2` are the world ages in which to compare `f₁` and `f₂`.
It defaults to the current world age.
"""
function compare_code_typed(
    f₁::Base.Callable, types₁::Type{<:Tuple},
    f₂::Base.Callable, types₂::Type{<:Tuple};
    color=true, world_1=nothing, world_2=nothing, kwargs...
)
    @nospecialize(f₁, types₁, f₂, types₂)
    code_info₁ = code_typed(f₁, types₁, world_1; kwargs...)
    code_info₂ = code_typed(f₂, types₂, world_2; kwargs...)
    return compare_code_typed(code_info₁, code_info₂; color)
end


"""
    compare_ast(code₁::Expr, code₂::Expr; color=true, prettify=true, lines=false, alias=false)

A [`CodeDiff`](@ref) between `code₁` and `code₂`, relying on the native display of Julia AST.

If `prettify == true`, then
[`MacroTools.prettify(code; lines, alias)`](https://fluxml.ai/MacroTools.jl/stable/utilities/#MacroTools.prettify)
is used to cleanup the AST. `lines == true` will keep the `LineNumberNode`s and `alias == true`
will replace mangled names (or `gensym`s) by dummy names.

`color == true` is special, see [`compare_ast(code₁::AbstractString, code₂::AbstractString)`](@ref).
"""
function compare_ast(code₁::Expr, code₂::Expr; color=true, prettify=true, lines=false, alias=false)
    if prettify
        code₁ = MacroTools.prettify(code₁; lines, alias)
        code₂ = MacroTools.prettify(code₂; lines, alias)
    end

    # Placing the `Expr`s in blocks is required to have a multiline display
    code₁ = MacroTools.block(code₁)
    code₂ = MacroTools.block(code₂)

    if color
        io_buf = IOBuffer()

        print(io_buf, code₁)
        code_str₁ = String(take!(io_buf))

        print(io_buf, code₂)
        code_str₂ = String(take!(io_buf))

        return compare_ast(code_str₁, code_str₂)
    else
        return compare_show(code₁, code₂; color=false)
    end
end


"""
    compare_ast(code₁::AbstractString, code₂::AbstractString; color=true)
    compare_ast(code₁::Markdown.MD, code₂::Markdown.MD; color=true)

[`CodeDiff`](@ref) between Julia code string, in the form of Markdown code blocks.

Relies on the Markdown code highlighting from [`OhMyREPL.jl`](https://github.com/KristofferC/OhMyREPL.jl)
to colorize Julia code.
"""
function compare_ast(code₁::Markdown.MD, code₂::Markdown.MD; color=true)
    if !haskey(Base.loaded_modules, OhMYREPL_PKG_ID)
        @warn "OhMyREPL.jl is not loaded, AST highlighting will not work" maxlog=1
    end
    return compare_show(code₁, code₂; color, force_no_ansi=true)
end


function compare_ast(code₁::AbstractString, code₂::AbstractString; color=true)
    code_md₁ = Markdown.MD(Markdown.julia, Markdown.Code("julia", code₁))
    code_md₂ = Markdown.MD(Markdown.julia, Markdown.Code("julia", code₂))
    return compare_ast(code_md₁, code_md₂; color)
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

function method_to_ast(f::Base.Callable, types::Type{<:Tuple}, world=Base.get_world_counter())
    @nospecialize(f, types)
    sig = Base.signature_type(f, types)
    mi = method_instance(sig, world)
    return method_to_ast(mi)
end


"""
    compare_ast(
        f₁::Base.Callable, types₁::Type{<:Tuple},
        f₂::Base.Callable, types₂::Type{<:Tuple};
        color=true, kwargs...
    )

Retrieve the AST for the definitions of the methods matching the calls to `f₁` and `f₂`
using [`CodeTracking.jl`](https://github.com/timholy/CodeTracking.jl), then compare them.

For `CodeTracking.jl` to work, [`Revise.jl`](https://github.com/timholy/Revise.jl) must be
loaded.
"""
function compare_ast(
    f₁::Base.Callable, types₁::Type{<:Tuple},
    f₂::Base.Callable, types₂::Type{<:Tuple};
    world_1=nothing, world_2=nothing, kwargs...
)
    @nospecialize(f₁, types₁, f₂, types₂)
    if !isnothing(world_1) || !isnothing(world_2)
        error("world age comparison is not possible with AST, as Revise.jl does not track \
               of definitions across ages")
    end
    code₁ = method_to_ast(f₁, types₁)
    code₂ = method_to_ast(f₂, types₂)
    return compare_ast(code₁, code₂; kwargs...)
end


"""
    code_diff(::Val{:ast}, code₁, code₂; kwargs...)

Compare AST in `code₁` and `code₂`, which can be `Expr` or any `AbstractString`.
"""
code_diff(::Val{:ast}, code₁, code₂; kwargs...) = compare_ast(code₁, code₂; kwargs...)

code_diff(::Val{:native}, code₁::AbstractString, code₂::AbstractString; kwargs...) =
    compare_code(code₁, code₂, InteractiveUtils.print_native; kwargs...)
code_diff(::Val{:llvm},   code₁::AbstractString, code₂::AbstractString; kwargs...) =
    compare_code(code₁, code₂, InteractiveUtils.print_llvm; kwargs...)
code_diff(::Val{:typed},  code₁::AbstractString, code₂::AbstractString; kwargs...) =
    compare_code(code₁, code₂, identity; kwargs...)

"""
    code_diff(::Val{type}, f₁, types₁, f₂, types₂; kwargs...)
    code_diff(::Val{type}, code₁, code₂; kwargs...)
    code_diff(args...; type=:native, kwargs...)

Dispatch to [`compare_code_native`](@ref), [`compare_code_llvm`](@ref),
[`compare_code_typed`](@ref) or [`compare_ast`](@ref) depending on `type`.
"""
code_diff(code₁, code₂; type::Symbol=:native, kwargs...) =
    code_diff(Val(type), code₁, code₂; kwargs...)

@nospecialize

code_diff(::Val{:native}, f₁, types₁, f₂, types₂; kwargs...) = compare_code_native(f₁, types₁, f₂, types₂; kwargs...)
code_diff(::Val{:llvm},   f₁, types₁, f₂, types₂; kwargs...) = compare_code_llvm(f₁, types₁, f₂, types₂; kwargs...)
code_diff(::Val{:typed},  f₁, types₁, f₂, types₂; kwargs...) = compare_code_typed(f₁, types₁, f₂, types₂; kwargs...)
code_diff(::Val{:ast},    f₁, types₁, f₂, types₂; kwargs...) = compare_ast(f₁, types₁, f₂, types₂; kwargs...)

code_diff(code₁::Tuple, code₂::Tuple; type::Symbol=:native, kwargs...) =
    code_diff(Val(type), code₁..., code₂...; kwargs...)

@specialize


function replace_locals_by_gensyms(expr)
    Base.isexpr(expr, :call) && expr.args[1] === :error     && return expr, Expr(:block)
    Base.isexpr(expr, :call) && expr.args[1] === :code_diff && return Expr(:block), expr

    call_expr = pop!(expr.args)
    if !(Base.isexpr(call_expr, :call) && call_expr.args[1] === :code_diff)
        error("expected call to `code_diff`, got: $call_expr")
    end

    locals = Symbol[]
    locals = Dict{Symbol, Symbol}()
    # Replace `a` or `(a, b)` in `local a = 1`. We suppose `expr` is the result of
    # `InteractiveUtils.gen_call_with_extracted_types`, therefore there is less edge cases
    # to care about.
    expr = MacroTools.postwalk(expr) do e
        !Base.isexpr(e, :local) && return e
        assign = e.args[1]
        !Base.isexpr(assign, :(=)) && error("unexpected `local` expression: $e")
        if Base.isexpr(assign.args[1], :tuple)
            l_vars = assign.args[1]
            map!(l_vars.args, l_vars.args) do l
                locals[l] = gensym(l)
            end
        elseif Base.isexpr(assign.args[1], :call)
            # alias for dot function, already a gensym
        else
            l = assign.args[1]
            assign.args[1] = locals[l] = gensym(l)
        end
        return Expr(:local, assign)
    end

    # We assume that all `locals` defined in `expr` are only used in the last expression,
    # the `call(:code_diff, ...)`, which is true since `code_diff` starts with `code_`.
    call_expr = MacroTools.postwalk(call_expr) do e
        !(e isa Symbol) && return e
        return get(locals, e, e)
    end

    if Base.isexpr(call_expr.args[2], :parameters)
        !isempty(call_expr.args[2].args) && error("unexpected kwargs: $call_expr")
        popat!(call_expr.args, 2)  # Remove the kwargs
    end

    return expr, call_expr
end


"""
    @code_diff [type=:native] [option=value...] f₁(...) f₂(...)
    @code_diff [option=value...] :(expr₁) :(expr₂)

Compare the methods called by the `f₁(...)` and `f₂(...)` expressions, and return a
[`CodeDiff`](@ref).

`option`s are passed as key-word arguments to [`code_diff`](@ref) and then to the
`compare_code_*` function for the given code `type`.

In the other form of `@code_diff`, compare the `Expr`essions `expr₁` and `expr₂`, the `type`
is inferred as `:ast`.
To compare `Expr` in variables, use `@code_diff :(\$a) :(\$b)`, or call
[`compare_ast`](@ref) directly.
"""
macro code_diff(args...)
    length(args) < 2 && throw(ArgumentError("@code_diff takes at least 2 arguments"))
    options = args[1:end-2]
    code₁, code₂ = args[end-1:end]

    options = map(options) do option
        !(option isa Expr && option.head === :(=)) &&
            throw(ArgumentError("options must be in the form `key=value`, got: $option"))
        return Expr(:kw, esc(option.args[1]), esc(option.args[2]))
    end

    # Simple values such as `:(1)` are stored in a `QuoteNode`
    code₁ isa QuoteNode && (code₁ = Expr(:quote, Expr(:block, code₁.value)))
    code₂ isa QuoteNode && (code₂ = Expr(:quote, Expr(:block, code₂.value)))

    if Base.isexpr(code₁, :quote) && Base.isexpr(code₂, :quote)
        code₁ = esc(code₁)
        code₂ = esc(code₂)
        call_code_diff = :($code_diff($code₁, $code₂; type=:ast))
        append!(call_code_diff.args[2].args, options)
        return call_code_diff
    else
        expr₁ = InteractiveUtils.gen_call_with_extracted_types(__module__, :code_diff, code₁)
        expr₂ = InteractiveUtils.gen_call_with_extracted_types(__module__, :code_diff, code₂)

        # `gen_call_with_extracted_types` will, to handle some specific calls, store some
        # values in local variables with a fixed name. This is a problem as we might use
        # the same variable name twice since we want to fuse `expr₁` and `expr₂`.
        expr₁, call_expr₁ = replace_locals_by_gensyms(expr₁)
        expr₂, call_expr₂ = replace_locals_by_gensyms(expr₂)

        if Base.isexpr(call_expr₁, :call) && Base.isexpr(call_expr₂, :call)
            # Fuse both calls to `code_diff`, into a single kwcall
            call_code_diff = :($code_diff(
                ($(call_expr₁.args[2:3]...),),
                ($(call_expr₂.args[2:3]...),);
            ))
            append!(call_code_diff.args[2].args, options)
        else
            call_code_diff = call_expr₁  # `expr₁` or `expr₂` has an error expression
        end

        return MacroTools.flatten(Expr(:block, expr₁, expr₂, call_code_diff))
    end
end
