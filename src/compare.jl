
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


function compare_code(code₁::AbstractString, code₂::AbstractString, highlight_func; color=true)
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


function compare_show(code₁, code₂; color=true, force_no_ansi=false)
    io_buf = IOBuffer()
    io_ctx = IOContext(io_buf, :color => false)
    highlight_ctx = IOContext(io_buf, :color => true)

    Base.show(io_ctx, MIME"text/plain"(), code₁)
    code_str₁ = String(take!(io_buf))
    force_no_ansi && (code_str₁ = replace(code_str₁, ANSI_REGEX => ""))
    if !occursin('\n', code_str₁)
        code_str₁ *= '\n'  # Hack to make sure `deepdiff` creates a `StringLineDiff`
        needed_newline = true
    else
        needed_newline = false
    end

    if color
        Base.show(highlight_ctx, MIME"text/plain"(), code₁)
        code₁_colored = String(take!(io_buf)) * (needed_newline ? "\n" : "")
    else
        code₁_colored = code_str₁
    end

    Base.show(io_ctx, MIME"text/plain"(), code₂)
    code_str₂ = String(take!(io_buf))
    force_no_ansi && (code_str₂ = replace(code_str₂, ANSI_REGEX => ""))
    if !occursin('\n', code_str₂)
        code_str₂ *= '\n'
        needed_newline = true
    else
        needed_newline = false
    end

    if color
        Base.show(highlight_ctx, MIME"text/plain"(), code₂)
        code₂_colored = String(take!(io_buf)) * (needed_newline ? "\n" : "")
    else
        code₂_colored = code_str₂
    end

    if !needed_newline && endswith(code_str₁, '\n') && endswith(code_str₂, '\n') &&
            count(==('\n'), code_str₁) > 1 && count(==('\n'), code_str₂) > 1
        # Strip the last newline only if there is more than one, for the same reason as to
        # why `needed_newline` exists.
        code_str₁ = rstrip(==('\n'), code_str₁)
        code₁_colored = rstrip(==('\n'), code₁_colored)
        code_str₂ = rstrip(==('\n'), code_str₂)
        code₂_colored = rstrip(==('\n'), code₂_colored)
    end

    diff = CodeDiff(code_str₁, code_str₂, code₁_colored, code₂_colored)
    optimize_line_changes!(diff)
    return diff
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


"""
    compare_code_native(
        f₁::Base.Callable, types₁::Type{<:Tuple},
        f₂::Base.Callable, types₂::Type{<:Tuple};
        color=true, kwargs...
    )

Call `InteractiveUtils.code_native(f₁, types₁)` and `InteractiveUtils.code_native(f₂, types₂)`
and return their [`CodeDiff`](@ref). `kwargs` are passed to `code_native`.
"""
function compare_code_native(
    f₁::Base.Callable, types₁::Type{<:Tuple},
    f₂::Base.Callable, types₂::Type{<:Tuple};
    color=true, kwargs...
)
    @nospecialize(f₁, types₁, f₂, types₂)

    io_buf = IOBuffer()
    io_ctx = IOContext(io_buf, :color => false)

    InteractiveUtils.code_native(io_ctx, f₁, types₁; kwargs...)
    code₁ = String(take!(io_buf))

    InteractiveUtils.code_native(io_buf, f₂, types₂; kwargs...)
    code₂ = String(take!(io_buf))

    return compare_code_native(code₁, code₂; color)
end


function method_instance(sig, world)
    @static if VERSION < v"1.10"
        mth_match = Base._which(sig, world)
    else
        mth_match = Base._which(sig; world)
    end
    return Core.Compiler.specialize_method(mth_match)
end


"""
    compare_code_native(
        f::Base.Callable, types::Type{<:Tuple}, world₁, world₂;
        color=true, kwargs...
    )

Similar to [`compare_code_native(f₁, types₁, f₂, types₂)`](@ref), but as a difference
between `f` in world ages `world₁` and `world₂`.
"""
function compare_code_native(
    f::Base.Callable, types::Type{<:Tuple}, world₁::Integer, world₂::Integer;
    color=true, dump_module=true, syntax=:intel, raw=false, debuginfo=:default, binary=false
)
    @nospecialize(f, types)

    sig = Base.signature_type(f, types)
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
    mi_f₁ = method_instance(sig, world₁)
    @static if VERSION < v"1.10"
        f₁_str = InteractiveUtils._dump_function_linfo_native(mi_f₁, world₁, false, syntax, debuginfo, binary)
    else
        if dump_module
            f₁_str = InteractiveUtils._dump_function_native_assembly(mi_f₁, world₁, false, syntax, debuginfo, binary, raw, params)
        else
            f₁_str = InteractiveUtils._dump_function_native_disassembly(mi_f₁, world₁, false, syntax, debuginfo, binary)
        end
    end

    mi_f₂ = method_instance(sig, world₂)
    @static if VERSION < v"1.10"
        f₂_str = InteractiveUtils._dump_function_linfo_native(mi_f₂, world₂, false, syntax, debuginfo, binary)
    else
        if dump_module
            f₂_str = InteractiveUtils._dump_function_native_assembly(mi_f₂, world₂, false, syntax, debuginfo, binary, raw, params)
        else
            f₂_str = InteractiveUtils._dump_function_native_disassembly(mi_f₂, world₂, false, syntax, debuginfo, binary)
        end
    end

    return compare_code_native(f₁_str, f₂_str; color)
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


"""
    compare_code_llvm(
        f₁::Base.Callable, types₁::Type{<:Tuple},
        f₂::Base.Callable, types₂::Type{<:Tuple};
        color=true, kwargs...
    )

Call `InteractiveUtils.code_llvm(f₁, types₁)` and `InteractiveUtils.code_llvm(f₂, types₂)`
and return their [`CodeDiff`](@ref). `kwargs` are passed to `code_llvm`.
"""
function compare_code_llvm(
    f₁::Base.Callable, types₁::Type{<:Tuple},
    f₂::Base.Callable, types₂::Type{<:Tuple};
    color=true, kwargs...
)
    @nospecialize(f₁, types₁, f₂, types₂)

    io_buf = IOBuffer()
    io_ctx = IOContext(io_buf, :color => false)

    InteractiveUtils.code_llvm(io_ctx, f₁, types₁; kwargs...)
    code₁ = String(take!(io_buf))

    InteractiveUtils.code_llvm(io_buf, f₂, types₂; kwargs...)
    code₂ = String(take!(io_buf))

    return compare_code_llvm(code₁, code₂; color)
end


"""
    compare_code_llvm(
        f::Base.Callable, types::Type{<:Tuple}, world₁, world₂;
        color=true, kwargs...
    )

Similar to [`compare_code_llvm(f₁, types₁, f₂, types₂)`](@ref), but as a difference
between `f` in world ages `world₁` and `world₂`.
"""
function compare_code_llvm(
    f::Base.Callable, types::Type{<:Tuple}, world₁::Integer, world₂::Integer;
    color=true, raw=false, dump_module=false, optimize=true, debuginfo=:default
)
    @nospecialize(f, types)

    sig = Base.signature_type(f, types)
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
    mi_f₁ = method_instance(sig, world₁)
    @static if VERSION < v"1.10"
        f₁_str = InteractiveUtils._dump_function_linfo_llvm(
            mi_f₁, world₁, false, !raw, dump_module, optimize, debuginfo, params
        )
    else
        f₁_str = InteractiveUtils._dump_function_llvm(
            mi_f₁, world₁, false, !raw, dump_module, optimize, debuginfo, params
        )
    end

    mi_f₂ = method_instance(sig, world₂)
    @static if VERSION < v"1.10"
        f₂_str = InteractiveUtils._dump_function_linfo_llvm(
            mi_f₂, world₂, false, !raw, dump_module, optimize, debuginfo, params
        )
    else
        f₂_str = InteractiveUtils._dump_function_llvm(
            mi_f₂, world₂, false, !raw, dump_module, optimize, debuginfo, params
        )
    end

    return compare_code_llvm(f₁_str, f₂_str; color)
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


"""
    compare_code_typed(
        f₁::Base.Callable, types₁::Type{<:Tuple},
        f₂::Base.Callable, types₂::Type{<:Tuple};
        color=true, kwargs...
    )

Call `Base.code_typed(f₁, types₁)` and `Base.code_typed(f₂, types₂)` and return their
[`CodeDiff`](@ref). `kwargs` are passed to `code_typed`.

Both function calls should only match a single method.
"""
function compare_code_typed(
    f₁::Base.Callable, types₁::Type{<:Tuple},
    f₂::Base.Callable, types₂::Type{<:Tuple};
    color=true, kwargs...
)
    @nospecialize(f₁, types₁, f₂, types₂)

    code_info₁ = Base.code_typed(f₁, types₁; kwargs...)
    code_info₁ = only(code_info₁)

    code_info₂ = Base.code_typed(f₂, types₂; kwargs...)
    code_info₂ = only(code_info₂)

    return compare_code_typed(code_info₁, code_info₂; color)
end


"""
    compare_code_typed(
        f::Base.Callable, types::Type{<:Tuple}, world₁, world₂;
        color=true, kwargs...
    )

Similar to [`compare_code_typed(f₁, types₁, f₂, types₂)`](@ref), but as a difference
between `f` in world ages `world₁` and `world₂`.
"""
function compare_code_typed(
    f::Base.Callable, types::Type{<:Tuple}, world₁::Integer, world₂::Integer;
    color=true, kwargs...
)
    @nospecialize(f, types)

    code_info₁ = Base.code_typed(f, types; world=world₁, kwargs...)
    code_info₁ = only(code_info₁)

    code_info₂ = Base.code_typed(f, types; world=world₂, kwargs...)
    code_info₂ = only(code_info₂)

    return compare_code_typed(code_info₁, code_info₂; color)
end


"""
    compare_ast(code₁::Expr, code₂::Expr; color=true, prettify=true, lines=false, alias=false)

A [`CodeDiff`](@ref) between `code₁` and `code₂`, relying on the native display of Julia AST.

If `prettify == true`, then
[`MacroTools.prettify(code; lines, alias)`](https://fluxml.ai/MacroTools.jl/stable/utilities/#MacroTools.prettify)
is used to cleanup the AST. `lines == true` will keep the `LineNumberNode`s and `alias == true`
will replace mangled names (or `gensym`s) by dummy names.

`color == true` is special, as it places the stringified AST into a Markdown code block.
See [`compare_ast(code₁::Markdown.MD, code₂::Markdown.MD)`](@ref).
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


"""
    code_diff(code₁::Markdown.MD, code₂::Markdown.MD; kwargs...)
    code_diff(code₁::Expr, code₂::Expr; kwargs...)
    code_diff(::Val{:ast}, code₁::AbstractString, code₂::AbstractString; kwargs...)

Compare AST in `code₁` and `code₂`. `Expr` and `String` are placed in `Markdown` code blocks.
"""
code_diff(code₁::Markdown.MD, code₂::Markdown.MD; kwargs...) = compare_ast(code₁, code₂; kwargs...)
code_diff(code₁::Expr, code₂::Expr; kwargs...) = compare_ast(code₁, code₂; kwargs...)
code_diff(::Val{:ast}, code₁::AbstractString, code₂::AbstractString; kwargs...) =
    compare_ast(code₁, code₂; kwargs...)

code_diff(::Val{:native}, code₁::AbstractString, code₂::AbstractString; kwargs...) =
    compare_code(code₁, code₂, InteractiveUtils.print_native; kwargs...)
code_diff(::Val{:llvm},   code₁::AbstractString, code₂::AbstractString; kwargs...) =
    compare_code(code₁, code₂, InteractiveUtils.print_llvm; kwargs...)
code_diff(::Val{:typed},  code₁::AbstractString, code₂::AbstractString; kwargs...) =
    compare_code(code₁, code₂, identity; kwargs...)

"""
    code_diff(::Val{type}, f₁, types₁, f₂, types₂; kwargs...)
    code_diff(::Val{type}, code₁::AbstractString, code₂::AbstractString; kwargs...)
    code_diff(args...; type=:native, kwargs...)

Dispatch to [`compare_code_native`](@ref), [`compare_code_llvm`](@ref),
[`compare_code_typed`](@ref) or [`compare_ast`](@ref) depending on `type`.
"""
code_diff(code₁::AbstractString, code₂::AbstractString; type::Symbol=:native, kwargs...) =
    code_diff(Val(type), code₁, code₂; kwargs...)

@nospecialize

code_diff(::Val{:native}, f₁, types₁, f₂, types₂; kwargs...) = compare_code_native(f₁, types₁, f₂, types₂; kwargs...)
code_diff(::Val{:llvm},   f₁, types₁, f₂, types₂; kwargs...) = compare_code_llvm(f₁, types₁, f₂, types₂; kwargs...)
code_diff(::Val{:typed},  f₁, types₁, f₂, types₂; kwargs...) = compare_code_typed(f₁, types₁, f₂, types₂; kwargs...)

code_diff(code₁::Tuple, code₂::Tuple; type::Symbol=:native, kwargs...) =
    code_diff(Val(type), code₁..., code₂...; kwargs...)

@specialize


"""
    @code_diff [type=:native] [option=value...] f₁(...) f₂(...)
    @code_diff [type] [option=value...] a b

Compare the methods called by the `f₁(...)` and `f₂(...)` expressions, and return a
[`CodeDiff`](@ref).
In the other form of `@code_diff`, `a` and `b` must be either variable names (`Symbol`s)
or quoted expressions (e.g. `@code_diff :(1+2) :(2+3)`): in this case the difference type
might be inferred automatically.

`option`s are passed as key-word arguments to [`code_diff`](@ref) and then to the
`compare_code_*` function for the given code `type`.
"""
macro code_diff(args...)
    length(args) < 2 && throw(ArgumentError("@code_diff takes at least 2 arguments"))
    options = args[1:end-2]
    code₁, code₂ = args[end-1:end]

    options = map(options) do option
        !(option isa Expr && option.head === :(=)) &&
            throw(ArgumentError("options must be in the form `key=value`, got: $option"))
        return Expr(:kw, option.args[1], option.args[2])
    end

    code₁, code₂ = map((code₁, code₂)) do code
        (!(code isa Expr) || code.head === :quote) && return code
        code.head !== :call && throw(ArgumentError("expected call expression, got: $code"))
        # `f(a, b)` => `(f, Base.typesof(a, b))`
        f = code.args[1]
        f_args = :(Base.typesof($(code.args[2:end]...)))
        return :($f, $f_args)
    end

    call_expr = :($code_diff($code₁, $code₂; ))
    append!(call_expr.args[2].args, options)
    return esc(call_expr)
end
