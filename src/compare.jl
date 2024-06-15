
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
    code_for_diff(f, types::Type{<:Tuple}; type=:native, color=true, cleanup=true, kwargs...)
    code_for_diff(expr::Expr; type=:ast, color=true, kwargs...)

Fetches the code of `f` with [`get_code(Val(type), f, types; kwargs...)`](@ref), cleans it
up with [`cleanup_code(Val(type), code)`](@ref) and highlights it using the appropriate
[`code_highlighter(Val(type))`](@ref).
The result is two `String`s: one without and the other with highlighting.
"""
function code_for_diff(f, types::Type{<:Tuple}; type=:native, color=true, io=nothing, cleanup=true, kwargs...)
    @nospecialize(f, types)
    code = get_code(Val(type), f, types; kwargs...)
    return code_for_diff(code, Val(type), color, cleanup)
end

function code_for_diff(expr::Union{Expr, QuoteNode}; type=:ast, color=true, io=nothing, cleanup=true, kwargs...)
    if type !== :ast
        throw(ArgumentError("wrong type for `$(typeof(expr))`: `$type`, expected `:ast`"))
    end
    code = code_ast(expr; kwargs...)
    return code_for_diff(code, Val(type), color, cleanup)
end

function code_for_diff(code, type::Val, color, cleanup)
    code = cleanup ? cleanup_code(type, code) : code

    code_str = sprint(code_highlighter(type), code; context=(:color => false,))
    code_str = replace(code_str, ANSI_REGEX => "")  # Make sure there is no decorations

    if color
        code_highlighted = sprint(code_highlighter(type), code; context=(:color => true,))
    else
        code_highlighted = code_str
    end

    return code_str, code_highlighted
end


argconvert(@nospecialize(code_type), arg) = arg
extract_extra_options(@nospecialize(f), _) = (;)
separate_kwargs(code_type::Val, args...; kwargs...) = (argconvert.(Ref(code_type), args), values(kwargs))
is_error_expr(expr) = Base.isexpr(expr, :call) && expr.args[1] in (:error, :throw)
is_call_expr(expr) = Base.isexpr(expr, :call) || (Base.isexpr(expr, :(.), 2) && Base.isexpr(expr.args[2], :tuple))


function gen_code_for_diff_call(mod, expr, diff_options)
    # `diff_options` must be already `esc`aped, but not `expr`

    if !is_call_expr(expr)
        error_str = "Expected call (or dot call) to function, got: $expr"
        return :(throw(ArgumentError($error_str)))
    end

    is_dot_call = Base.isexpr(expr, :(.))

    f_sym, args_sym, kwargs_sym, code_type_sym = gensym(:f), gensym(:args), gensym(:kwargs), gensym(:code_type)
    f_esc, args_esc, kwargs_esc, code_type_esc = esc(f_sym), esc(args_sym), esc(kwargs_sym), esc(code_type_sym)
    diff_opts_esc, extra_diff_opts_esc = esc(gensym(:diff_opts)), esc(gensym(:extra_opts))

    # `f`'s arguments will be replaced by splats from `separate_kwargs` which would have
    # properly `argconvert` all arguments.
    f_expr = expr.args[1]
    expr.args[1] = f_sym

    # We can't `Core.kwcall` a function no defined with a kwargs, therefore for simplicity
    # we duplicate everything to handle the cases with and without kwargs at runtime.
    expr_no_kw = copy(expr)
    expr_wh_kw = copy(expr)

    call_args       = is_dot_call ?       expr.args[2].args : expr.args[2:end]
    call_args_no_kw = is_dot_call ? expr_no_kw.args[2].args : @view(expr_no_kw.args[2:end])
    call_args_wh_kw = is_dot_call ? expr_wh_kw.args[2].args : @view(expr_wh_kw.args[2:end])
    keepat!(parent(call_args_no_kw), is_dot_call ? () : (1,))  # remove all arguments of the call expression
    keepat!(parent(call_args_wh_kw), is_dot_call ? () : (1,))
    push!(parent(call_args_no_kw), :($args_sym...))
    push!(parent(call_args_wh_kw), Expr(:parameters, :($kwargs_sym...)), :($args_sym...))

    # Add the `code_type` argument for `separate_kwargs`
    first_arg_pos = !isempty(call_args) && Base.isexpr(call_args[1], :parameters) ? 2 : 1
    insert!(call_args, first_arg_pos, :(Val($code_type_sym)))

    # `code_for_diff`'s name must start with `code` in order to replicate the behavior of
    # the other `@code_*` macros.
    code_for_diff_no_kw = InteractiveUtils.gen_call_with_extracted_types(mod, :code_for_diff, expr_no_kw)
    code_for_diff_wh_kw = InteractiveUtils.gen_call_with_extracted_types(mod, :code_for_diff, expr_wh_kw)
    is_error_expr(code_for_diff_no_kw) && return code_for_diff_no_kw
    is_error_expr(code_for_diff_wh_kw) && return code_for_diff_wh_kw

    # Get the call to `code_for_diff` and add our kwargs to it.
    # `gen_call_with_extracted_types` adds kwargs inconsistently so we do it ourselves.
    diff_args_no_kw = Base.isexpr(code_for_diff_no_kw, :call) ? code_for_diff_no_kw.args : code_for_diff_no_kw.args[end].args
    diff_args_wh_kw = Base.isexpr(code_for_diff_wh_kw, :call) ? code_for_diff_wh_kw.args : code_for_diff_wh_kw.args[end].args
    !Base.isexpr(diff_args_no_kw[2], :parameters) && insert!(diff_args_no_kw, 2, Expr(:parameters))
    !Base.isexpr(diff_args_wh_kw[2], :parameters) && insert!(diff_args_wh_kw, 2, Expr(:parameters))
    push!(diff_args_no_kw[2].args, Expr(:..., diff_opts_esc), Expr(:..., extra_diff_opts_esc))
    push!(diff_args_wh_kw[2].args, Expr(:..., diff_opts_esc), Expr(:..., extra_diff_opts_esc))

    diff_kwargs = Expr(:tuple, Expr(:parameters, diff_options...))  # `(; diff_options...)`
    call_args .= esc.(call_args)

    return MacroTools.flatten(quote
        local $diff_opts_esc = $diff_kwargs
        local $f_esc = $(esc(f_expr))
        local $code_type_esc = get($diff_opts_esc, :type, :native)
        local $args_esc, $kwargs_esc = $separate_kwargs($(call_args...))
        local $extra_diff_opts_esc = $extract_extra_options($f_esc, $kwargs_esc)

        if isempty($kwargs_esc)
            $code_for_diff_no_kw
        else
            $code_for_diff_wh_kw
        end
    end)
end


function code_diff_for_expr(code_expr, options, mod)
    if is_call_expr(code_expr)
        # Generic call comparison
        return gen_code_for_diff_call(mod, code_expr, options)
    else
        if Base.isexpr(code_expr, :quote)
            # AST comparison
            type_guess = (Expr(:kw, :type, QuoteNode(:ast)),)
        else
            # Mystery comparison
            type_guess = ()
        end
        return :($code_for_diff($(esc(code_expr)); $(type_guess...), $(options...)))
    end
end


"""
    @code_diff [type=:native] [color=true] [cleanup=true] [option=value...] f₁(...) f₂(...)
    @code_diff [option=value...] :(expr₁) :(expr₂)

Compare the methods called by the `f₁(...)` and `f₂(...)` or the expressions `expr₁` and
`expr₂`, then return a [`CodeDiff`](@ref).

`option`s are passed to [`get_code`](@ref). Option names ending with `_1` or `_2` are passed
to the call of `get_code` for `f₁` and `f₂` respectively. They can also be packed into
`extra_1` and `extra_2`.

To compare `Expr` in variables, use `@code_diff :(\$a) :(\$b)`.

`cleanup == true` will use [`cleanup_code`](@ref) to make the codes more prone to comparisons
(e.g. by renaming variables with names which change every time).

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
    options = collect(args[1:end-2])
    code₁, code₂ = args[end-1:end]

    # 2 ways to pass kwargs to a specific side: `extra_1=(; kwargs...)` or `<opt>_1=val`/`<opt>_2=val`
    # otherwise it is an option common to both sides.
    options₁ = Expr[]
    options₂ = Expr[]
    for option in options
        if option isa Symbol
            # Shortcut allowing to write `opt` instead of `opt=opt`
            option = Expr(:(=), option, option)
        elseif !(Base.isexpr(option, :(=), 2) && option.args[1] isa Symbol)
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

    code_for_diff₁ = code_diff_for_expr(code₁, options₁, __module__)
    code_for_diff₂ = code_diff_for_expr(code₂, options₂, __module__)
    is_error_expr(code_for_diff₁) && return code_for_diff₁
    is_error_expr(code_for_diff₂) && return code_for_diff₂

    return quote
        let
            local code₁, hl_code₁ = $code_for_diff₁
            local code₂, hl_code₂ = $code_for_diff₂
            code_diff(code₁, code₂, hl_code₁, hl_code₂)
        end
    end
end


"""
    @code_for [type=:native] [color=true] [io=stdout] [cleanup=true] [option=value...] f(...)
    @code_for [option=value...] :(expr)

Display the code of `f(...)` to `io` for the given code `type`, or the expression `expr`
(AST only).

`option`s are passed to [`get_code`](@ref).
To display an `Expr` in a variable, use `@code_for :(\$expr)`.

`io` defaults to `stdout`. If `io == String`, then the code is not printed and is simply
returned.

If the `type` option is the first option, `"type"` can be omitted: i.e. `@code_for :llvm f()`
is valid.

`cleanup == true` will use [`cleanup_code`](@ref) on the code.

```julia
# Default comparison
@code_for type=:native f()

# Without debuginfo
@code_for type=:llvm debuginfo=:none f()

# Options sets can be passed from variables with the `extra` options
opts = (; debuginfo=:none, world=Base.get_world_counter())
@code_for type=:typed extra=opts f()

# Same as above, but shorter since we can omit "type"
@code_for :typed extra=opts f()
```
"""
macro code_for(args...)
    isempty(args) && return :(throw(ArgumentError("@code_for takes at least 1 argument")))
    raw_options = collect(args[1:end-1])
    code = args[end]

    options = Expr[]
    for (i, option) in enumerate(raw_options)
        if option isa Symbol
            # Shortcut allowing to write `opt` instead of `opt=opt`
            option = Expr(:(=), option, option)
        elseif option isa QuoteNode && option.value isa Symbol && i == 1
            # Allow the first option to be the `type`, to write `@code_for :native f()`
            option = Expr(:(=), :type, option)
        elseif !(Base.isexpr(option, :(=), 2) && option.args[1] isa Symbol)
            opt_error = "options must be in the form `key=value`, got: `$option`"
            return :(throw(ArgumentError($opt_error)))
        end

        opt_name = option.args[1]::Symbol
        if opt_name === :extra
            opt_splat = Expr(:..., esc(option.args[2]))
            push!(options, opt_splat)
        else
            kw_option = Expr(:kw, opt_name, esc(option.args[2]))
            push!(options, kw_option)
        end
    end

    # Simple values such as `:(1)` are stored in a `QuoteNode`
    code isa QuoteNode && (code = Expr(:quote, Expr(:block, code.value)))

    # Place the diff options in a temp variable in order to extract `io` at runtime
    diff_options = esc(gensym(:diff_options))
    code_for = code_diff_for_expr(code, [:($diff_options...)], __module__)
    is_error_expr(code_for) && return code_for

    return quote
        let
            local $diff_options = (; $(options...))
            local io = get($diff_options, :io, stdout)
            local _, hl_code = $code_for
            if io === $String
                chomp(hl_code)
            else
                printstyled(io, chomp(hl_code), '\n')
            end
        end
    end
end
