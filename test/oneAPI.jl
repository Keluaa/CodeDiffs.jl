@testset "oneAPI.jl" begin


function test_one_code_type_diff(code_type, f₁, args₁, f₂, args₂; extra...)
    color = true
    unreliable_code = code_type in ()  # TODO?

    diff = @code_diff type=code_type color extra_1=extra extra_2=extra f₁(args₁...) f₁(args₁...)
    @test CodeDiffs.issame(diff) skip=unreliable_code

    diff = @code_diff type=code_type color extra_1=extra extra_2=extra f₁(args₁...) f₂(args₂...)
    @test !CodeDiffs.issame(diff)

    f₁_name = f₁ isa Function ? nameof(f₁) : :f₁
    f₂_name = f₂ isa Function ? nameof(f₂) : :f₂
    println(TEST_IO, "\n$code_type: $f₁_name vs. $f₂_name")
    printstyled(TEST_IO, display_str(diff; columns=120, color))
    println(TEST_IO)
end


function test_one_diff(f₁, args₁, f₂, args₂; extra_kw...)
    @testset "oneAPI Typed" begin
        test_one_code_type_diff(:one_typed, f₁, args₁, f₂, args₂; debuginfo=:none, extra_kw...)
    end

    @testset "oneAPI LLVM" begin
        test_one_code_type_diff(:one_llvm, f₁, args₁, f₂, args₂; debuginfo=:none, extra_kw...)
    end

    @testset "SPIRV" begin
        test_one_code_type_diff(:spirv, f₁, args₁, f₂, args₂; extra_kw...)
    end
end


@testset "Basics" begin
    N = 2^12
    x_d = oneAPI.rand(Float64, N)
    y_d = oneAPI.rand(Float64, N)

    function gpu_add!(y, x)
        index = get_global_id(0)
        stride = get_num_groups(0) * get_work_dim()
        for i = index:stride:length(y)
            @inbounds y[i] += x[i]
        end
        return
    end

    function gpu_sub!(y, x)
        index = get_global_id(0)
        stride = get_num_groups(0) * get_work_dim()
        for i = index:stride:length(y)
            @inbounds y[i] -= x[i]
        end
        return
    end

    test_one_diff(gpu_add!, (y_d, x_d), gpu_sub!, (y_d, x_d))

    @testset "error" begin
        @test_throws "ignores the `world` age" @code_diff type=:one_typed world_1=1 gpu_add!(y_d, x_d) gpu_add!(y_d, x_d)
    end
end


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
    r = oneAPI.zeros(Float64, N)
    x = oneAPI.rand(Float64, N)
    y = oneAPI.rand(Float64, N)
    a = rand(Float64)

    daxpy_k = daxpy(oneAPI.oneAPIBackend(), 1024, length(r))
    daxmy_k = daxmy(oneAPI.oneAPIBackend(), 1024, length(r))

    test_one_diff(daxpy_k, (r, a, x, y), daxmy_k, (r, a, x, y))
end

end
