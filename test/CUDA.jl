@testset "CUDA.jl" begin


function test_cuda_code_type_diff(code_type, f₁, args₁, f₂, args₂; extra...)
    color = !(code_type in (:cuda_native, :ptx))
    unreliable_code = code_type in (:cuda_native, :ptx, :sass)

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


function test_cuda_diff(f₁, args₁, f₂, args₂; extra_kw...)
    @testset "CUDA Typed" begin
        test_cuda_code_type_diff(:cuda_typed, f₁, args₁, f₂, args₂; debuginfo=:none, extra_kw...)
    end

    @testset "CUDA LLVM" begin
        test_cuda_code_type_diff(:cuda_llvm, f₁, args₁, f₂, args₂; debuginfo=:none, extra_kw...)
    end

    @testset "PTX" begin
        test_cuda_code_type_diff(:cuda_native, f₁, args₁, f₂, args₂; extra_kw...)
    end

    @testset "SASS" begin
        test_cuda_code_type_diff(:sass, f₁, args₁, f₂, args₂; extra_kw...)
    end
end


@testset "Basics" begin
    N = 2^12
    x_d = CUDA.rand(Float64, N)
    y_d = CUDA.rand(Float64, N)

    function gpu_add!(y, x)
        index = (blockIdx().x - 1) * blockDim().x + threadIdx().x
        stride = gridDim().x * blockDim().x
        for i = index:stride:length(y)
            @inbounds y[i] += x[i]
        end
        return
    end

    function gpu_sub!(y, x)
        index = (blockIdx().x - 1) * blockDim().x + threadIdx().x
        stride = gridDim().x * blockDim().x
        for i = index:stride:length(y)
            @inbounds y[i] -= x[i]
        end
        return
    end

    test_cuda_diff(gpu_add!, (y_d, x_d), gpu_sub!, (y_d, x_d))

    @testset "error" begin
        @test_throws "ignores the `world` age" @code_diff type=:cuda_typed world_1=1 gpu_add!(y_d, x_d) gpu_add!(y_d, x_d)
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
    r = CUDA.zeros(Float64, N)
    x = CUDA.rand(Float64, N)
    y = CUDA.rand(Float64, N)
    a = rand(Float64)

    daxpy_k = daxpy(CUDA.CUDABackend(), 1024, length(r))
    daxmy_k = daxmy(CUDA.CUDABackend(), 1024, length(r))

    test_cuda_diff(daxpy_k, (r, a, x, y), daxmy_k, (r, a, x, y))
end

end
