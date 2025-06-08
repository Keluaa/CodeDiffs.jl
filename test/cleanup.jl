@testset "Cleanup" begin

import CodeDiffs.Cleanup as CDC

is_removed(needle, present_there, not_there) =
        occursin(needle, present_there) && !occursin(needle, not_there)

has_trailing_spaces(str) = occursin(r"\h+(\R|$)"m, str)


@testset "Demangling" begin
    @test CDC.demangle("test") == "test"
    @test CDC.demangle("_Z1fv") == "f()"
    @test CDC.demangle("_Z1fiPv") == "f(int, void*)"
    @test CDC.demangle("_Z1f3ValILi1EE4TypeI5Int64ES2_") == "f(Val<1>, Type<Int64>, Int64)"

    @test CDC.mangled_base_name("test") === nothing
    @test CDC.mangled_base_name("_Ztest") === nothing
    @test CDC.mangled_base_name("_Z1f3ValILi1EE4TypeI5Int64ES2_") == "f"

    text_with_no_mangled_name = """
    This is a function prototype: f()
    The prototype `f(int, void*)` is a bit more complex.
    And with type parameters it is a mess, like for `f(Val<1>, Type<Int64>, Int64)`.
    The string "_Z1fipv" is not a mangled name, but it looks like one.
    """

    text_with_mangled_names = """
    This is a function prototype: _Z1fv
    The prototype `_Z1fiPv` is a bit more complex.
    And with type parameters it is a mess, like for `_Z1f3ValILi1EE4TypeI5Int64ES2_`.
    The string "_Z1fipv" is not a mangled name, but it looks like one.
    """

    @test CDC.demangle_all(text_with_no_mangled_name) == text_with_no_mangled_name
    @test CDC.demangle_all(text_with_mangled_names) == text_with_no_mangled_name

    llvm_ir_function = "define void @_Z1fv({ {}*, i64, i64 }* %0, [1 x {}*]* %1, {}* %2) #0 { }"
    m = match(CDC.LLVM_IR_FUNC_NAME_MANGLED_REGEX, llvm_ir_function)
    @test !isnothing(m)
    @test m[1] == "_Z1fv"
end


@testset "Julia names" begin
    # julia_
    @test CDC.replace_llvm_module_name("julia_f_123") == "f"
    if Sys.islinux()
        @eval var"@f"() = 1
        @test occursin(r"julia_f_\d+", @io2str code_native(::IO, var"@f", Tuple{}))
        @test CDC.replace_llvm_module_name("julia_f_123", "@f") == "f"
    else
        @test CDC.replace_llvm_module_name("julia_@f_123", "@f") == "@f"
    end

    # jlcapi_
    get_cfunc_add() = @cfunction(+, Int, (Int, Int))
    @test occursin(r"jlcapi_\+_\d+", @io2str code_llvm(::IO, get_cfunc_add, Tuple{}))
    @test CDC.replace_llvm_module_name("jlcapi_+_123") == "+"

    # j_
    function test_append(a, b)
        v = Vector{typeof(b)}()
        push!(v, a, b) # 'j__append!' call
        return v
    end
    test_append_llvm_ir = @io2str code_llvm(::IO, test_append, Tuple{Int, Int})

    @static if VERSION ≥ v"1.11-"
        @test occursin(CDC.function_unique_gen_name_regex(), test_append_llvm_ir)
        @test occursin(CDC.function_unique_gen_name_regex("copyto!"), test_append_llvm_ir)
        @test occursin(r"j_copyto!_\d+", test_append_llvm_ir)
        @test CDC.replace_llvm_module_name("j_copyto!_123") == "copyto!"

        @test occursin(CDC.global_var_unique_gen_name_regex(), test_append_llvm_ir)
        @test occursin(CDC.global_var_unique_gen_name_regex("Core.GenericMemory"), test_append_llvm_ir)

        @test CDC.replace_llvm_module_name("@+Core.GenericMemory#123.jit") == "@+Core.GenericMemory.jit"
        @test CDC.replace_llvm_module_name(".L+Core.GenericMemory#123.jit") == ".L+Core.GenericMemory.jit"
    else
        @test occursin(CDC.function_unique_gen_name_regex(), test_append_llvm_ir)
        @test occursin(CDC.function_unique_gen_name_regex("_append!"), test_append_llvm_ir)
        @test occursin(r"j__append!_\d+", test_append_llvm_ir)
        @test CDC.replace_llvm_module_name("j__append!_123") == "_append!"
    end

    # I did not find easy ways to create a function for those cases:
    @test CDC.replace_llvm_module_name("jfptr_f_123") == "f"
    @test CDC.replace_llvm_module_name("tojlinvoke123") == "tojlinvoke"
end


@testset "Typed IR" begin
    @testset "Inline LLVM-IR" begin
        tuple_gref = GlobalRef(Core, :tuple)
        llvmcall_gref = GlobalRef(Base, :llvmcall)
        # Inline LLVM-IR in typed Julia IR is detected by a `llvmcall` function, whose first argument
        # being the index at which the LLVM IR source is at.
        ir_list = Any[
            :($tuple_gref("; ModuleID = 'llvmcall'\ndefine void @entry() #0 {\nentry:\n    ret void\n}", "entry")),
            :($llvmcall_gref($(Core.SSAValue(1)))),  # invalid `Base.llvmcall` but we don't care here

            :($tuple_gref("""
            define void @entry() #0 {
            entry:
                ret void
            }
            """, "entry")),
            :(Base.llvmcall($(Core.SSAValue(3)))),

            :(Core.tuple("""; ModuleID = 'llvmcall'
            define void @entry() #0 {
            entry:
                ret void
            }
            """, "entry")),
            :($llvmcall_gref($(Core.SSAValue(5)))),

            :($tuple_gref("""; ModuleID = 'llvmcall'
            oops, no function defined here!
            """, "entry")),
            :($llvmcall_gref($(Core.SSAValue(7)))),

            :($tuple_gref("this is not a LLVM module", "entry")),
            :($llvmcall_gref($(Core.SSAValue(9)))),

            # Complex real-world example with multiple nested '{}'
            # Replicate similar code by accessing an array of tuples (or structs) in a GPU kernel
            :($tuple_gref("""
            ; ModuleID = 'llvmcall'
            source_filename = "llvmcall"

            ; Function Attrs: alwaysinline
            define void @entry(i8 addrspace(1)* %0, { i64, i64, [2 x i64] } %1, i64 %2) #0 {
            entry:
                %3 = bitcast i8 addrspace(1)* %0 to { i64, i64, [2 x i64] } addrspace(1)*
                %4 = getelementptr inbounds { i64, i64, [2 x i64] }, { i64, i64, [2 x i64] } addrspace(1)* %3, i64 %2
                store { i64, i64, [2 x i64] } %1, { i64, i64, [2 x i64] } addrspace(1)* %4, align 8, !tbaa !0
                ret void
            }

            attributes #0 = { alwaysinline }

            !0 = !{!1, !1, i64 0, i64 0}
            !1 = !{!"custom_tbaa_addrspace(1)", !2, i64 0}
            !2 = !{!"custom_tbaa"}
            """, "entry")),
            :(Base.llvmcall($(Core.SSAValue(11)))),
        ]

        @test CDC.cleanup_inline_llvmcall_modules(ir_list) === nothing
        @test ir_list[1] isa CDC.LLVMCallBodyDef
        @test !occursin("\\n", ir_list[1].code)
        @test ir_list[1].entry == "entry"
        @test ir_list[1] == ir_list[3] == ir_list[5]
        @test count(x -> isa(x, CDC.LLVMCallBodyDef), ir_list) == count(CDC.is_llvmcall, ir_list) - 2
        @test all(typeof.(ir_list[7:10]) .== Expr)  # unmatched llvmcalls are unchanged

        @test ir_list[11] isa CDC.LLVMCallBodyDef
        @test occursin("void @entry", ir_list[11].code) && occursin("ret void", ir_list[11].code)  # the whole body should be extracted
        @test !occursin("alwaysinline", ir_list[11].code)  # leading and trailing attributes should be excluded
    end
end


@testset "LLVM IR" begin
    # TODO
end


@testset "Native Assembly" begin
    # TODO
end


@testset "PTX" begin
    @testset "Sample 1" begin
        ptx_sample = readchomp("./samples/reverse_kernel.ptx")
        cleaned_ptx = CDC.cleanup_code(Val(:ptx), ptx_sample)

        println(TEST_IO, "\nCleaned PTX sample 1:")
        println(TEST_IO, cleaned_ptx)

        # Comments removal
        @test is_removed("// Generated by LLVM NVPTX Back-End", ptx_sample, cleaned_ptx)
        @test is_removed("// callseq", ptx_sample, cleaned_ptx)
        @test is_removed("// begin inline asm", ptx_sample, cleaned_ptx)
        @test is_removed("// -- Begin function", ptx_sample, cleaned_ptx)
        @test is_removed("// -- End function", ptx_sample, cleaned_ptx)
        @test is_removed(r"// %L\d+", ptx_sample, cleaned_ptx)

        # Demangling
        @test is_removed("14gpu_reverse_ka", ptx_sample, cleaned_ptx)
        @test occursin(r"\bgpu_reverse_ka\b", cleaned_ptx)

        # Removal of all LLVM module numbers for external functions
        @test is_removed(r"throw_boundserror_\d+", ptx_sample, cleaned_ptx)

        # Re-indentation of predicate guards
        @test is_removed(r"\t@%", ptx_sample, cleaned_ptx)

        # Reformat function calls
        @test is_removed(r"call.+?,\R", ptx_sample, cleaned_ptx)

        # Others
        @test !has_trailling_spaces(cleaned_ptx)
        @test count(r"\R{2,}", cleaned_ptx) == 0  # no empty lines

        # Make sure we didn't remove any instruction by mistake
        @test count(';', ptx_sample) == count(';', cleaned_ptx)
    end

    @testset "Sample 2" begin
        # This sample is from a function compiled to PTX with `kernel=false`
        ptx_sample = readchomp("./samples/arithmetic_func.ptx")
        cleaned_ptx = CDC.cleanup_code(Val(:ptx), ptx_sample)
        func_name = "tid_to_blk_index_warp_aware_thread_side"

        println(TEST_IO, "\nCleaned PTX sample 2:")
        println(TEST_IO, cleaned_ptx)

        # Proper cleanup of each parameter name
        @test count(func_name * r"\d+_param_\d+\b", ptx_sample) == 3
        @test count(func_name * r"_param_\d+\b", cleaned_ptx) == 3

        # Make sure we didn't remove any instruction by mistake
        @test count(';', ptx_sample) == count(';', cleaned_ptx)
    end


    # TODO: calls with 0 parameters are not reformatted correctly
end


@testset "SASS" begin
    # TODO
end


@testset "GCN" begin
    @testset "Sample 1" begin
        gcn_sample = readchomp("./samples/loop_kernel.gcn")
        cleaned_gcn = CDC.cleanup_code(Val(:gcn), gcn_sample)

        println(TEST_IO, "\nCleaned GCN sample 1:")
        println(TEST_IO, cleaned_gcn)

        # No more ultra long mangled names
        @test is_removed(CDC.MANGLED_NAME_REGEX, gcn_sample, cleaned_gcn)

        # All metadata is removed by default
        @test is_removed(r".ident\s\"clang version", gcn_sample, cleaned_gcn)
        @test is_removed(".amdhsa_kernel", gcn_sample, cleaned_gcn)
        @test is_removed(".AMDGPU.csdata", gcn_sample, cleaned_gcn)
        @test is_removed(".amdgpu_metadata", gcn_sample, cleaned_gcn)

        # Code-gen comments are all removed
        @test is_removed(r"; %L\d+", gcn_sample, cleaned_gcn)
        @test is_removed(r"; %bb\.\d+:", gcn_sample, cleaned_gcn)
        @test is_removed("divergent unreachable", gcn_sample, cleaned_gcn)
        @test is_removed("; -- Begin function", gcn_sample, cleaned_gcn)
        @test is_removed("; -- End function", gcn_sample, cleaned_gcn)
    end
end


# TODO
@testset "AGX" begin end
@testset "SPIRV" begin end

end
