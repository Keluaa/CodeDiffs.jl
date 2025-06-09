@testset "Stats" begin

import CodeDiffs.Stats as CDS


@testset "PTX" begin
    @testset "Sample 1" begin
        ptx_sample = readchomp("./samples/reverse_kernel.ptx")
        ptx_stats = CDS.extract_stats(Val(:ptx), ptx_sample)

        @test isempty(ptx_stats.defs.global)
        @test isempty(ptx_stats.defs.constant)
        @test ptx_stats.defs.param == Dict("b8" => 64 + 2*16)
        @test ptx_stats.defs.shared == Dict("b8" => 16)
        @test isempty(ptx_stats.defs.local)
        @test ptx_stats.defs.registers == Dict("b32" => 5 + 2, "b64" => 24, "pred" => 4)

        @test !ptx_stats.uses_dynamic_shared_mem

        @test ptx_stats.total.global   == 0
        @test ptx_stats.total.constant == 0
        @test ptx_stats.total.param    == 96
        @test ptx_stats.total.shared   == 16
        @test ptx_stats.total.local    == 0

        @test ptx_stats.inst.global.loads  == Dict("u64" => 1)
        @test ptx_stats.inst.global.stores == Dict("u64" => 1)
        @test all(isempty, ptx_stats.inst.constant)
        @test ptx_stats.inst.param.loads   == Dict("u64" => 4, "u32" => 1)
        @test ptx_stats.inst.param.stores  == Dict("b64" => 2, "b32" => 2)
        @test ptx_stats.inst.shared.loads  == Dict("u64" => 1)
        @test ptx_stats.inst.shared.stores == Dict("u64" => 1)
        @test all(isempty, ptx_stats.inst.local)

        disp_ptx_stats = display_str(ptx_stats)
        @test !occursin("u16", disp_ptx_stats)

        cleaned_ptx = CDC.cleanup_code(Val(:ptx), ptx_sample)
        cleaned_ptx_stats = CDS.extract_stats(Val(:ptx), cleaned_ptx)
        @test ptx_stats == cleaned_ptx_stats
    end

    # PTX types should be displayed in a consistant order
    @test CDS.cmp_ptx_type("u8", "u16")    && !CDS.cmp_ptx_type("u16", "u8")
    @test CDS.cmp_ptx_type("pred", "b8")   && !CDS.cmp_ptx_type("b8", "pred")
    @test !CDS.cmp_ptx_type("u128", "u64") && CDS.cmp_ptx_type("u64", "u128")
    @test !CDS.cmp_ptx_type("u8", "u8")
    @test !CDS.cmp_ptx_type("", "")
end


@testset "SASS" begin
    @testset "Sample 1" begin
        sass_sample = readchomp("./samples/extern_func_with_no_params.sass")
        sass_stats = CDS.extract_stats(Val(:sass), sass_sample)

        @test sass_stats.SM             == 86
        @test sass_stats.registers      == 38
        @test sass_stats.instructions   == 600
        @test sass_stats.workgroup_sync == 7
        @test sass_stats.warp_sync      == 0
        @test sass_stats.calls          == 12

        disp_sass_stats = display_str(sass_stats)

        cleaned_sass = CDC.cleanup_code(Val(:sass), sass_sample)
        cleaned_sass_stats = CDS.extract_stats(Val(:sass), cleaned_sass)
        @test sass_stats == cleaned_sass_stats
    end

    @testset "PTX & SASS" begin
        ptx_sample = readchomp("./samples/extern_func_with_no_params.ptx")
        sass_sample = readchomp("./samples/extern_func_with_no_params.sass")
        ptx_sass_stats = CDS.extract_stats(Val(:cuda_stats), (ptx_sample, sass_sample))

        ptx_stats  = CDS.extract_stats(Val(:ptx), ptx_sample)
        sass_stats = CDS.extract_stats(Val(:sass), sass_sample)
        @test ptx_sass_stats.ptx == ptx_stats && ptx_sass_stats.sass == sass_stats

        disp_ptx_stats = display_str(ptx_stats)
        disp_sass_stats = display_str(sass_stats)
        disp_ptx_sass_stats = display_str(ptx_sass_stats)
        @test occursin(disp_ptx_stats, disp_ptx_sass_stats)
        @test occursin(disp_sass_stats, disp_ptx_sass_stats)
    end
end

end
