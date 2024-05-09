
# Use `print` by default instead of `Base.show(io, MIME"text/plain", s)` to avoid quotes
# and escape sequences for strings
no_highlighting(io::IO, s::AbstractString) = print(io, s)
no_highlighting(io::IO, c) = Base.show(io, MIME"text/plain"(), c)

"""
    code_highlighter(::Val{code_type}) where {code_type}

Return a function of signature `(io::IO, code_obj)` which prints `code_obj` to `io` with
highlighting/decorations. By default `print(io, code_obj)` is used for `AbstractString`s
and `Base.show(io, MIME"text/plain"(), code_obj)` otherwise.

The highlighting function is called twice: once for color-less text and again with color.
"""
code_highlighter(_) = no_highlighting

code_highlighter(::Val{:native}) = InteractiveUtils.print_native
code_highlighter(::Val{:llvm}) = InteractiveUtils.print_llvm


highlight_ast(io::IO, ast::Expr) = highlight_ast(io, sprint(Base.show, ast))

function highlight_ast(io::IO, ast::AbstractString)
    if !haskey(Base.loaded_modules, OhMYREPL_PKG_ID)
        @warn "OhMyREPL.jl is not loaded, AST highlighting will not work" maxlog=1
    end
    ast_md = Markdown.MD(Markdown.julia, Markdown.Code("julia", ast))

    ast_md_str = sprint(Base.show, MIME"text/plain"(), ast_md; context=IOContext(io))
    if startswith(ast_md_str, "  ")
        # Markdown adds two spaces in front of every line
        ast_md_str = replace(ast_md_str[3:end], "\n  " => '\n')
    end

    print(io, ast_md_str)
end

code_highlighter(::Val{:ast}) = highlight_ast
