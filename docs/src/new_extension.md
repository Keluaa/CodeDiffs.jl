```@meta
CurrentModule = CodeDiffs
```

# Defining a new extension

Defining a new `code_type` involves four functions:
- `CodeDiffs.get_code_dispatch(::Val{code_type}, f, types; kwargs...)` (**not** `get_code`!)
  should return a printable object (usually a `String`) representing the code for `f(types)`.
  `kwargs` are the options passed to `@code_diff`.
- `CodeDiffs.Cleanup.cleanup_code(::Val{:code_type}, code, dbinfo, cleanup_opts)` does some cleanup
  on the code object to make it more `diff`-able.
- `CodeDiffs.code_highlighter(::Val{code_type})` returns a `f(io, obj)` to print the `obj`
  to as text in `io`. This is done twice: once without highlighting (`get(io, :color, false) == false`),
  and another with highlighting.
- `CodeDiffs.argconvert(::Val{code_type}, arg)` converts `arg` as needed (by default `arg` is unchanged)

Defining a new pre-processing step for functions and its arguments (like for KernelAbstractions.jl kernels)
involves two functions:
- `CodeDiffs.extract_extra_options(f, kwargs)` returns some additional `kwargs` which are passed to `get_code`
- `CodeDiffs.get_code(code_type, f, types; kwargs...)` allows to change `f` depending on its type.
  To avoid method ambiguities, do not put type constraints on `code_type`.

Defining a new object type which can be put as an argument to `@code_diff` or `@code_for`
invoves at one function: `CodeDiffs.code_for_diff(obj::YourType; kwargs...)`.
It must return two `String`s, one without and the other without highlighting.
When calling `@code_for obj`, [`code_for_diff(obj)`](@ref) will be called only if `obj` is
not a call expression or a quoted `Expr`.
`kwargs` are the options passed to `@code_for` or the options passed to `@code_diff` for
the side of `obj`.
