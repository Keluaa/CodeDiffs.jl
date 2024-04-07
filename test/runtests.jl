using Aqua
using CodeDiffs
using DeepDiffs
using InteractiveUtils
using ReferenceTests
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


# OhMyREPL is quite reluctant from loading its Markdown highlighting overload in a testing
# environment. See https://github.com/KristofferC/OhMyREPL.jl/blob/b0071f5ee785a81ca1e69a561586ff270b4dc2bb/src/OhMyREPL.jl#L106
prev = jl_options_overload(:isinteractive, Int8(1))
@no_overwrite_warning using OhMyREPL
jl_options_overload(:isinteractive, prev)


# Disable printing diffs to stdout by setting `ENV["TEST_PRINT_DIFFS"] = false`
const TEST_PRINT_DIFFS = parse(Bool, get(ENV, "TEST_PRINT_DIFFS", "true"))
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
            line_diff = diff.changed[idx][2]
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
        diff = CodeDiffs.compare_ast(:(1+2), :(1+2); color=false, prettify=false, lines=false, alias=false)
        @test CodeDiffs.issame(diff)
        @test diff.before == diff.highlighted_before == "quote\n    1 + 2\nend"

        diff = CodeDiffs.compare_ast(:(1+2), :(1+3); color=false, prettify=false, lines=false, alias=false)
        @test !CodeDiffs.issame(diff)
        @test length(DeepDiffs.added(diff)) == length(DeepDiffs.removed(diff)) == 1

        e = quote
            $(LineNumberNode(42, :file))
            1+2
        end
        diff = CodeDiffs.compare_ast(e, :(1+2); color=false, prettify=false, lines=true, alias=false)
        @test !CodeDiffs.issame(diff)
        @test occursin("#= file:42 =#", diff.before)
        diff = CodeDiffs.compare_ast(e, :(1+2); color=false, prettify=true, lines=false, alias=false)
        @test CodeDiffs.issame(diff)
        @test diff == (@code_diff type=:ast color=false e :(1+2))
    end

    @testset "Basic function" begin
        f1() = 1
        f2() = 2

        @testset "Typed" begin
            diff = CodeDiffs.compare_code_typed(f1, Tuple{}, f1, Tuple{}; color=false)
            @test CodeDiffs.issame(diff)
    
            diff = CodeDiffs.compare_code_typed(f1, Tuple{}, f2, Tuple{}; color=false)
            @test !CodeDiffs.issame(diff)
            @test length(DeepDiffs.added(diff)) == length(DeepDiffs.removed(diff)) == 1
            @test diff == (@code_diff type=:typed color=false f1() f2())
        end

        @testset "LLVM" begin
            diff = CodeDiffs.compare_code_llvm(f1, Tuple{}, f1, Tuple{}; color=false)
            @test CodeDiffs.issame(diff)
            @test !occursin(r"julia_f1", diff.before)  # LLVM module names should have been cleaned up
    
            diff = CodeDiffs.compare_code_llvm(f1, Tuple{}, f2, Tuple{}; color=false)
            @test !CodeDiffs.issame(diff)
            @test diff == (@code_diff type=:llvm color=false f1() f2())
        end

        @testset "Native" begin
            diff = CodeDiffs.compare_code_native(f1, Tuple{}, f1, Tuple{}; color=false)
            @test CodeDiffs.issame(diff)
            @test !occursin(r"julia_f1", diff.before)  # LLVM module names should have been cleaned up

            diff = CodeDiffs.compare_code_native(f1, Tuple{}, f2, Tuple{}; color=false)
            @test !CodeDiffs.issame(diff)
            @test diff == (@code_diff type=:native color=false f1() f2())
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

        diff = CodeDiffs.compare_ast(A, B; color=false)
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
                diff = CodeDiffs.compare_code_typed(f₁, args₁, f₂, args₂; color=true)
                @test findfirst(CodeDiffs.ANSI_REGEX, diff.before) === nothing
                @test !endswith(diff.before, '\n') && !endswith(diff.after, '\n')
                println(TEST_IO, "\nTyped: $(nameof(f₁)) vs. $(nameof(f₂))")
                printstyled(TEST_IO, display_str(diff; columns=120))
                println(TEST_IO)
            end

            @testset "LLVM" begin
                diff = CodeDiffs.compare_code_llvm(f₁, args₁, f₂, args₂; color=true, debuginfo=:none)
                @test findfirst(CodeDiffs.ANSI_REGEX, diff.before) === nothing
                @test !endswith(diff.before, '\n') && !endswith(diff.after, '\n')
                @test rstrip(@io2str InteractiveUtils.print_llvm(IOContext(::IO, :color => true), diff.before)) == diff.highlighted_before
                println(TEST_IO, "\nLLVM: $(nameof(f₁)) vs. $(nameof(f₂))")
                printstyled(TEST_IO, display_str(diff; columns=120))
                println(TEST_IO)
            end

            @testset "Native" begin
                diff = CodeDiffs.compare_code_native(f₁, args₁, f₂, args₂; color=true, debuginfo=:none)
                @test findfirst(CodeDiffs.ANSI_REGEX, diff.before) === nothing
                @test !endswith(diff.before, '\n') && !endswith(diff.after, '\n')
                @test rstrip(@io2str InteractiveUtils.print_native(IOContext(::IO, :color => true), diff.before)) == diff.highlighted_before
                println(TEST_IO, "\nNative: $(nameof(f₁)) vs. $(nameof(f₂))")
                printstyled(TEST_IO, display_str(diff; columns=120))
                println(TEST_IO)
            end

            @testset "Line numbers" begin
                diff = CodeDiffs.compare_code_typed(f₁, args₁, f₂, args₂; color=false)
                @test findfirst(CodeDiffs.ANSI_REGEX, diff.before) === nothing
                withenv("CODE_DIFFS_LINE_NUMBERS" => true) do
                    println(TEST_IO, "\nTyped + line numbers: $(nameof(f₁)) vs. $(nameof(f₂))")
                    printstyled(TEST_IO, display_str(diff; color=false, columns=120))
                    println(TEST_IO)
                end
            end
        end

        @testset "f1" begin
            f() = 1
            test_cmp_display(f, Tuple{}, f, Tuple{})
        end

        @testset "saxpy" begin
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

            diff = CodeDiffs.compare_ast(A, B; color=false)

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

            diff = CodeDiffs.compare_ast(A, B; color=true)
            @test_reference "references/a_vs_b_COLOR.jl_ast" display_str(diff; color=true, columns=120)

            # Single line code should not cause any issues with DeepDiffs.jl
            diff = CodeDiffs.code_diff(Val(:ast), "1 + 2", "1 + 3"; color=false)
            @test length(CodeDiffs.added(diff)) == length(CodeDiffs.removed(diff)) == 1
        end
    end

    @testset "LLVM module name" begin
        @test CodeDiffs.replace_llvm_module_name("julia_f_1") == "f"
        if Sys.islinux()
            @eval var"@f"() = 1
            @test occursin(r"julia_f_\d+", @io2str code_native(::IO, var"@f", Tuple{}))
            @test CodeDiffs.replace_llvm_module_name("julia_f_1", "@f") == "f"
        else
            @test CodeDiffs.replace_llvm_module_name("julia_@f_1", "@f") == "@f"
        end
    end

    @testset "World age" begin
        @no_overwrite_warning @eval begin
            f() = 1
            w₁ = Base.get_world_counter()
            f() = 2
            w₂ = Base.get_world_counter()
        end

        @testset "Typed" begin
            diff = CodeDiffs.compare_code_typed(f, Tuple{}, w₁, w₁; color=false, debuginfo=:none)
            @test CodeDiffs.issame(diff)

            diff = CodeDiffs.compare_code_typed(f, Tuple{}, w₁, w₂; color=false, debuginfo=:none)
            @test !CodeDiffs.issame(diff)
            @test occursin("1", diff.before)
            @test occursin("2", diff.after)
        end

        @testset "LLVM" begin
            diff = CodeDiffs.compare_code_llvm(f, Tuple{}, w₁, w₁; color=false, debuginfo=:none)
            @test CodeDiffs.issame(diff)

            diff = CodeDiffs.compare_code_llvm(f, Tuple{}, w₁, w₂; color=false, debuginfo=:none)
            @test !CodeDiffs.issame(diff)
            @test occursin("1", diff.before)
            @test occursin("2", diff.after)
        end

        @testset "Native" begin
            diff = CodeDiffs.compare_code_native(f, Tuple{}, w₁, w₁; color=false, debuginfo=:none)
            @test CodeDiffs.issame(diff)

            diff = CodeDiffs.compare_code_native(f, Tuple{}, w₁, w₂; color=false, debuginfo=:none)
            @test !CodeDiffs.issame(diff)
        end
    end
end
