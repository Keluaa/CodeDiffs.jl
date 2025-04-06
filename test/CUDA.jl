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


@testset "LLVM call cleanup" begin
    @kernel function test_ka(a, b, c)
        i = @index(Global, Linear)
        s = @localmem eltype(a) 100
        l = @private eltype(a) 3
        s[i] = a[i]
        @synchronize()
        l[1] = mod1(i * 42, 100)
        l[2] = mod1(i * 46, 100)
        l[3] = mod1(abs(Int(c[i])) * 465, 100)
        a[i] = b[i] * c[i] - s[mod1(i + 42, 100)]
        b[i] = c[i] - a[i] + s[mod1(i + 27, 100)]
        c[i] = b[i] * a[i] * s[mod1(i + 37, 100)]
    end

    a = CUDA.rand(Int64, 100)
    b = CUDA.rand(Int64, 100)
    c = CUDA.rand(Int64, 100)

    test_ka_k = test_ka(CUDA.CUDABackend(), 100, size(a))

    ci = CodeDiffs.get_code(Val(:cuda_typed), test_ka_k, Base.typesof(a, b, c); debuginfo=:none)
    @test ci isa Pair{Core.CodeInfo, DataType}
    @test count(CodeDiffs.is_llvmcall, first(ci).code) > 0

    ir_no_color = @code_for io=String type=:cuda_typed dbinfo=false color=false test_ka_k(a, b, c)
    ir_color    = @code_for io=String type=:cuda_typed dbinfo=false color=true  test_ka_k(a, b, c)

    @test occursin("; stripped llvmcall body", ir_no_color)
    @test occursin("; stripped llvmcall body", ir_color)
    @test !occursin("; ModuleID = 'llvmcall'", ir_no_color)
    @test !occursin("; ModuleID = 'llvmcall'", ir_color)
    @test count("; stripped llvmcall body", ir_no_color) == count("Base.llvmcall", ir_no_color)
end

end
