var documenterSearchIndex = {"docs":
[{"location":"","page":"Home","title":"Home","text":"CurrentModule = CodeDiffs","category":"page"},{"location":"#CodeDiffs","page":"Home","title":"CodeDiffs","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Compare different types of code and display it in the terminal. For cleaner results, syntax highlighting is separated from the difference calculation.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Supports:","category":"page"},{"location":"","page":"Home","title":"Home","text":"native CPU assembly (output of @code_native, highlighted by InteractiveUtils.print_native)\nLLVM IR (output of @code_llvm, highlighted by InteractiveUtils.print_llvm)\nTyped Julia IR (output of @code_typed, highlighted through the Base.show method of Core.CodeInfo)\nJulia AST (an Expr), highlighting is done with:\nOhMyREPL.jl's Julia syntax highlighting in Markdown code blocks\n(Julia ≥ v1.11) JuliaSyntaxHighlighting.jl","category":"page"},{"location":"","page":"Home","title":"Home","text":"The @code_diff macro is the main entry point. If possible, the code type will be detected automatically, otherwise add e.g. type=:llvm for LLVM IR comparison:","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> f1(a) = a + 1\nf1 (generic function with 1 method)\n\njulia> @code_diff type=:llvm debuginfo=:none color=false f1(Int64(1)) f1(Int8(1))\ndefine i64 @f1(i64 signext %0) #0 {   ⟪╋⟫define i64 @f1(i8 signext %0) #0 {\ntop:                                   ┃ top:\n                                       ┣⟫  %1 = sext i8 %0 to i64\n  %1 = add i64 %0, 1                  ⟪╋⟫  %2 = add nsw i64 %1, 1\n  ret i64 %1                          ⟪╋⟫  ret i64 %2\n}                                      ┃ }\n\njulia> f2(a) = a - 1\nf2 (generic function with 1 method)\n\njulia> @code_diff type=:llvm debuginfo=:none color=false f1(1) f2(1)\ndefine i64 @f1(i64 signext %0) #0 {   ⟪╋⟫define i64 @f2(i64 signext %0) #0 {\ntop:                                   ┃ top:\n  %1 = add i64 %0, 1                  ⟪╋⟫  %1 = add i64 %0, -1\n  ret i64 %1                           ┃   ret i64 %1\n}                                      ┃ }","category":"page"},{"location":"","page":"Home","title":"Home","text":"Setting the environment variable \"CODE_DIFFS_LINE_NUMBERS\" to true will display line numbers on each side:","category":"page"},{"location":"","page":"Home","title":"Home","text":"julia> ENV[\"CODE_DIFFS_LINE_NUMBERS\"] = true\ntrue\n\njulia> @code_diff type=:llvm debuginfo=:none color=false f1(1) f2(1)\n1 define i64 @f1(i64 signext %0) #0 { ⟪╋⟫define i64 @f2(i64 signext %0) #0 { 1\n2 top:                                 ┃ top:                                2\n3   %1 = add i64 %0, 1                ⟪╋⟫  %1 = add i64 %0, -1               3\n4   ret i64 %1                         ┃   ret i64 %1                        4\n5 }                                    ┃ }                                   5","category":"page"},{"location":"#Main-functions","page":"Home","title":"Main functions","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"CodeDiff\ncompare_code_native\ncompare_code_llvm\ncompare_code_typed\ncompare_ast\ncode_diff(::Any, ::Any)\ncode_diff(::Val{:ast}, ::Any, ::Any)\n@code_diff","category":"page"},{"location":"#CodeDiffs.CodeDiff","page":"Home","title":"CodeDiffs.CodeDiff","text":"CodeDiff(code₁, code₂)\nCodeDiff(code₁, code₂, highlighted₁, highlighted₂)\n\nA difference between code₁ and code₂.\n\ncode₁ and code₂ should have no highlighting. Only highlighted₁ and highlighted₂ should have syntax highlighting. When showing the differences, their formatting will be re-applied.\n\nFor cleaner differences, use replace_llvm_module_name on all codes.\n\nUse optimize_line_changes! to improve the difference.\n\nFancy REPL output is done with side_by_side_diff.\n\n\n\n\n\n","category":"type"},{"location":"#CodeDiffs.compare_code_native","page":"Home","title":"CodeDiffs.compare_code_native","text":"compare_code_native(code₁, code₂; color=true)\n\nReturn a CodeDiff between code₁ and code₂. Codes are cleaned-up with replace_llvm_module_name beforehand.\n\nIf color == true, then both codes are highlighted using InteractiveUtils.print_native.\n\n\n\n\n\ncompare_code_native(\n    f₁::Base.Callable, types₁::Type{<:Tuple},\n    f₂::Base.Callable, types₂::Type{<:Tuple};\n    color=true, kwargs...\n)\n\nCall InteractiveUtils.code_native(f₁, types₁) and InteractiveUtils.code_native(f₂, types₂) and return their CodeDiff. kwargs are passed to code_native.\n\n\n\n\n\ncompare_code_native(\n    f::Base.Callable, types::Type{<:Tuple}, world₁, world₂;\n    color=true, kwargs...\n)\n\nSimilar to compare_code_native(f₁, types₁, f₂, types₂), but as a difference between f in world ages world₁ and world₂.\n\n\n\n\n\n","category":"function"},{"location":"#CodeDiffs.compare_code_llvm","page":"Home","title":"CodeDiffs.compare_code_llvm","text":"compare_code_llvm(code₁, code₂; color=true)\n\nReturn a CodeDiff between code₁ and code₂. Codes are cleaned-up with replace_llvm_module_name beforehand.\n\nIf color == true, then both codes are highlighted using InteractiveUtils.print_llvm.\n\n\n\n\n\ncompare_code_llvm(\n    f₁::Base.Callable, types₁::Type{<:Tuple},\n    f₂::Base.Callable, types₂::Type{<:Tuple};\n    color=true, kwargs...\n)\n\nCall InteractiveUtils.code_llvm(f₁, types₁) and InteractiveUtils.code_llvm(f₂, types₂) and return their CodeDiff. kwargs are passed to code_llvm.\n\n\n\n\n\ncompare_code_llvm(\n    f::Base.Callable, types::Type{<:Tuple}, world₁, world₂;\n    color=true, kwargs...\n)\n\nSimilar to compare_code_llvm(f₁, types₁, f₂, types₂), but as a difference between f in world ages world₁ and world₂.\n\n\n\n\n\n","category":"function"},{"location":"#CodeDiffs.compare_code_typed","page":"Home","title":"CodeDiffs.compare_code_typed","text":"compare_code_typed(code_info₁::Pair, code_info₂::Pair; color=true)\ncompare_code_typed(code_info₁::Core.CodeInfo, code_info₂::Core.CodeInfo; color=true)\n\nReturn a CodeDiff between code_info₁ and code_info₂.\n\nIf color == true, then both codes are highlighted.\n\n\n\n\n\ncompare_code_typed(\n    f₁::Base.Callable, types₁::Type{<:Tuple},\n    f₂::Base.Callable, types₂::Type{<:Tuple};\n    color=true, kwargs...\n)\n\nCall Base.code_typed(f₁, types₁) and Base.code_typed(f₂, types₂) and return their CodeDiff. kwargs are passed to code_typed.\n\nBoth function calls should only match a single method.\n\n\n\n\n\ncompare_code_typed(\n    f::Base.Callable, types::Type{<:Tuple}, world₁, world₂;\n    color=true, kwargs...\n)\n\nSimilar to compare_code_typed(f₁, types₁, f₂, types₂), but as a difference between f in world ages world₁ and world₂.\n\n\n\n\n\n","category":"function"},{"location":"#CodeDiffs.compare_ast","page":"Home","title":"CodeDiffs.compare_ast","text":"compare_ast(code₁::Expr, code₂::Expr; color=true, prettify=true, lines=false, alias=false)\n\nA CodeDiff between code₁ and code₂, relying on the native display of Julia AST.\n\nIf prettify == true, then MacroTools.prettify(code; lines, alias) is used to cleanup the AST. lines == true will keep the LineNumberNodes and alias == true will replace mangled names (or gensyms) by dummy names.\n\ncolor == true is special, see compare_ast(code₁::AbstractString, code₂::AbstractString).\n\n\n\n\n\ncompare_ast(code₁::AbstractString, code₂::AbstractString; color=true)\ncompare_ast(code₁::Markdown.MD, code₂::Markdown.MD; color=true)\n\nCodeDiff between Julia code string, in the form of Markdown code blocks.\n\nRelies on the Markdown code highlighting from OhMyREPL.jl to colorize Julia code.\n\n\n\n\n\ncompare_ast(\n    f₁::Base.Callable, types₁::Type{<:Tuple},\n    f₂::Base.Callable, types₂::Type{<:Tuple};\n    color=true, kwargs...\n)\n\nRetrieve the AST for the definitions of the methods matching the calls to f₁ and f₂ using CodeTracking.jl, then compare them.\n\nFor CodeTracking.jl to work, Revise.jl must be loaded.\n\n\n\n\n\n","category":"function"},{"location":"#CodeDiffs.code_diff-Tuple{Any, Any}","page":"Home","title":"CodeDiffs.code_diff","text":"code_diff(::Val{type}, f₁, types₁, f₂, types₂; kwargs...)\ncode_diff(::Val{type}, code₁, code₂; kwargs...)\ncode_diff(args...; type=:native, kwargs...)\n\nDispatch to compare_code_native, compare_code_llvm, compare_code_typed or compare_ast depending on type.\n\n\n\n\n\n","category":"method"},{"location":"#CodeDiffs.code_diff-Tuple{Val{:ast}, Any, Any}","page":"Home","title":"CodeDiffs.code_diff","text":"code_diff(::Val{:ast}, code₁, code₂; kwargs...)\n\nCompare AST in code₁ and code₂, which can be Expr or any AbstractString.\n\n\n\n\n\n","category":"method"},{"location":"#CodeDiffs.@code_diff","page":"Home","title":"CodeDiffs.@code_diff","text":"@code_diff [type=:native] [option=value...] f₁(...) f₂(...)\n@code_diff [option=value...] :(expr₁) :(expr₂)\n\nCompare the methods called by the f₁(...) and f₂(...) expressions, and return a CodeDiff.\n\noptions are passed as key-word arguments to code_diff and then to the compare_code_* function for the given code type.\n\nIn the other form of @code_diff, compare the Expressions expr₁ and expr₂, the type is inferred as :ast. To compare Expr in variables, use @code_diff :($a) :($b), or call compare_ast directly.\n\n\n\n\n\n","category":"macro"},{"location":"#Display-functions","page":"Home","title":"Display functions","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"optimize_line_changes!\nreplace_llvm_module_name\nside_by_side_diff","category":"page"},{"location":"#CodeDiffs.optimize_line_changes!","page":"Home","title":"CodeDiffs.optimize_line_changes!","text":"optimize_line_changes!(diff::CodeDiff; dist=Levenshtein(), tol=0.7)\n\nMerges consecutive line removals+additions into single line changes in diff, when they are within the tolerance of the normalized string distance.\n\nThis does not aim to produce an optimal CodeDiff, but simply improve its display.\n\n\n\n\n\n","category":"function"},{"location":"#CodeDiffs.replace_llvm_module_name","page":"Home","title":"CodeDiffs.replace_llvm_module_name","text":"replace_llvm_module_name(code::AbstractString)\n\nRemove in code the trailing numbers in the LLVM module names, e.g. \"julia_f_2007\" => \"f\". This allows to remove false differences when comparing raw code, since each call to code_native (or code_llvm) triggers a new compilation using an unique LLVM module name, therefore each consecutive call is different even though the actual code does not change.\n\njulia> f() = 1\nf (generic function with 1 method)\n\njulia> buf = IOBuffer();\n\njulia> code_native(buf, f, Tuple{})  # Equivalent to `@code_native f()`\n\njulia> code₁ = String(take!(buf));\n\njulia> code_native(buf, f, Tuple{})\n\njulia> code₂ = String(take!(buf));\n\njulia> code₁ == code₂  # Different LLVM module names...\nfalse\n\njulia> replace_llvm_module_name(code₁) == replace_llvm_module_name(code₂)  # ...but same code\ntrue\n\n\n\n\n\nreplace_llvm_module_name(code::AbstractString, function_name)\n\nReplace only LLVM module names for function_name.\n\n\n\n\n\n","category":"function"},{"location":"#CodeDiffs.side_by_side_diff","page":"Home","title":"CodeDiffs.side_by_side_diff","text":"side_by_side_diff([io::IO,] diff::CodeDiff; tab_width=4, width=nothing, line_numbers=nothing)\n\nSide by side display of a CodeDiff to io (defaults to stdout).\n\nwidth defaults to the width of the terminal. It is 80 by default for non-terminal io.\n\ntab_width is the number of spaces tabs are replaced with.\n\nline_numbers=true will add line numbers on each side of the columns. It defaults to the environment variable \"CODE_DIFFS_LINE_NUMBERS\", which itself defaults to false.\n\n\n\n\n\n","category":"function"},{"location":"#Internals","page":"Home","title":"Internals","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"LLVM_MODULE_NAME_REGEX","category":"page"},{"location":"#CodeDiffs.LLVM_MODULE_NAME_REGEX","page":"Home","title":"CodeDiffs.LLVM_MODULE_NAME_REGEX","text":"LLVM_MODULE_NAME_REGEX\n\nShould match the LLVM module of any function which does not have any of '\",;- or spaces in it.\n\nIt is 'get_function_name', in 'julia/src/codegen.cpp' which builds the function name for the LLVM module used to get the function code. The regex is built to match any output from that function. Since the 'globalUniqueGeneratedNames' counter (the number at the end of the module name) is incremented at each call to 'get_function_name', and since code_llvm or code_native forces a compilation, it should be guaranteed that the match with the highest number at the end is the name of our function in code.\n\n\n\n\n\n","category":"constant"}]
}
