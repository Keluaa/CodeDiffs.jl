
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


function replace_expr_for_printing(expr::Expr)
    expr = MacroTools.postwalk(expr) do e
        MacroTools.@capture(e, struct S_ end | mutable struct S_ end) && return OneLinerExpr(e)
        return e
    end
    return expr isa Expr ? expr : Expr(:block, expr)
end


function cleanup_code(::Val{:ast}, expr::Expr, dbinfo, cleanup_opts)
    # Some transformations can only be safely done in the AST, as otherwise we would need to parse
    # the AST string representation, which we would like to avoid.
    expr = replace_expr_for_printing(expr)
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


function remove_uncessecary_indents(str::AbstractString, indent_width)
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
        print(buf, @view line[extra_indent*indent_width+1:end])

        prev_indent = indent
    end

    return String(take!(buf))
end


function small_if_to_ternary(str::AbstractString, max_length)
    # Matches a multiline `if` statement (any indent level), but only if each block fits in a single line.
    # At the end of the `if`, we either match a newline (`if_end`) or the begining of the next expression.
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
    # starts with any of those keywords. Keywords can be preceeded by macros: this allows to match
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
 - `fix_indents=true`: removes unnecessary indents (e.g. `@threads for ...` is over-indended by default)
 - `add_newlines=true`: attempts to unclutter the code by adding newlines in-between blocks at the
   same indentation level.
"""
function cleanup_code(::Val{:ast}, expr::AbstractString, dbinfo, cleanup_opts)
    indent_width = Base.indent_width
    max_line_length = get(cleanup_opts, :line_length, 120)

    expr = remove_outer_block(expr, indent_width)

    if get(cleanup_opts, :compact_if, true)
        expr = small_if_to_ternary(expr, max_line_length)
    end
    if get(cleanup_opts, :fix_indents, true)
        expr = remove_uncessecary_indents(expr, indent_width)
    end
    if get(cleanup_opts, :add_newlines, true)
        expr = add_newlines_between_blocks(expr)
    end

    return expr
end
