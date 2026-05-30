
struct OneLinerExpr
    expr :: Expr
end


function Base.show_unquoted(io::IO, ex::OneLinerExpr, indent::Int, prec::Int, quote_level::Int)
    head = ex.expr.head
    if head === :struct
        head = ex.expr.args[1] ? Symbol("mutable struct") : Symbol("struct")
        print(io, head, ' ')
        Base.show_list(io, Any[ex.expr.args[2]], ", ", indent, 0, quote_level)
        print(io, " end")
    end
end


mutable struct MaybeMultiline
    expr          :: Expr
    line_length   :: Int
    indent_offset :: Int
end

MaybeMultiline(expr::Expr, line_length::Int; indent_offset=0) =
    MaybeMultiline(expr, line_length, indent_offset)

# Trickery to make `MaybeMultiline` behave as an `Expr`
Base.propertynames(::MaybeMultiline, private=false) = (:expr, :line_length, :indent_offset, :head, :args)

function Base.getproperty(ex::MaybeMultiline, name::Symbol)
    if     name === :head  return ex.expr.head
    elseif name === :args  return ex.expr.args
    else
        return Base.getfield(ex, name)
    end
end

# Method ambiguities are annoying to deal with...
Base.is_expr(ex::MaybeMultiline, heads::Symbol)                        = Base.is_expr(ex.expr, heads)
Base.is_expr(ex::MaybeMultiline, heads::Symbol, n::Int)                = Base.is_expr(ex.expr, heads, n)
Base.is_expr(ex::MaybeMultiline, heads::Tuple{Vararg{Symbol}})         = Base.is_expr(ex.expr, heads)
Base.is_expr(ex::MaybeMultiline, heads::Tuple{Vararg{Symbol}}, n::Int) = Base.is_expr(ex.expr, heads, n)
Base.is_expr(ex::MaybeMultiline, heads::Vector{Symbol})                = Base.is_expr(ex.expr, heads)
Base.is_expr(ex::MaybeMultiline, heads::Vector{Symbol}, n::Int)        = Base.is_expr(ex.expr, heads, n)


"""
    show_multiline_list(
        io::IO, items, sep, indent::Int, max_line_length::Int, initial_line_pos::Int; 
        prec::Int=0, quote_level::Int=0, enclose_operators::Bool=false, kw::Bool=false,
        kws_from=nothing, add_space_before_first_item=false,
    )

Similar to `Base.show_list`, but will add newlines between items when needed.
If all items fit within `max_line_length`, no newline are added. Otherwise, a newline is added
before the first item, and before any item which would exceed `max_line_length` when printed.

Assumes there are `initial_line_pos` characters already printed in the first line.

If `kws_from !== nothing`, then `';'` will be printed instead of `sep` after the `kws_from`-th item.
Subsequent items will be printed with `kw == true`.

If `add_space_before_first_item == true`, then a space will be printed before the first item,
only if we do not print a newline first.
"""
function show_multiline_list(
    io::IO, items, sep, indent::Int, max_line_length::Int, initial_line_pos::Int; 
    prec::Int=0, quote_level::Int=0, enclose_operators::Bool=false, kw::Bool=false,
    kws_from=nothing, add_space_before_first_item=false,
)
    n = length(items)
    n == 0 && return false, initial_line_pos

    io_item_buf = IOBuffer()
    io_item_ctx = IOContext(io_item_buf, io)

    io_line_buf = IOBuffer()
    io_line_ctx = IOContext(io_line_buf, io)

    is_multiline = false
    line_pos = initial_line_pos
    line_indent = indent + Base.indent_width

    function print_newline()
        print(io, '\n', " "^line_indent)
        is_multiline = true
        line_pos = line_indent
    end

    function print_line(; more_content_after=true, force=false)
        if more_content_after && !is_multiline
            # Make the first line start on its own line
            line_chars = line_pos - initial_line_pos
            print_newline()
            line_pos += line_chars
            !force && return false
        end
        if add_space_before_first_item 
            add_space_before_first_item = false
            !is_multiline && print(io, ' ')
        end
        print(io, String(take!(io_line_buf)))
        more_content_after && print_newline()
        return true
    end

    function print_item()
        str = String(take!(io_item_buf))
        len = length(str)
        if line_pos + len + add_space_before_first_item > max_line_length
            if position(io_line_buf) > 0 && !print_line()
                if line_pos + len + add_space_before_first_item > max_line_length
                    # We really need a fresh line to write this item
                    print_line()
                else
                    print(io_line_ctx, ' ')
                    line_pos += 1
                end
            end
            print(io_line_ctx, str)
        else
            if position(io_line_buf) > 0
                print(io_line_ctx, ' ')
                line_pos += 1
            end
            print(io_line_ctx, str)
        end
        line_pos += len
    end

    if kws_from == 0
        print(io, ';')
        line_pos += 1
        add_space_before_first_item = true
        kw = true
    end

    for (i, item) in enumerate(items)
        # TODO: handle items which print on multiple lines
        Base.show_list(io_item_ctx, Any[item], sep, indent, prec, quote_level, enclose_operators, kw)
        i < n && print(io_item_ctx, i == kws_from ? ';' : sep)
        print_item()

        if i == kws_from
            # The rest of the items are kwargs, we want to print them on a new line
            print_line(; force=!is_multiline)
            kw = true
        end
    end

    if position(io_line_buf) > 0
        print_line(; more_content_after=false)
    end

    return is_multiline, line_pos
end


function show_call_head(io::IO, head, func, indent, quote_level)
    # Unfortunate but necessary: this is a copy of the logic to print the call head from `Base.show_call`
    if (isa(func, Symbol) && func !== :(:) && !(head === :. && Base.isoperator(func))) ||
            (isa(func, Symbol) && !Base.is_valid_identifier(func)) ||
            (isa(func, Expr) && (func.head === :. || func.head === :curly || func.head === :macroname)) ||
            isa(func, GlobalRef)
        Base.show_unquoted(io, func, indent, 0, quote_level)
    else
        print(io, '(')
        Base.show_unquoted(io, func, indent, 0, quote_level)
        print(io, ')')
    end
    if head === :(.)
        print(io, '.')
    end
end


last_newline_offset(::IO) = nothing
last_newline_offset(io::IOContext) = last_newline_offset(only(Base.unwrapcontext(io)))
function last_newline_offset(io::Base.GenericIOBuffer)
    (!io.seekable || !io.readable) && return nothing
    readable_data_span = Base.get_used_span(io)
    for pos in reverse(readable_data_span)
        io.data[pos] == 0x0A && return last(readable_data_span) - pos
    end
    return nothing
end


function Base.show_unquoted(io::IO, ex::MaybeMultiline, indent::Int, prec::Int, quote_level::Int)
    raw_io = only(Base.unwrapcontext(io))
    if !applicable(position, raw_io)
        # This should only happen when trying to print a `MaybeMultiline` object nested in another to stdout
        return Base.show_unquoted(io, ex.expr, indent, prec, quote_level)
    end

    # Get the number of bytes after the last newline. Assuming there are no multiline characters,
    # it is the number of characters in the current line.
    line_offset = @something last_newline_offset(raw_io) 0
    current_pos = position(raw_io)

    indent += ex.indent_offset

    head = ex.expr.head
    if head === :(=)
        # If the function definition is too long, add a newline after the `=`
        # `f(a, b) = c`  ->  `f(a, b) =\n c`
        call, body = ex.expr.args
        Base.show_unquoted(io, call, indent, prec, quote_level)
        print(io, " =")
        line_length = position(raw_io) - current_pos

        io_buf = IOBuffer()
        io_ctx = IOContext(io_buf, io)
        Base.show_unquoted(io_ctx, body, indent, prec, quote_level)
        str = String(take!(io_buf))

        if line_offset + line_length + length(str) ≥ ex.line_length
            print(io, '\n', " "^(indent + Base.indent_width))
        else
            print(io, ' ')
        end
        print(io, str)

    elseif head in keys(Base.expr_parens)
        # Tuple, vect, etc...
        items = ex.expr.args
        
        op, cl = Base.expr_parens[head]
        print(io, op)
        line_offset += 1
        add_space_before_first_item = false

        if head === :tuple && Base.is_expr(items[1], :parameters)
            # NamedTuple
            items = items[1].args
            print(io, ';')
            line_offset += 1
            add_space_before_first_item = true
        end

        has_newlines, line_pos = show_multiline_list(
            io, items, ',', indent, ex.line_length, line_offset;
            kw=true, quote_level, add_space_before_first_item
        )
        has_newlines && print(io, '\n', " "^indent)
        print(io, cl)

    elseif head === :call
        # Function call or definition
        func_head = ex.expr.args[1]
        func_args = @view(ex.expr.args[2:end])

        if !isempty(func_args) && Base.is_expr(func_args[1], :parameters)
            func_kws  = func_args[1].args
            func_args = @view func_args[2:end]
        else
            func_kws = Expr[]
        end

        line_start = position(raw_io)
        show_call_head(io, head, func_head, indent, quote_level)
        print(io, '(')
        line_pos = position(raw_io) - line_start  # this is inexact if there are multi-byte chars
        line_pos += line_offset

        # Positional arguments and kwargs are merged to the same list in order to improve the result
        args = Any[]
        append!(args, func_args)
        if !isempty(func_kws)
            kws_from = length(args)
            append!(args, func_kws)
        else
            kws_from = nothing
        end

        has_newlines, line_pos = show_multiline_list(io, args, ',', indent, ex.line_length, line_pos; kws_from, quote_level, kw=true)
        has_newlines && print(io, '\n', " "^indent)
        print(io, ')')

    elseif head === :__where_params
        # The type parameters of a `where` clause
        # Since `replace_expr_for_printing` filters out cases with one parameter, we always need to
        # print the curly braces.
        print(io, '{')
        line_offset += 1
        has_newlines, line_pos = show_multiline_list(io, ex.expr.args, ',', indent, ex.line_length, line_offset; quote_level)
        has_newlines && print(io, '\n', " "^indent)
        print(io, '}')

    elseif head === :curly
        line_start = position(raw_io)
        Base.show_unquoted(io, ex.expr.args[1], indent, prec, quote_level)
        print(io, '{')
        line_pos = position(raw_io) - line_start  # this is inexact if there are multi-byte chars
        line_pos += line_offset

        has_newlines, line_pos = show_multiline_list(io, @view(ex.expr.args[2:end]), ',', indent, ex.line_length, line_pos; quote_level)
        has_newlines && print(io, '\n', " "^indent)
        print(io, '}')

    else
        error("unexpected expression head: ", head)
    end
end


function replace_expr_for_printing(expr::Expr, max_line_length)
    expr = MacroTools.postwalk(expr) do e
        if Base.is_expr(e, :function, 2)
            # Multiline function definition
            func_call = e.args[1]
            if Base.is_expr(func_call, :where)
                func_call = func_call.args[1]
            end
            if func_call isa MaybeMultiline
                # We want to indent function arguments at the same level as the function body
                func_call.indent_offset = -Base.indent_width
            end
            return e
        end

        if Base.is_expr(e, :where) && length(e.args) > 2
            # `some_type_or_function where {bla, bla, bla}`
            # We consider only cases with more than one parameter (therefore printed with curly braces).
            # We modify the AST to place all parameters in our custom `__where_params` expression,
            # keeping most of the printing logic for `:where` unchanged.
            where_params = e.args[2:end]
            multi_where = MaybeMultiline(Expr(:__where_params, where_params...), max_line_length)
            # Indent type parameters at the same level as the function body
            multi_where.indent_offset = -Base.indent_width
            e.args = [e.args[1], multi_where]
            return e
        end

        if Base.is_expr(e, :call) && length(e.args) > 1 && !Base.isoperator(e.args[1])
            # Function call with arguments, but not for an arithmetic operation
            return MaybeMultiline(e, max_line_length)
        end

        if Base.is_expr(e, :(=), 2) && (Base.is_expr(e.args[1], [:where, :call]))
            # Single line function definition
            return MaybeMultiline(e, max_line_length)
        end

        # Tuple or NamedTuple
        Base.is_expr(e, :tuple) && length(e.args) > 0 && return MaybeMultiline(e, max_line_length)
        # Vector
        Base.is_expr(e, :vect) && length(e.args) > 0 && return MaybeMultiline(e, max_line_length)
        # `T{A, B <: C}`
        Base.is_expr(e, :curly) && length(e.args) > 0 && return MaybeMultiline(e, max_line_length)
        # Struct with no fields
        MacroTools.@capture(e, struct S_ end | mutable struct S_ end) && return OneLinerExpr(e)
        return e
    end
    return expr isa Expr ? expr : Expr(:block, expr)
end


function cleanup_code(::Val{:ast}, expr::Expr, dbinfo, cleanup_opts)
    max_line_length = get(cleanup_opts, :line_length, 120)
    if get(cleanup_opts, :ast_pretty_print, true)
        # Some transformations can only be safely done in the AST, as otherwise we would need to parse
        # the AST string representation, which we would like to avoid.
        expr = replace_expr_for_printing(expr, max_line_length)
    end
    # Important: use `print` and not `Base.show`, as `print` will default to pretty printing of quotes
    expr_str = sprint(print, expr)
    return cleanup_code(Val(:ast), expr_str, dbinfo, cleanup_opts)
end


function count_indents(s::AbstractString, indent)
    leading_spaces = 0
    for c in s
        c != ' ' && break
        leading_spaces += 1
    end
    return fld(leading_spaces, indent)
end


function remove_unnecessary_indents(str::AbstractString, indent_width)
    buf = IOBuffer(; sizehint=ncodeunits(str))

    # Parse through each line and count the indent.
    # If it increases by more than one `indent_width` from one line to another, remove the extra
    # indent until we go back to the previous indent.
    first_line = true
    prev_indent = 0
    extra_indent = 0
    extra_indent_stack = Tuple{Int, Int}[]
    for line in eachsplit(str, r"\R")
        indent = count_indents(line, indent_width)
        if indent > prev_indent + 1
            line_extra_indent = indent - prev_indent - 1
            extra_indent += line_extra_indent
            push!(extra_indent_stack, (prev_indent, line_extra_indent))
        else
            while !isempty(extra_indent_stack) && last(extra_indent_stack)[1] ≥ indent
                _, line_extra_indent = pop!(extra_indent_stack)
                extra_indent -= line_extra_indent
            end
        end

        !first_line && println(buf)
        first_line = false
        # print(buf, "-"^(indent_width * extra_indent))  # for debugging: this prints spaces which would be removed
        print(buf, @view line[extra_indent*indent_width+1:end])

        prev_indent = indent
    end

    return String(take!(buf))
end


function small_if_to_ternary(str::AbstractString, max_length)
    # Matches a multiline `if` statement (any indent level), but only if each block fits in a single line.
    # At the end of the `if`, we either match a newline (`if_end`) or the beginning of the next expression.
    if_regex = r"\bif (?<cond>.+)\R *(?<yes>.+)\R *else\R *(?<no>.+)\R *end((?<if_end>\R|$)|(?<if_inline>\b))"

    buf = IOBuffer(; sizehint=ncodeunits(str))

    prev_pos = 1
    for if_match in eachmatch(if_regex, str)
        tot_len = length(if_match[:cond]) + length(if_match[:yes]) + length(if_match[:no])
        tot_len ≥ max_length && continue

        print(buf, @view str[prev_pos:first(if_match.offset)-1])
        if !isnothing(if_match[:if_inline])
            # Then the `if` statement is followed by another expression on the same line, e.g. the
            # user wrote `(a ? b : c) * 42`.
            # For correctness, we must surround the ternary statement with parentheses.
            print(buf, "(", if_match[:cond], " ? ", if_match[:yes], " : ", if_match[:no], ")")
        else
            # Normal `if` statement
            print(buf, if_match[:cond], " ? ", if_match[:yes], " : ", if_match[:no], if_match[:if_end])
        end

        prev_pos = if_match.offset + length(if_match.match)
    end

    print(buf, @view str[prev_pos:end])
    return String(take!(buf))
end


function add_newlines_between_blocks(str::AbstractString)
    # Match only if the previous line has the same indent as the current one, and the current line
    # starts with any of those keywords. Keywords can be preceded by macros: this allows to match
    # blocks like `@testset` or `@threads`. We also ignore lines ending with `end`, to allow tight
    # packing of one liners.
    start_block_regex = r"^(?<prev_line>(?<prev_indent> *)\S.+\R)(?<this_line>\g{prev_indent}(@.+)?(baremodule|begin|do|for|function|if|let|macro|module|mutable|public|quote|struct|try|while))\b(?!.*end$)"m

    # Match only if the next line has the same indent as the current one, and the current line
    # is the end of a block.
    end_block_regex = r"^(?<this_line>(?<this_indent> *)end\R)(?<next_line>\g{this_indent})(?=\S)"m

    return replace(str,
        start_block_regex => s"\g<prev_line>\n\g<this_line>",
        end_block_regex => s"\g<this_line>\n\g<next_line>",
    )
end


function remove_outer_block(str::AbstractString, indent_width)
    if startswith(str, "begin") && endswith(str, "end")
        return replace(str,
            # Remove the leading indent of all lines
            r"^"m * " "^indent_width => "",
            # Remove the `begin` block around the code
            r"^begin\R" => "",
            r"\Rend$"   => "",
        )
    else
        return str
    end
end


"""
    cleanup_code(::Val{:ast}, expr::Expr, dbinfo, cleanup_opts)
    cleanup_code(::Val{:ast}, expr::AbstractString, dbinfo, cleanup_opts)

Cleanup the AST in `expr`. If `expr isa Expr`, it is first converted to a `String` with `Base.show`.

As the cleanup step is supposed to operate only on strings, `MacroTools.prettify` isn't applied here
but by [`CodeDiffs.code_ast`](@ref).

Accepted `cleanup_opts` and their default values:
 - `compact_if=true`: transforms small `if` blocks into one-liner ternary statements
 - `line_length=120`: threshold after which `compact_if` keeps the whole `if` statement, to prevent
   very long lines.
 - `fix_indents=true`: removes unnecessary indents (e.g. `@threads for ...` is over-indented by default)
 - `add_newlines=true`: attempts to unclutter the code by adding newlines in-between blocks at the
   same indentation level.
 - `ast_pretty_print=true`: hijack AST printing to add (or remove) newlines where appropriate. This
   only works if an `Expr` is given.
"""
function cleanup_code(::Val{:ast}, expr::AbstractString, dbinfo, cleanup_opts)
    indent_width = Base.indent_width
    max_line_length = get(cleanup_opts, :line_length, 120)

    expr = remove_outer_block(expr, indent_width)

    if get(cleanup_opts, :compact_if, true)
        expr = small_if_to_ternary(expr, max_line_length)
    end
    if get(cleanup_opts, :fix_indents, true)
        expr = remove_unnecessary_indents(expr, indent_width)
    end
    if get(cleanup_opts, :add_newlines, true)
        expr = add_newlines_between_blocks(expr)
    end

    return expr
end
