using Aqua
using CodeDiffs
using DeepDiffs
using InteractiveUtils
using ReferenceTests
using Test


if Base.JLOptions().code_coverage == 0
    # This is because code coverage adds instructions in Julia IR, and for references to
    # be correct and compared with, code coverage must be always enabled.
    error("tests must be done with code coverage enabled")
end


# Code in references might change depending on the Julia version.
# Versions introducing significant changes in Julia IR should have their entry here.
const REFERENCES_VERSION = if v"1.6-" ≤ VERSION < v"1.7"
    "v1.6"
elseif v"1.10-" ≤ VERSION
    "v1.10"
else
    error("no references for this version")
end


const REFERENCES_DIR = joinpath("references", REFERENCES_VERSION)


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
            1 + 3
            f(a, d)
            g(c, b)
            "test2"
        end

        diff = CodeDiffs.compare_ast(A, B; color=false)
        @test !CodeDiffs.issame(diff)
        # All statements were marked as changed
        @test length(DeepDiffs.added(diff)) == length(DeepDiffs.changed(diff)) == 4
    end

    @testset "Display" begin
        function test_cmp_display(cmp_name, f₁, args₁, f₂, args₂)
            @testset "Typed" begin
                diff = CodeDiffs.compare_code_typed(f₁, args₁, f₂, args₂; color=false)
                @test_reference(
                    "$REFERENCES_DIR/$(cmp_name).jl_typed",
                    display_str(diff; color=false, columns=120)
                )

                diff = CodeDiffs.compare_code_typed(f₁, args₁, f₂, args₂; color=true)
                @test findfirst(CodeDiffs.ANSI_REGEX, diff.before) === nothing
                @test_reference(
                    "$REFERENCES_DIR/$(cmp_name)_COLOR.jl_typed",
                    display_str(diff; columns=120)
                )
            end

            @testset "LLVM" begin
                diff = CodeDiffs.compare_code_llvm(f₁, args₁, f₂, args₂; color=true, debuginfo=:none)
                @test findfirst(CodeDiffs.ANSI_REGEX, diff.before) === nothing
                @test (@io2str InteractiveUtils.print_llvm(IOContext(::IO, :color => true), diff.before)) == diff.highlighted_before
                printstyled(display_str(diff; columns=120))  # output not portable therefore no reference
                println()
            end

            @testset "Native" begin
                diff = CodeDiffs.compare_code_native(f₁, args₁, f₂, args₂; color=true, debuginfo=:none)
                @test findfirst(CodeDiffs.ANSI_REGEX, diff.before) === nothing
                @test (@io2str InteractiveUtils.print_native(IOContext(::IO, :color => true), diff.before)) == diff.highlighted_before
                printstyled(display_str(diff; columns=120))  # output not portable therefore no reference
                println()
            end

            @testset "Line numbers" begin
                diff = CodeDiffs.compare_code_typed(f₁, args₁, f₂, args₂; color=false)
                withenv("CODE_DIFFS_LINE_NUMBERS" => true) do
                    @test_reference(
                        "$REFERENCES_DIR/$(cmp_name)_LINES.jl_typed",
                        display_str(diff; color=false, columns=120)
                    )
                end
            end
        end

        @testset "f1" begin
            f() = 1
            test_cmp_display("f1", f, Tuple{}, f, Tuple{})
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
            test_cmp_display("saxpy", saxpy, saxpy_args, saxpy_simd, saxpy_args)
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
