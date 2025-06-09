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


@testset "GCN" begin
    @testset "Sample 1" begin
        gcn_sample = readchomp("./samples/loop_kernel.gcn")
        gcn_stats = CDS.extract_stats(Val(:gcn), gcn_sample)

        @test gcn_stats.scalar_registers == 26
        @test gcn_stats.vector_registers == 18
        @test gcn_stats.accu_registers   == 0
        @test gcn_stats.sgpr_spill_count == 0
        @test gcn_stats.vgpr_spill_count == 0
        @test !gcn_stats.uses_dyn_stack

        @test gcn_stats.arguments_count == 12
        @test gcn_stats.arguments_size  == 304

        @test gcn_stats.target_triple  == "amdgcn-amd-amdhsa"
        @test gcn_stats.ISA            == "gfx90a"
        @test gcn_stats.architecture   == "CDNA"
        @test gcn_stats.arch_version   == v"2"
        @test gcn_stats.wavefront_size == 64

        @test gcn_stats.inst_count        == 325
        @test gcn_stats.scalar_inst_count == 101
        @test gcn_stats.vector_inst_count == 202
        @test gcn_stats.dyn_branch_count  == 0
        @test gcn_stats.barrier_count     == 2
        @test gcn_stats.sync_count        == 8

        # Since we remove the metadata when cleaning the GCN source, almost all stats
        # become unavailable.
        cleaned_gcn = CDC.cleanup_code(Val(:gcn), gcn_sample)
        cleaned_gcn_stats = CDS.extract_stats(Val(:gcn), cleaned_gcn)
        @test cleaned_gcn_stats.scalar_registers == 0
        @test cleaned_gcn_stats.inst_count == gcn_stats.inst_count
        @test gcn_stats != cleaned_gcn_stats
    end
end

end
