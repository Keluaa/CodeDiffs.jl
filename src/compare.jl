
function should_strip_last_newline(str)
    # Strip the last newline only if there is more than one
    f_pos = findfirst('\n', str)
    isnothing(f_pos) && return false
    nl_end = endswith(str, '\n')
    return nl_end && f_pos < length(str)
end


function code_diff(code₁::String, code₂::String, code₁_colored::String, code₂_colored::String)
    if should_strip_last_newline(code₁) && should_strip_last_newline(code₂)
        code₁ = rstrip(==('\n'), code₁)
        code₂ = rstrip(==('\n'), code₂)
        code₁_colored = rstrip(==('\n'), code₁_colored)
        code₂_colored = rstrip(==('\n'), code₂_colored)
    else
        # Hack to make sure `deepdiff` creates a `StringLineDiff`
        if !occursin('\n', code₁)
            code₁ *= '\n'
            code₁_colored *= '\n'
        end

        if !occursin('\n', code₂)
            code₂ *= '\n'
            code₂_colored *= '\n'
        end
    end

    diff = CodeDiff(code₁, code₂, code₁_colored, code₂_colored)

    optimize_line_changes!(diff)
    return diff
end


"""
    code_diff(args₁::Tuple, args₂::Tuple; extra_1=(;), extra_2=(;), kwargs...)

Function equivalent to [`@code_diff`](@ref)`(extra_1, extra_2, kwargs..., args₁, args₂)`.
`kwargs` are common to both sides, while `extra_1` and `extra_2` are passed to
[`code_for_diff`](@ref) only with `args₁` and `args₂` respectively.

```jldoctest; setup=(f() = 1; g() = 2)
julia> diff_1 = @code_diff debuginfo_1=:none f() g();

julia> diff_2 = code_diff((f, Tuple{}), (g, Tuple{}); extra_1=(; debuginfo=:none));

julia> diff_1 == diff_2
true
```
"""
function code_diff(args₁::Tuple, args₂::Tuple; extra_1=(;), extra_2=(;), kwargs...)
    code₁, hl_code₁ = code_for_diff(args₁...; kwargs..., extra_1...)
    code₂, hl_code₂ = code_for_diff(args₂...; kwargs..., extra_2...)
    return code_diff(code₁, code₂, hl_code₁, hl_code₂)
end


"""
    code_for_diff(f::Base.Callable, types::Type{<:Tuple}; type=:native, color=true, kwargs...)
    code_for_diff(expr::Expr; type=:ast, color=true, kwargs...)

Fetches the code of `f` with [`get_code(Val(type), f, types; kwargs...)`](@ref), cleans it
up with [`cleanup_code(Val(type), code)`](@ref) and highlights it using the appropriate
[`code_highlighter(Val(type))`](@ref).
The result is two `String`s: one without and the other with highlighting.
"""
function code_for_diff(f::Base.Callable, types::Type{<:Tuple}; type=:native, color=true, kwargs...)
    @nospecialize(f, types)
    code = get_code(Val(type), f, types; kwargs...)
    return code_for_diff(code, Val(type), color)
end

function code_for_diff(expr::Union{Expr, QuoteNode}; type=:ast, color=true, kwargs...)
    if type !== :ast
        throw(ArgumentError("wrong type for `$(typeof(expr))`: `$type`, expected `:ast`"))
    end
    code = code_ast(expr; kwargs...)
    return code_for_diff(code, Val(type), color)
end

function code_for_diff(code, type::Val, color)
    code = cleanup_code(type, code)

    code_str = sprint(code_highlighter(type), code; context=(:color => false,))
    code_str = replace(code_str, ANSI_REGEX => "")  # Make sure there is no decorations

    if color
        code_highlighted = sprint(code_highlighter(type), code; context=(:color => true,))
    else
        code_highlighted = code_str
    end

    return code_str, code_highlighted
end


"""
    @code_diff [type=:native] [color=true] [option=value...] f₁(...) f₂(...)
    @code_diff [option=value...] :(expr₁) :(expr₂)

Compare the methods called by the `f₁(...)` and `f₂(...)` or the expressions `expr₁` and
`expr₂`, then return a [`CodeDiff`](@ref).

`option`s are passed to [`get_code`](@ref). Option names ending with `_1` or `_2` are passed
to the call of `get_code` for `f₁` and `f₂` respectively. They can also be packed into
`extra_1` and `extra_2`.

To compare `Expr` in variables, use `@code_diff :(\$a) :(\$b)`.

```julia
# Default comparison
@code_diff type=:native f() g()

# No debuginfo for `f()` and `g()`
@code_diff type=:native debuginfo=:none f() g()

# No debuginfo for `f()`
@code_diff type=:native debuginfo_1=:none f() g()

# No debuginfo for `g()`
@code_diff type=:native debuginfo_2=:none f() g()

# Options can be passed from variables with `extra_1` and `extra_2`
opts = (; debuginfo=:none, world=Base.get_world_counter())
@code_diff type=:native extra_1=opts extra_2=opts f() g()

# `type` and `color` can also be made different in each side
@code_diff type_1=:native type_2=:llvm f() f()
```
"""
macro code_diff(args...)
    length(args) < 2 && return :(throw(ArgumentError("@code_diff takes at least 2 arguments")))
    options = args[1:end-2]
    code₁, code₂ = args[end-1:end]

    # 2 ways to pass kwargs to a specific side: `extra_1=(; kwargs...)` or `<opt>_1=val`/`<opt>_2=val`
    # otherwise it is an option common to both sides.
    options₁ = Expr[]
    options₂ = Expr[]
    for option in options
        if !(Base.isexpr(option, :(=), 2) && option.args[1] isa Symbol)
            opt_error = "options must be in the form `key=value`, got: `$option`"
            return :(throw(ArgumentError($opt_error)))
        end

        opt_name = option.args[1]::Symbol
        if opt_name in (:extra_1, :extra_2)
            opt_splat = Expr(:..., esc(option.args[2]))
            if opt_name === :extra_1
                push!(options₁, opt_splat)
            else
                push!(options₂, opt_splat)
            end
        else
            opt_name_str = String(opt_name)
            has_suffix = endswith(opt_name_str, r"_[12]")
            opt_name = has_suffix ? Symbol(opt_name_str[1:end-2]) : opt_name
            kw_option = Expr(:kw, opt_name, esc(option.args[2]))
            if endswith(opt_name_str, "_1")
                push!(options₁, kw_option)
            elseif endswith(opt_name_str, "_2")
                push!(options₂, kw_option)
            else
                push!(options₁, kw_option)
                push!(options₂, kw_option)
            end
        end
    end

    # Simple values such as `:(1)` are stored in a `QuoteNode`
    code₁ isa QuoteNode && (code₁ = Expr(:quote, Expr(:block, code₁.value)))
    code₂ isa QuoteNode && (code₂ = Expr(:quote, Expr(:block, code₂.value)))

    if Base.isexpr(code₁, :quote) && Base.isexpr(code₂, :quote)
        code₁ = esc(code₁)
        code₂ = esc(code₂)
        code_for_diff₁ = :($code_for_diff($code₁; type=:ast, $(options₁...)))
        code_for_diff₂ = :($code_for_diff($code₂; type=:ast, $(options₂...)))
    else
        # `code_for_diff`'s name must start with `code` in order to replicate the behavior
        # of the other `@code_*` macros.
        code_for_diff₁ = InteractiveUtils.gen_call_with_extracted_types(__module__, :code_for_diff, code₁)
        code_for_diff₂ = InteractiveUtils.gen_call_with_extracted_types(__module__, :code_for_diff, code₂)

        if Base.isexpr(code_for_diff₁, :call) && code_for_diff₁.args[1] === :error
            return code_for_diff₁
        elseif Base.isexpr(code_for_diff₂, :call) && code_for_diff₂.args[1] === :error
            return code_for_diff₂
        end

        # `gen_call_with_extracted_types` adds kwargs inconsistently so we do it ourselves
        args₁ = Base.isexpr(code_for_diff₁, :call) ? code_for_diff₁.args : code_for_diff₁.args[end].args
        args₂ = Base.isexpr(code_for_diff₂, :call) ? code_for_diff₂.args : code_for_diff₂.args[end].args
        !Base.isexpr(args₁[2], :parameters) && insert!(args₁, 2, Expr(:parameters))
        !Base.isexpr(args₂[2], :parameters) && insert!(args₂, 2, Expr(:parameters))
        append!(args₁[2].args, options₁)
        append!(args₂[2].args, options₂)
    end

    return quote
        let
            local code₁, hl_code₁ = $code_for_diff₁
            local code₂, hl_code₂ = $code_for_diff₂
            code_diff(code₁, code₂, hl_code₁, hl_code₂)
        end
    end
end
