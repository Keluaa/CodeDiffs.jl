
"""
    function_unique_gen_name_regex()
    function_unique_gen_name_regex(function_name)

Regex matching all LLVM function names which might change from one compilation to another.
As an example, in the outputs of `@code_llvm` below:
```julia
julia> f() = 1
f (generic function with 1 method)

julia> @code_llvm f()
...
define i64 @julia_f_855() #0 {
...

julia> @code_llvm f()
...
define i64 @julia_f_857() #0 {
...
```
the regex will match `julia_f_855` and `julia_f_857`.

`function_unique_gen_name_regex()` should work for any function which does not have any
characters in `'",;-` or spaces in its name.
The function name is either in the capture group `1` or `2`.

`function_unique_gen_name_regex(function_name)` should work with any generated name for the
given function name.

It is `'globalUniqueGeneratedNames'` in `'julia/src/codegen.cpp'` which gives the unique
number on the generated code. The regex matches most usages of this counter:
- from [`get_function_name`](https://github.com/JuliaLang/julia/blob/89cae45ea4f75ce81fff08ca6e731e72e838f4ad/src/codegen.cpp#L7507)
    - `julia_<function_name>_<unique_num>`
    - `japi3_<function_name>_<unique_num>`
    - `japi1_<function_name>_<unique_num>`

- from [`'src/codegen.cpp#L4713'`](https://github.com/JuliaLang/julia/blob/89cae45ea4f75ce81fff08ca6e731e72e838f4ad/src/codegen.cpp#L4713)
    - `j_<function_name>_<unique_num>`
    - `j1_<function_name>_<unique_num>`

- from [`'src/codegen.cpp#L6407'`](https://github.com/JuliaLang/julia/blob/89cae45ea4f75ce81fff08ca6e731e72e838f4ad/src/codegen.cpp#L6407)
    - `jlcapi_<function_name>_<unique_num>`

- from [`'src/codegen.cpp#L7753'`](https://github.com/JuliaLang/julia/blob/89cae45ea4f75ce81fff08ca6e731e72e838f4ad/src/codegen.cpp#L7753)
    - `jfptr_<function_name>_<unique_num>`

- from [`'src/codegen.cpp#L6185'`](https://github.com/JuliaLang/julia/blob/89cae45ea4f75ce81fff08ca6e731e72e838f4ad/src/codegen.cpp#L6185)
    - `tojlinvoke<unique_num>`
"""
function_unique_gen_name_regex() =
    r"(?>(?>julia|japi3|japi1|jlcapi|jfptr|j1|j)_([^\"\s,;\-']*)_|(tojlinvoke))(\d+)"
function_unique_gen_name_regex(function_name) =
    Regex("(?>julia|japi3|japi1|jlcapi|jfptr|j1|j)_\\Q$(function_name)\\E_(\\d+)")


"""
    global_var_unique_gen_name_regex()
    global_var_unique_gen_name_regex(global_name)

Regex matching all global variable names which might change from one compilation to another.

!!! compat "Julia 1.11"
    Those global variables names only appear starting from Julia 1.11.

In LLVM IR, those variables are mentioned as such: `@"+Core.GenericMemory#14067.jit"`.
In native code, they look like this: `".L+Core.GenericMemory#13985.jit"`, with maybe some
`.set` and `.size` sections at the end of the code (in x86 ASM).

`global_var_unique_gen_name_regex()` should work for any variable which does not have any
characters in `'",;-` or spaces in its name.

`global_var_unique_gen_name_regex(global_name)` should work with any generated name for the
given variable name.

It is `'globalUniqueGeneratedNames'` in `'julia/src/codegen.cpp'` which gives the unique
number on the generated code. The regex matches only a single usage of this counter:
in `julia_pgv(ctx, cname, addr)` at [`'src/cgutils.cpp#L358'`](https://github.com/JuliaLang/julia/blob/08e1fc0abb959ce5bd4c75b05518a41b85e4aba1/src/cgutils.cpp#L358)
which is then added a `".jit"` suffix in [`'src/aotcompile.cpp#L2064'`](https://github.com/JuliaLang/julia/blob/08e1fc0abb959ce5bd4c75b05518a41b85e4aba1/src/aotcompile.cpp#L2064)
when doing code introspection.
"""
global_var_unique_gen_name_regex() = r"(\+[^\"\s,;\-']+)#\d+\.jit"
global_var_unique_gen_name_regex(global_name) = Regex("(\\+\\Q$(global_name)\\E)#\\d+\\.jit")


"""
    replace_llvm_module_name(code::AbstractString)

Remove in `code` the trailing numbers in the LLVM module names, e.g. `"julia_f_2007" => "f"`.
This allows to remove false differences when comparing raw code, since each call to
`code_native` (or `code_llvm`) triggers a new compilation using an unique LLVM module name,
therefore each consecutive call is different even though the actual code does not
change.

In Julia 1.11+, global variables names are also replaced with [`global_var_unique_gen_name_regex`](@ref).

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
function replace_llvm_module_name(code::AbstractString)
    @static if VERSION ≥ v"1.11-"
        return replace(code,
            function_unique_gen_name_regex() => s"\1\2",
            global_var_unique_gen_name_regex() => s"\1.jit"  # get rid of the '#<gen_num>' part
        )
    else
        return replace(code, function_unique_gen_name_regex() => s"\1\2")
    end
end


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
    func_re = function_unique_gen_name_regex(function_name)
    return replace(code, func_re => function_name)
end


"""
    demangle(name::AbstractString)

Demangle `name` into a C/C++ name using the [demumble](https://github.com/nico/demumble)
utility.
"""
demangle(name::AbstractString) = readchomp(`$(demumble()) $name`)


"""
    mangled_base_name(name::AbstractString)

Attempt to return the base name in the mangled function `name`.
If it fails, `nothing` is returned.
"""
function mangled_base_name(name::AbstractString)
    # Suppose Itanium encoding
    encoding_prefix = findfirst(r"_{0,4}Z", name)
    isnothing(encoding_prefix) && return nothing

    # The name length precedes the base name
    raw_name_length = findnext(r"\d+", name, last(encoding_prefix)+1)
    isnothing(raw_name_length) && return nothing
    name_length = tryparse(Int, @view name[raw_name_length])
    isnothing(name_length) && return nothing

    name_start = last(raw_name_length)+1
    return @view name[name_start:name_start+name_length-1]
end


# Matches Itanium ABI mangled names
# See https://github.com/llvm/llvm-project/blob/56cb55429199435a78f6e836f52cf41577406e90/llvm/lib/Demangle/Demangle.cpp#L40
# And https://github.com/llvm/llvm-project/blob/56cb55429199435a78f6e836f52cf41577406e90/llvm/tools/llvm-cxxfilt/llvm-cxxfilt.cpp#L137
const MANGLED_NAME_REGEX = r"\b(_{0,4}Z[0-9A-Za-z_.$]+)"m


# Matches the mangled name of a function definition in LLVM IR
# See https://llvm.org/docs/LangRef.html#functions
const LLVM_IR_FUNC_NAME_MANGLED_REGEX = r"define\s[^@]*@"m * MANGLED_NAME_REGEX


"""
    demangle_all(code::AbstractString)

Find and replace all mangled names in `code` with their demangled counterparts.
"""
demangle_all(code::AbstractString) = replace(code, MANGLED_NAME_REGEX => demangle)


"""
    clean_function_name(name_regex, code, replacement=nothing)

Replace occurences of `name_regex` in the `code` by `replacement`.
`replacement` defaults to the demangled function name.
"""
function clean_function_name(name_regex, c, replacement=nothing)
    # TODO: what happens when there is more than one function in a module? is the result wrong?
    m = match(name_regex, c)
    isnothing(m) && return c
    mangled_name = m[1]

    if isnothing(replacement)
        # Simplest demangling: '_Z6blabla...' => 'blabla'
        replacement = mangled_base_name(mangled_name)
        if isnothing(replacement)
            # Complete demangling: the main disadvantage is that the demangled name might
            # be very long, to the point where is becomes barely readable and useless.
            replacement = demangle(mangled_name)
        end
    end

    return replace(c, mangled_name => replacement)
end


struct LLVMCallBodyDef
    code  :: String
    entry :: String
end


function Base.show(io::IO, llvmcall::LLVMCallBodyDef)
    print(io, "Core.tuple(\"\"\"")
    if get(io, :color, false)
        code_highlighter(Val(:llvm))(io, llvmcall.code)
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
cleanup_inline_llvmcall_modules(c::Pair{Core.CodeInfo, DataType}) =
    (cleanup_inline_llvmcall_modules(first(c)); c)
cleanup_inline_llvmcall_modules(c::Core.CodeInfo) =
    (cleanup_inline_llvmcall_modules(c.code); c)

is_llvmcall(_) = false
is_llvmcall(e::Expr) = Base.isexpr(e, :call) && e.args[1] in (GlobalRef(Base, :llvmcall), :(Base.llvmcall))

function cleanup_inline_llvmcall_modules(c::Vector{Any})
    # GPU packages tend to use inline LLVM calls, which can make the typed source hard to
    # read. This expands the source into a multiline string and strips extra LLVM IR info.

    llvmcall_body_regex = r"define[^{]+{[^}]+}"  # LLVM-IR function declaration regex
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
        isnothing(body) && return nothing

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
    cleanup_code(::Val{code_type}, code, dbinfo=true, cleanup_opts=(;))

Perform minor changes to `code` to improve readability and the quality of the differences.

`dbinfo` is a superset of `debuginfo`. It is compatible with all code types, but it may
have no effect.

`cleanup_opts` are passed by the user, and have specific meaning depending on the `code_type`.

Currently only [`replace_llvm_module_name`](@ref) is applied to `:native` and `:llvm` code.
For GPU code much more cleanup is done.
"""
cleanup_code(type, code) = cleanup_code(type, code, true, (;))
cleanup_code(type, code, dbinfo) = cleanup_code(type, code, dbinfo, (;))

cleanup_code(_, c, _, _) = c

cleanup_code(::Val{:native}, c, dbinfo, cleanup_opts) = replace_llvm_module_name(c)
cleanup_code(::Val{:llvm}, c, dbinfo, cleanup_opts) = replace_llvm_module_name(c)

function cleanup_code(::Val{:typed}, c, dbinfo, cleanup_opts)
    if get(cleanup_opts, :expand_llvmcall, true)
        c = cleanup_inline_llvmcall_modules(c)
    end
    return c
end
