
struct LLVMCallBodyDef
    code  :: String
    entry :: String
end


function Base.show(io::IO, llvmcall::LLVMCallBodyDef)
    print(io, "Core.tuple(\"\"\"")
    if get(io, :color, false)
        CodeDiffs.code_highlighter(Val(:llvm))(io, llvmcall.code)
    else
        println(io, llvmcall.code)
    end
    print(io, "  \"\"\", \"", llvmcall.entry, "\")")
end


"""
    cleanup_inline_llvmcall_modules(c::Core.CodeInfo)
    cleanup_inline_llvmcall_modules(c::Vector{Any})

Replace the LLVM-IR body of `Base.llvmcall` expressions in `c` to something more readable
using an unescaped string, allowing to display the IR over multiple lines, with highlighting.

Only the LLVM function declaration is kept, other code (annotations, etc...) are stripped.
"""
cleanup_inline_llvmcall_modules(c::Pair{Core.CodeInfo, <:Any}) =
    (cleanup_inline_llvmcall_modules(first(c)); c)
cleanup_inline_llvmcall_modules(c::Core.CodeInfo) =
    (cleanup_inline_llvmcall_modules(c.code); c)

is_llvmcall(_) = false
is_llvmcall(e::Expr) = Base.isexpr(e, :call) && e.args[1] in (GlobalRef(Base, :llvmcall), :(Base.llvmcall))

function cleanup_inline_llvmcall_modules(c::Vector{Any})
    # GPU packages tend to use inline LLVM calls, which can make the typed source hard to
    # read. This expands the source into a multiline string and strips extra LLVM IR info.

    # LLVM-IR function declaration regex. We rely on the fact that the beginning of the
    # body starts with a "{\n" and ends with "\n}\n".
    llvmcall_body_regex = r"define.+?{\n.+?\n}(?=\n|$)"s
    for expr in c
        # Expect `Base.llvmcall(<llvm IR code SSA ID>, ...)`
        !is_llvmcall(expr) && continue
        length(expr.args) < 2 && continue
        !(expr.args[2] isa Core.SSAValue) && continue
        code_pos = expr.args[2].id  # the SSAValue ID is the index of the LLVM code in `c`
        !(code_pos in eachindex(c)) && continue

        # The source of a LLVM call is placed in a `Core.tuple(src, entry_point)` expression
        code_expr = c[code_pos]
        !@capture(code_expr, f_(code_, entry_)) && continue
        !(f == GlobalRef(Core, :tuple) || f == :(Core.tuple)) && continue
        !(code isa String) && continue

        # Extract the function of the llvmcall body. We assume that there is only one.
        # This also means that we discard all annotations around the body.
        body = match(llvmcall_body_regex, code)
        isnothing(body) && continue

        indent = "  "
        body = unescape_string(body.match)
        body = replace(body, "\n" => "\n" * indent)

        cleaner_code = "; stripped llvmcall body\n$indent$body"

        # Placing the modified body in the original `Expr` would be ugly, as the string
        # would be escaped, newlines included. For proper pretty printing, we must use a
        # custom object with `Base.show` set to not escape the string.
        c[code_pos] = LLVMCallBodyDef(cleaner_code, entry)
    end
end


"""
    cleanup_code(::Val{:typed}, code, dbinfo, cleanup_opts)

Cleanup Julia typed IR `code`.

Accepted `cleanup_opts` and their default values:
 - `expand_llvmcall=true`: replace raw inline LLVM IR with multiline blocks with syntax highlighting.
"""
function cleanup_code(::Val{:typed}, c, dbinfo, cleanup_opts)
    if get(cleanup_opts, :expand_llvmcall, true)
        c = cleanup_inline_llvmcall_modules(c)
    end
    return c
end

cleanup_code(::Val{:gpu_typed}, c, dbinfo, cleanup_opts) =
    cleanup_code(Val{:typed}(), c, dbinfo, cleanup_opts)
