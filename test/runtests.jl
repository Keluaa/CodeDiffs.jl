using Aqua
using CodeDiffs
using DeepDiffs
using InteractiveUtils
using ReferenceTests
using Test


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
        @test diff == (@code_diff color=false e :(1+2))

        # TODO: OhMyREPL highlighting
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
    end

    @testset "Display" begin
        function test_cmp_display(f₁, args₁, f₂, args₂)
            @testset "Typed" begin
                diff = CodeDiffs.compare_code_typed(f₁, args₁, f₂, args₂; color=true)
                @test findfirst(CodeDiffs.ANSI_REGEX, diff.before) === nothing
                printstyled(display_str(diff; columns=120))
                println()
            end

            @testset "LLVM" begin
                diff = CodeDiffs.compare_code_llvm(f₁, args₁, f₂, args₂; color=true, debuginfo=:none)
                @test findfirst(CodeDiffs.ANSI_REGEX, diff.before) === nothing
                @test (@io2str InteractiveUtils.print_llvm(IOContext(::IO, :color => true), diff.before)) == diff.highlighted_before
                printstyled(display_str(diff; columns=120))
                println()
            end

            @testset "Native" begin
                diff = CodeDiffs.compare_code_native(f₁, args₁, f₂, args₂; color=true, debuginfo=:none)
                @test findfirst(CodeDiffs.ANSI_REGEX, diff.before) === nothing
                @test (@io2str InteractiveUtils.print_native(IOContext(::IO, :color => true), diff.before)) == diff.highlighted_before
                printstyled(display_str(diff; columns=120))
                println()
            end

            @testset "Line numbers" begin
                diff = CodeDiffs.compare_code_typed(f₁, args₁, f₂, args₂; color=false)
                withenv("CODE_DIFFS_LINE_NUMBERS" => true) do
                    printstyled(display_str(diff; color=false, columns=120))
                    println()
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
            @test_reference "references/a_vs_b.jl_ast" display_str(diff; color=false, columns=120)

            withenv("CODE_DIFFS_LINE_NUMBERS" => true) do
                @test_reference "references/a_vs_b_LINES.jl_ast" display_str(diff; color=false, columns=120)
            end

            diff = CodeDiffs.compare_ast(A, B; color=true)
            @test_reference "references/a_vs_b_COLOR.jl_ast" display_str(diff; color=true, columns=120)
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
end
