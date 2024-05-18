
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

It the `'globalUniqueGeneratedNames'` in `'julia/src/codegen.cpp'` which gives the unique
number on the generated code. The regex matches all usages of this counter:
- from [`get_function_name`](https://github.com/JuliaLang/julia/blob/89cae45ea4f75ce81fff08ca6e731e72e838f4ad/src/codegen.cpp#L7507)
    - `julia_<function_name>_<unique_num>`
    - `japi3_<function_name>_<unique_num>`
    - `japi1_<function_name>_<unique_num>`
- from [src/codegen.cpp#L4713](https://github.com/JuliaLang/julia/blob/89cae45ea4f75ce81fff08ca6e731e72e838f4ad/src/codegen.cpp#L4713)
    - `j_<function_name>_<unique_num>`
    - `j1_<function_name>_<unique_num>`
- from [src/codegen.cpp#L6407](https://github.com/JuliaLang/julia/blob/89cae45ea4f75ce81fff08ca6e731e72e838f4ad/src/codegen.cpp#L6407)
    - `jlcapi_<function_name>_<unique_num>`
- from [src/codegen.cpp#L7753](https://github.com/JuliaLang/julia/blob/89cae45ea4f75ce81fff08ca6e731e72e838f4ad/src/codegen.cpp#L7753)
    - `jfptr_<function_name>_<unique_num>`
- from [src/codegen.cpp#L6185](https://github.com/JuliaLang/julia/blob/89cae45ea4f75ce81fff08ca6e731e72e838f4ad/src/codegen.cpp#L6185)
    - `tojlinvoke<unique_num>`
"""
function_unique_gen_name_regex() =
    r"(?>(?>julia|japi3|japi1|jlcapi|jfptr|j1|j)_([^\"\s,;\-']*)_|(tojlinvoke))(\d+)"
function_unique_gen_name_regex(function_name) =
    Regex("(?>julia|japi3|japi1|jlcapi|jfptr|j1|j)_\\Q$(function_name)\\E_(\\d+)")


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
replace_llvm_module_name(code::AbstractString) =
    replace(code, function_unique_gen_name_regex() => s"\1\2")


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
    cleanup_code(::Val{code_type}, code)

Perform minor changes to `code` to improve readability and the quality of the differences.

Currently only [`replace_llvm_module_name`](@ref) is applied to `:native` and `:llvm` code.
"""
cleanup_code(_, c) = c

cleanup_code(::Val{:native}, c) = replace_llvm_module_name(c)
cleanup_code(::Val{:llvm}, c) = replace_llvm_module_name(c)
