
using Aqua
using CodeDiffs
using CUDA
using DeepDiffs
using InteractiveUtils
using KernelAbstractions
using ReferenceTests
using Revise
using Test


function jl_options_overload(field::Symbol, state::Int8)
    # Unsafe way of setting `Base.JLOptions().field`
    field_idx = findfirst(==(field), fieldnames(Base.JLOptions))
    field_offset = fieldoffset(Base.JLOptions, field_idx)
    field_ptr = cglobal(:jl_options, Int8) + field_offset
    if fieldtype(Base.JLOptions, field_idx) === Int8
        prev = unsafe_load(field_ptr)
        unsafe_store!(field_ptr, Int8(state))
        return prev
    else
        error("unexpected type for `Base.JLOptions().$field`")
    end
end


macro no_overwrite_warning(expr)
    # Enable/disable the method overwrite warning through the JLOptions
    # See https://github.com/JuliaLang/julia/blob/fe0db7d9474781ee949c7927f806214c7fc00a9a/src/gf.c#L1569C39-L1569C67
    @static if VERSION < v"1.10-"
        return esc(expr)
    else
        prev_sym = gensym(:prev)
        return Expr(:tryfinally, quote
                $prev_sym = $jl_options_overload(:warn_overwrite, Int8(0))
                $(esc(expr))
            end, quote
                $jl_options_overload(:warn_overwrite, $prev_sym) 
            end
        )
    end
end


function eval_for_revise(str, path=tempname(), init=true)
    open(path, "w") do file
        println(file, str)
    end

    if init
        Revise.includet(path)
    else
        main_pkg_data = Revise.pkgdatas[Base.PkgId(nothing, "Main")]
        Revise.revise_file_now(main_pkg_data, path)
    end

    return path
end


# OhMyREPL is quite reluctant from loading its Markdown highlighting overload in a testing
# environment. See https://github.com/KristofferC/OhMyREPL.jl/blob/b0071f5ee785a81ca1e69a561586ff270b4dc2bb/src/OhMyREPL.jl#L106
prev = jl_options_overload(:isinteractive, Int8(1))
@no_overwrite_warning using OhMyREPL
jl_options_overload(:isinteractive, prev)


# Enable printing diffs to stdout only in CI by default
const TEST_PRINT_DIFFS = parse(Bool, get(ENV, "TEST_PRINT_DIFFS", get(ENV, "CI", "false")))
const TEST_IO = TEST_PRINT_DIFFS ? stdout : IOContext(IOBuffer(), stdout)


function display_str(v; mime=MIME"text/plain"(), compact=false, color=true, columns=nothing)
    # Fancy print `v` to a string
    columns = !isnothing(columns) ? columns : displaysize(stdout)[2]
    io = IOBuffer()
    io_ctx = IOContext(io, :compact => compact, :color => color)
    withenv("COLUMNS" => columns) do 
        if mime === nothing
            Base.show(io_ctx, v)
        else
            Base.show(io_ctx, mime, v)
        end
    end
    return String(take!(io))
end


function check_diff_display_order(diff::CodeDiffs.CodeDiff, order::Vector{<:Pair})
    xlines = split(diff.before, '\n')
    ylines = split(diff.after, '\n')
    order_idx = 1
    DeepDiffs.visitall(diff) do idx, state, _
        if state === :removed
            @test last(order[order_idx]) === nothing
            @test occursin(first(order[order_idx]), xlines[idx])
        elseif state === :added
            @test first(order[order_idx]) === nothing
            @test occursin(last(order[order_idx]), ylines[idx])
        elseif state === :changed
            line_diff = diff.changed[idx][3]
            @test occursin(first(order[order_idx]), line_diff.before)
            @test occursin(last(order[order_idx]), line_diff.after)
        else
            @test occursin(first(order[order_idx]), xlines[idx])
        end
        order_idx += 1
    end
end


@testset "CodeDiffs.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(CodeDiffs)
    end

    @testset "AST" begin
        diff = CodeDiffs.code_diff((:(1+2),), (:(1+2),); type=:ast, color=false, prettify=false, lines=false, alias=false)
        @test CodeDiffs.issame(diff)
        @test diff.before == diff.highlighted_before == "quote\n    1 + 2\nend"

        diff = CodeDiffs.code_diff((:(1+2),), (:(1+3),); type=:ast, color=false, prettify=false, lines=false, alias=false)
        @test !CodeDiffs.issame(diff)
        @test length(DeepDiffs.added(diff)) == length(DeepDiffs.removed(diff)) == 1

        e = quote
            $(LineNumberNode(42, :file))
            1+2
        end
        diff = CodeDiffs.code_diff((e,), (:(1+2),); type=:ast, color=false, prettify=false, lines=true, alias=false)
        @test !CodeDiffs.issame(diff)
        @test occursin("#= file:42 =#", diff.before)
        diff = CodeDiffs.code_diff((e,), (:(1+2),); type=:ast, color=false, prettify=true, lines=false, alias=false)
        @test CodeDiffs.issame(diff)
        @test diff == (@code_diff color=false :($e) :(1+2))
    end

    @testset "Basic function" begin
        eval_for_revise("""
        f1() = 1
        f2() = 2
        """)

        @testset "Typed" begin
            diff = CodeDiffs.code_diff((f1, Tuple{}), (f1, Tuple{}); type=:typed, color=false)
            @test CodeDiffs.issame(diff)

            diff = CodeDiffs.code_diff((f1, Tuple{}), (f2, Tuple{}); type=:typed, color=false)
            @test !CodeDiffs.issame(diff)
            @test length(DeepDiffs.added(diff)) == length(DeepDiffs.removed(diff)) == 1
            @test diff == (@code_diff type=:typed color=false f1() f2())
        end

        @testset "LLVM" begin
            diff = CodeDiffs.code_diff((f1, Tuple{}), (f1, Tuple{}); type=:llvm, color=false)
            @test CodeDiffs.issame(diff)
            @test !occursin(r"julia_f1", diff.before)  # LLVM module names should have been cleaned up

            diff = CodeDiffs.code_diff((f1, Tuple{}), (f2, Tuple{}); type=:llvm, color=false)
            @test !CodeDiffs.issame(diff)
            @test diff == (@code_diff type=:llvm color=false f1() f2())
        end

        @testset "Native" begin
            diff = CodeDiffs.code_diff((f1, Tuple{}), (f1, Tuple{}); type=:native, color=false)
            @test CodeDiffs.issame(diff)
            @test !occursin(r"julia_f1", diff.before)  # LLVM module names should have been cleaned up

            diff = CodeDiffs.code_diff((f1, Tuple{}), (f2, Tuple{}); type=:native, color=false)
            @test !CodeDiffs.issame(diff)
            @test diff == (@code_diff type=:native color=false f1() f2())
        end

        @testset "AST" begin
            diff = CodeDiffs.code_diff((f1, Tuple{}), (f1, Tuple{}); type=:ast, color=false)
            @test CodeDiffs.issame(diff)

            diff = CodeDiffs.code_diff((f1, Tuple{}), (f2, Tuple{}); type=:ast, color=false)
            @test !CodeDiffs.issame(diff)
            @test diff == (@code_diff type=:ast color=false f1() f2())
        end
    end

    @testset "Changes" begin
        A = quote
            1 + 2
            f(a, b)
            g(c, d)
            "test"
        end

        B = quote
            println("B")
            1 + 3
            f(a, d)
            g(c, b)
            a = c + b
            c = b - d
            h(x, y)
            "test2"
        end

        diff = CodeDiffs.code_diff((A,), (B,); type=:ast, color=false)
        @test !CodeDiffs.issame(diff)
        @test length(DeepDiffs.added(diff)) == 8
        @test length(DeepDiffs.changed(diff)) == 4

        check_diff_display_order(diff, [
            "quote"    => "quote",
            nothing    => "println(\"B\")",
            "1 + 2"    => "1 + 3",
            "f(a, b)"  => "f(a, d)",
            "g(c, d)"  => "g(c, b)",
            nothing    => "a = c + b",
            nothing    => "c = b - d",
            nothing    => "h(x, y)",
            "\"test\"" => "\"test2\"",
            "end"      => "end"
        ])
    end

    @testset "Display" begin
        function test_cmp_display(f₁, args₁, f₂, args₂)
            @testset "Typed" begin
                diff = CodeDiffs.code_diff((f₁, args₁), (f₂, args₂); type=:typed, color=true)
                @test findfirst(CodeDiffs.ANSI_REGEX, diff.before) === nothing
                @test !endswith(diff.before, '\n') && !endswith(diff.after, '\n')
                println(TEST_IO, "\nTyped: $(nameof(f₁)) vs. $(nameof(f₂))")
                printstyled(TEST_IO, display_str(diff; columns=120))
                println(TEST_IO)
            end
 
            @testset "LLVM" begin
                diff = CodeDiffs.code_diff((f₁, args₁), (f₂, args₂); type=:llvm, color=true, debuginfo=:none)
                @test findfirst(CodeDiffs.ANSI_REGEX, diff.before) === nothing
                @test !endswith(diff.before, '\n') && !endswith(diff.after, '\n')
                @test rstrip(@io2str InteractiveUtils.print_llvm(IOContext(::IO, :color => true), diff.before)) == diff.highlighted_before
                println(TEST_IO, "\nLLVM: $(nameof(f₁)) vs. $(nameof(f₂))")
                printstyled(TEST_IO, display_str(diff; columns=120))
                println(TEST_IO)
            end

            @testset "Native" begin
                diff = CodeDiffs.code_diff((f₁, args₁), (f₂, args₂); type=:native, color=true, debuginfo=:none)
                @test findfirst(CodeDiffs.ANSI_REGEX, diff.before) === nothing
                @test !endswith(diff.before, '\n') && !endswith(diff.after, '\n')
                @test rstrip(@io2str InteractiveUtils.print_native(IOContext(::IO, :color => true), diff.before)) == diff.highlighted_before
                println(TEST_IO, "\nNative: $(nameof(f₁)) vs. $(nameof(f₂))")
                printstyled(TEST_IO, display_str(diff; columns=120))
                println(TEST_IO)
            end

            @testset "AST" begin
                diff = CodeDiffs.code_diff((f₁, args₁), (f₂, args₂); type=:ast, color=true)
                @test findfirst(CodeDiffs.ANSI_REGEX, diff.before) === nothing
                @test !endswith(diff.before, '\n') && !endswith(diff.after, '\n')
                println(TEST_IO, "\nAST: $(nameof(f₁)) vs. $(nameof(f₂))")
                printstyled(TEST_IO, display_str(diff; columns=120))
                println(TEST_IO)
            end

            @testset "Line numbers" begin
                diff = CodeDiffs.code_diff((f₁, args₁), (f₂, args₂); type=:typed, color=false)
                @test findfirst(CodeDiffs.ANSI_REGEX, diff.before) === nothing
                withenv("CODE_DIFFS_LINE_NUMBERS" => true) do
                    println(TEST_IO, "\nTyped + line numbers: $(nameof(f₁)) vs. $(nameof(f₂))")
                    printstyled(TEST_IO, display_str(diff; color=false, columns=120))
                    println(TEST_IO)
                end
            end
        end

        @testset "f1" begin
            eval_for_revise("""
            f() = 1
            """)
            test_cmp_display(f, Tuple{}, f, Tuple{})
        end

        @testset "saxpy" begin
            eval_for_revise("""
            function saxpy(r, a, x, y)
                for i in eachindex(r)
                    r[i] = a * x[i] + y[i]
                end
            end

            function saxpy_simd(r, a, x, y)
                @inbounds @simd ivdep for i in eachindex(r)
                    r[i] = a * x[i] + y[i]
                end
            end
            """)

            saxpy_args = Tuple{Vector{Int}, Int, Vector{Int}, Vector{Int}}
            test_cmp_display(saxpy, saxpy_args, saxpy_simd, saxpy_args)
        end

        @testset "AST" begin
            A = quote
                1 + 2
                f(a, b)
                g(c, d)
                "test"
            end

            B = quote
                println("B")
                1 + 3
                f(a, d)
                g(c, b)
                h(x, y)
                "test2"
            end

            diff = CodeDiffs.code_diff((A,), (B,); type=:ast, color=false)

            check_diff_display_order(diff, [
                "quote"    => "quote",
                nothing    => "println(\"B\")",
                "1 + 2"    => "1 + 3",
                "f(a, b)"  => "f(a, d)",
                "g(c, d)"  => "g(c, b)",
                nothing    => "h(x, y)",
                "\"test\"" => "\"test2\"",
                "end"      => "end"
            ])

            @test_reference "references/a_vs_b_PRINT.jl_ast" display_str(diff; mime=nothing, color=false)
            @test_reference "references/a_vs_b.jl_ast" display_str(diff; color=false, columns=120)

            withenv("CODE_DIFFS_LINE_NUMBERS" => true) do
                @test_reference "references/a_vs_b_LINES.jl_ast" display_str(diff; color=false, columns=120)
            end

            diff = CodeDiffs.code_diff((A,), (B,); type=:ast, color=true)
            @test_reference "references/a_vs_b_COLOR.jl_ast" display_str(diff; color=true, columns=120)

            # Single line code should not cause any issues with DeepDiffs.jl
            a = "1 + 2"
            b = "1 + 3"
            diff = CodeDiffs.code_diff(a, b, a, b)
            @test length(CodeDiffs.added(diff)) == length(CodeDiffs.removed(diff)) == 1
        end
    end

    @testset "LLVM module name" begin
        # julia_
        @test CodeDiffs.replace_llvm_module_name("julia_f_123") == "f"
        if Sys.islinux()
            @eval var"@f"() = 1
            @test occursin(r"julia_f_\d+", @io2str code_native(::IO, var"@f", Tuple{}))
            @test CodeDiffs.replace_llvm_module_name("julia_f_123", "@f") == "f"
        else
            @test CodeDiffs.replace_llvm_module_name("julia_@f_123", "@f") == "@f"
        end

        # jlcapi_
        get_cfunc_add() = @cfunction(+, Int, (Int, Int))
        @test occursin(r"jlcapi_\+_\d+", @io2str code_llvm(::IO, get_cfunc_add, Tuple{}))
        @test CodeDiffs.replace_llvm_module_name("jlcapi_+_123") == "+"

        # j_
        function test_append(a, b)
            v = Vector{typeof(b)}()
            push!(v, a, b) # 'j__append!' call
            return v
        end
        test_append_llvm_ir = @io2str code_llvm(::IO, test_append, Tuple{Int, Int})

        @static if VERSION ≥ v"1.11-"
            @test occursin(CodeDiffs.function_unique_gen_name_regex(), test_append_llvm_ir)
            @test occursin(CodeDiffs.function_unique_gen_name_regex("copyto!"), test_append_llvm_ir)
            @test occursin(r"j_copyto!_\d+", test_append_llvm_ir)
            @test CodeDiffs.replace_llvm_module_name("j_copyto!_123") == "copyto!"

            @test occursin(CodeDiffs.global_var_unique_gen_name_regex(), test_append_llvm_ir)
            @test occursin(CodeDiffs.global_var_unique_gen_name_regex("Core.GenericMemory"), test_append_llvm_ir)

            @test CodeDiffs.replace_llvm_module_name("@+Core.GenericMemory#123.jit") == "@+Core.GenericMemory.jit"
            @test CodeDiffs.replace_llvm_module_name(".L+Core.GenericMemory#123.jit") == ".L+Core.GenericMemory.jit"
        else
            @test occursin(CodeDiffs.function_unique_gen_name_regex(), test_append_llvm_ir)
            @test occursin(CodeDiffs.function_unique_gen_name_regex("_append!"), test_append_llvm_ir)
            @test occursin(r"j__append!_\d+", test_append_llvm_ir)
            @test CodeDiffs.replace_llvm_module_name("j__append!_123") == "_append!"
        end

        # I did not find easy ways to create a function test in those cases:
        @test CodeDiffs.replace_llvm_module_name("jfptr_f_123") == "f"
        @test CodeDiffs.replace_llvm_module_name("tojlinvoke123") == "tojlinvoke"
    end

    @testset "World age" begin
        @no_overwrite_warning begin
            file_name = eval_for_revise("f() = 1")
            world_1 = Base.get_world_counter()

            eval_for_revise("f() = 2", file_name, false)
            world_2 = Base.get_world_counter()
        end

        extra_1 = (; world=world_1)
        extra_2 = (; world=world_2)

        @testset "Typed" begin
            diff = CodeDiffs.code_diff((f, Tuple{}), (f, Tuple{}); type=:typed, color=false, debuginfo=:none, extra_1, extra_2=extra_1)
            @test CodeDiffs.issame(diff)

            diff = CodeDiffs.code_diff((f, Tuple{}), (f, Tuple{}); type=:typed, color=false, debuginfo=:none, extra_1, extra_2)
            @test !CodeDiffs.issame(diff)
            @test occursin("1", diff.before)
            @test occursin("2", diff.after)
            @test diff == (@code_diff type=:typed color=false debuginfo=:none world_1=world_1 world_2=world_2 f() f())
        end

        @testset "LLVM" begin
            diff = CodeDiffs.code_diff((f, Tuple{}), (f, Tuple{}); type=:llvm, color=false, debuginfo=:none, extra_1, extra_2=extra_1)
            @test CodeDiffs.issame(diff)

            diff = CodeDiffs.code_diff((f, Tuple{}), (f, Tuple{}); type=:llvm, color=false, debuginfo=:none, extra_1, extra_2)
            @test !CodeDiffs.issame(diff)
            @test occursin("1", diff.before)
            @test occursin("2", diff.after)
            @test diff == (@code_diff type=:llvm color=false debuginfo=:none world_1=world_1 world_2=world_2 f() f())
        end

        @testset "Native" begin
            diff = CodeDiffs.code_diff((f, Tuple{}), (f, Tuple{}); type=:native, color=false, debuginfo=:none, extra_1, extra_2=extra_1)
            @test CodeDiffs.issame(diff)

            diff = CodeDiffs.code_diff((f, Tuple{}), (f, Tuple{}); type=:native, color=false, debuginfo=:none, extra_1, extra_2)
            @test !CodeDiffs.issame(diff)
            @test diff == (@code_diff type=:native color=false debuginfo=:none world_1=world_1 world_2=world_2 f() f())
        end
    end

    @testset "Tabs" begin
        @testset "$t tab length" for t in (1, 4, 8)
            tab_replacement = ' '^t
            buf = IOBuffer()
            chars = 'a':'m'
            for i in eachindex(chars)
                raw_str = join((chars[1:i-1]..., '\t', chars[i:end]...))
                expected_str = join((chars[1:i-1]..., ' '^(t - mod(length(1:i-1), t)), chars[i:end]...))
                CodeDiffs.print_str_with_tabs(buf, raw_str, tab_replacement)
                str = String(take!(buf))
                @test str == expected_str
            end
        end

        # Lines with changes use another code path for tabs alignment
        a = "\tabc\t123\n\tabc\t456"
        b = "\tabc\t126\n\tabc\t456"
        diff = CodeDiffs.code_diff(a, b, a, b)
        diff_str = split(display_str(diff; color=false), '\n')
        @test startswith(diff_str[1], "    abc 1")
        @test startswith(diff_str[2], "    abc 4")
    end

    @testset "Macros" begin
        @testset "error" begin
            @test_throws MethodError @code_diff "f()" g()
            @test_throws MethodError @code_diff f() "g()"
            @test_throws MethodError @code_diff "f()" "g()"
            @test_throws UndefVarError @code_diff a b
            @test_throws "`key=value`, got: `a + 1`" @code_diff a+1 b c
            @test_throws "world age" @code_diff type=:ast world_1=1 f() f()

            @test_throws MethodError @code_for "f()"
            @test_throws UndefVarError @code_for a
            @test_throws "`key=value`, got: `a + 1`" @code_for a+1 b c
            @test_throws "world age" @code_for type=:ast world=1 f()
        end

        @testset "@code_for" begin
            io = IOBuffer()
            @test (@code_for io +(1, 2)) === nothing
            c1 = String(take!(io))
            @test !isempty(c1)
            c2 = @code_for io=String +(1, 2)
            @test endswith(c1, '\n')
            @test chomp(c1) == c2
        end

        @testset "Kwargs" begin
            @testset "type=$t" for t in (:native, :llvm, :typed)
                # `type` can be a variable
                d1 = @code_diff type=t +(1, 2) +(2, 3)
                c1 = @code_for io=String type=t +(1, 2)
                # if the variable has the same name as the option, no need to repeat it
                type = t
                d2 = @code_diff type +(1, 2) +(2, 3)
                c2 = @code_for io=String type +(1, 2)
                @test d1 == d2
                @test c1 == d1.highlighted_before == c2
            end
        end

        @testset "Special calls" begin
            # From 1.9 `@code_native` (& others) support dot calls
            @test !CodeDiffs.issame(@code_diff identity.(1:3) identity(1:3))
            @test !CodeDiffs.issame(@code_diff (x -> x + 1).(1:3) identity(1:3))

            sum_args(a, b; c=1, d=2) = a + b + c + d
            @test !CodeDiffs.issame(@code_diff sum_args(1, 2) sum_args(1, 2; c=3, d=4))

            # Apparently `@code_*` does not support broadcasts with kwargs. This should be
            # a common error with both mecros.
            expected_error = nothing
            try
                @code_native sum_args.(1:5, 2; c=4)
            catch e
                expected_error = e
            end

            actual_error = nothing
            try
                @code_diff sum_args.(1:5, 2; c=4) sum_args.(1:3, 2:5)
            catch e
                actual_error = e
            end
            @test typeof(expected_error) == typeof(actual_error) == MethodError
            @test expected_error.f == actual_error.f
        end

        @testset "AST" begin
            @test !CodeDiffs.issame(@code_diff :(1) :(2))
            @test !CodeDiffs.issame(@code_diff :(1+2) :(2+2))
            a = :(1+2)
            @test !CodeDiffs.issame(@code_diff :($a) :(2+2))

            @test (@code_for io=String :(1)) == (@code_for io=String :(1)) != (@code_for io=String :(2))
            @test (@code_for io=String :(1+2)) == (@code_for io=String :($a)) != (@code_for io=String :(2+2))
        end

        @testset "Extra" begin
            d1 = @code_diff extra_1=(; type=:native, debuginfo=:none) extra_2=(; type=:llvm, color=false) f() f()
            d2 = @code_diff type_1=:native debuginfo_1=:none type_2=:llvm color_2=false f() f()
            @test d1 == d2

            c1 = @code_for io=String extra=(; type=:native, debuginfo=:none) f()
            @test d1.highlighted_before == c1
        end
    end

    include("KernelAbstractions.jl")

    CUDA.functional() && include("CUDA.jl")
end
