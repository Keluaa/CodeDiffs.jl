using CodeDifferences
using Test
using Aqua

@testset "CodeDifferences.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(CodeDifferences)
    end
    # Write your tests here.
end
