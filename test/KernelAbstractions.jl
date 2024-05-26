@testset "KernelAbstractions.jl" begin

@kernel function daxpy(r, a, x, y)
    i = @index(Global, Linear)
    r[i] = a * x[i] + y[i]
end

@kernel function daxmy(r, a, x, y)
    i = @index(Global, Linear)
    r[i] = a * x[i] - y[i]
end

N = 10000
r = zeros(Float64, N)
x = rand(Float64, N)
y = rand(Float64, N)
a = rand(Float64)

daxpy_k = daxpy(CPU(), 1024)
daxmy_k = daxmy(CPU(), 1024)


@testset "Typed" begin
    diff = @code_diff type=:typed daxpy_k(r, a, x, y; ndrange=length(r)) daxpy_k(r, a, x, y; ndrange=length(r))
    @test CodeDiffs.issame(diff)
    @test occursin("Base.add_float", diff.before)

    diff = @code_diff type=:typed daxpy_k(r, a, x, y; ndrange=length(r)) daxmy_k(r, a, x, y; ndrange=length(r))
    @test !CodeDiffs.issame(diff)
    @test occursin("Base.add_float", diff.before) && !occursin("Base.sub_float", diff.before)
    @test occursin("Base.sub_float", diff.after)  && !occursin("Base.add_float", diff.after)

    println(TEST_IO, "\nKA Typed: daxpy vs. daxmy")
    printstyled(TEST_IO, display_str(diff; columns=120))
    println(TEST_IO)
end

@testset "LLVM" begin
    diff = @code_diff type=:llvm daxpy_k(r, a, x, y; ndrange=length(r)) daxpy_k(r, a, x, y; ndrange=length(r))
    @test CodeDiffs.issame(diff)

    diff = @code_diff type=:llvm daxpy_k(r, a, x, y; ndrange=length(r)) daxmy_k(r, a, x, y; ndrange=length(r))
    @test !CodeDiffs.issame(diff)

    println(TEST_IO, "\nKA LLVM: daxpy vs. daxmy")
    printstyled(TEST_IO, display_str(diff; columns=120))
    println(TEST_IO)
end

@testset "Native" begin
    diff = @code_diff type=:native daxpy_k(r, a, x, y; ndrange=length(r)) daxpy_k(r, a, x, y; ndrange=length(r))
    @test CodeDiffs.issame(diff)

    diff = @code_diff type=:native daxpy_k(r, a, x, y; ndrange=length(r)) daxmy_k(r, a, x, y; ndrange=length(r))
    println(TEST_IO, "\nKA Native: daxpy vs. daxmy")
    printstyled(TEST_IO, display_str(diff; columns=120))
    println(TEST_IO)
end


@testset "Kernel parameters" begin
    @test CodeDiffs.issame(@code_diff(type=:typed,
        daxpy(CPU(), 1024)(r, a, x, y; ndrange=length(r)),
        daxpy_k(r, a, x, y; ndrange=length(r))
    ))

    @test !CodeDiffs.issame(@code_diff(type=:typed,
        daxpy(CPU(), 1024, length(r))(r, a, x, y),
        daxpy_k(r, a, x, y; ndrange=length(r))
    ))

    @test_throws("Can not partition kernel!",
        @code_diff type=:typed daxpy_k(r, a, x, y) daxmy_k(r, a, x, y)
    )
end


@testset "World age" begin
    @no_overwrite_warning begin
        eval(:(@kernel function k_test(r, a)
            i = @index(Global, Linear)
            r[i] = 2*a
        end))
        w1 = Base.get_world_counter()
        
        eval(:(@kernel function k_test(r, a)
            i = @index(Global, Linear)
            r[i] = 3*a
        end))
        w2 = Base.get_world_counter()
    end

    k_test_k = k_test(CPU(), 128, N)

    @testset "Typed" begin
        @test CodeDiffs.issame(@code_diff type=:typed world_1=w1 world_2=w1 k_test_k(r, a) k_test_k(r, a))
        
        diff = @code_diff type=:typed world_1=w1 world_2=w2 k_test_k(r, a) k_test_k(r, a)
        @test !CodeDiffs.issame(diff)
        @test occursin("2", diff.before)
        @test occursin("3", diff.after)
    end

    @testset "LLVM" begin
        @test CodeDiffs.issame(@code_diff type=:llvm world_1=w1 world_2=w1 k_test_k(r, a) k_test_k(r, a))

        diff = @code_diff type=:typed world_1=w1 world_2=w2 k_test_k(r, a) k_test_k(r, a)
        @test !CodeDiffs.issame(diff)
        @test occursin("2", diff.before)
        @test occursin("3", diff.after)
    end

    @testset "Native" begin
        @test CodeDiffs.issame(@code_diff type=:native world_1=w1 world_2=w1 k_test_k(r, a) k_test_k(r, a))

        diff = @code_diff type=:typed world_1=w1 world_2=w2 k_test_k(r, a) k_test_k(r, a)
        @test !CodeDiffs.issame(diff)
    end
end


@testset "Errors" begin
    # no ast from KA kernels: Revise cannot track it properly as they are generated from macros
    @test_logs (:warn, r"was not found") @test_throws("could not retrieve the AST",
        @code_diff type=:ast daxpy_k(r, a, x, y; ndrange=length(r)) daxmy_k(r, a, x, y; ndrange=length(r))
    )
end

end
