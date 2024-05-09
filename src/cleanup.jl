
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


"""
    cleanup_code(::Val{code_type}, code)

Perform minor changes to `code` to improve readability and the quality of the differences.

Currently only [`replace_llvm_module_name`](@ref) is applied to `:native` and `:llvm` code.
"""
cleanup_code(_, c) = c

cleanup_code(::Val{:native}, c) = replace_llvm_module_name(c)
cleanup_code(::Val{:llvm}, c) = replace_llvm_module_name(c)
