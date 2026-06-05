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
    if VERSION < v"1.12-"
        @test occursin(r"jlcapi_\+_\d+", @io2str code_llvm(::IO, get_cfunc_add, Tuple{}))
        @test CDC.replace_llvm_module_name("jlcapi_+_123") == "+"
    else
        # TODO: they changed how operator names work in 1.12? I don't know if this is fine or not...
        @test occursin(r"jlcapi_#\+_\d+", @io2str code_llvm(::IO, get_cfunc_add, Tuple{}))
        @test CDC.replace_llvm_module_name("jlcapi_#+_123") == "#+"
    end

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

        if VERSION ≥ v"1.12-"
            @test occursin(CDC.global_var_unique_gen_name_regex("global"), test_append_llvm_ir)
        else
            @test occursin(CDC.global_var_unique_gen_name_regex("Core.GenericMemory"), test_append_llvm_ir)
        end

        @test CDC.replace_llvm_module_name("@+Core.GenericMemory#123.jit") == "@+Core.GenericMemory.jit"
        @test CDC.replace_llvm_module_name(".L+Core.GenericMemory#123.jit") == ".L+Core.GenericMemory.jit"
        @test CDC.replace_llvm_module_name(".L+Core.Array#123.jit") == ".L+Core.Array.jit"
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


@testset "AST" begin
    @testset "Compact if to ternary" begin
        e = :(a ? b : c)  # this is printed as a `if` statement by default
        e = MacroTools.prettify(e)

        cleaned_e = CDC.cleanup_code(Val(:ast), e)
        @test cleaned_e == "a ? b : c"

        @testset "Inline ternary" begin
            e = :((a ? b : c) * 42)  # this is printed as a `if` statement by default
            e = MacroTools.prettify(e)

            cleaned_e = CDC.cleanup_code(Val(:ast), e)
            @test cleaned_e == "(a ? b : c) * 42"
        end

        @testset "Nested ifs" begin
            e = quote
                if a
                    if b
                        c
                    else
                        d
                    end
                else
                    e
                end
            end
            e = MacroTools.prettify(e)

            e_str = sprint(print, e)
            cleaned_e = CDC.cleanup_code(Val(:ast), e)

            @test count("if", cleaned_e) == 1
            @test count("?",  cleaned_e) == 1

            # Others
            @test !has_trailing_spaces(cleaned_e)
            @test !endswith(cleaned_e, r"\R")  # no trailing newlines
            @test MacroTools.prettify(Meta.parse(cleaned_e)) == e
        end
    end

    @testset "Unnecessary indents" begin
        e = quote
            @simd :ivdep for i in 1:100
                f(i)
            end
        end
        e = MacroTools.prettify(e)

        e_str = sprint(print, e)
        cleaned_e = CDC.cleanup_code(Val(:ast), e)

        @test is_removed("    "^2, e_str, cleaned_e)
        @test count("    ", cleaned_e) == 1

        # Others
        @test !has_trailing_spaces(cleaned_e)
        @test !endswith(cleaned_e, r"\R")  # no trailing newlines
        @test MacroTools.prettify(Meta.parse(cleaned_e)) == e
    end

    @testset "Newlines" begin
        e = Meta.parse(read(@__FILE__(), String))
        e = MacroTools.prettify(e)

        e_str = sprint(print, e)
        cleaned_e = CDC.cleanup_code(Val(:ast), e)

        @test count(r"\R{2,}", e_str) == 0
        @test count(r"\R{2,}", cleaned_e) > 0

        # Others
        @test !has_trailing_spaces(cleaned_e)
        @test !endswith(cleaned_e, r"\R")  # no trailing newlines
        @test MacroTools.prettify(Meta.parse(cleaned_e)) == e
    end

    @testset "One liners" begin
        e = quote
            struct Bla end
            mutable struct Ble end
            struct Bli{A <: Unsigned} end
        end
        e = MacroTools.prettify(e)

        e_str = sprint(print, e)
        cleaned_e = CDC.cleanup_code(Val(:ast), e)

        @test count(r"\R", e_str) == 7
        @test count(r"\R", cleaned_e) == 2

        # Others
        @test !has_trailing_spaces(cleaned_e)
        @test !endswith(cleaned_e, r"\R")  # no trailing newlines
        @test MacroTools.prettify(Meta.parse("begin\n" * cleaned_e * "\nend")) == e
    end

    @testset "Multiline expressions" begin
        function test_multiline_expr(e::Expr)
            @testset "width=$line_length" for line_length in (100, 50, 0)
                cleaned_e = CDC.cleanup_code(Val(:ast), e, false, (; line_length))

                @test !has_trailing_spaces(cleaned_e)
                @test !endswith(cleaned_e, r"\R")  # no trailing newlines
                @test MacroTools.prettify(Meta.parse("begin\n" * cleaned_e * "\nend")) == e
            end
        end

        e1 = quote
            function bla(a, b, c; d=3, e=(123, 456, [1234567, 4343, "BOUH"]), efefefe=5) where {A, B <: C{DEF, HIJ, KLM}}
                a = this_is_a_function_call(
                    "this is an argument", "this is the second argument", "this is the third argument";
                    this_is_a_kwarg=and_that_is_its_default_value,
                    this_is_the_next_kwarg=and_its_default_value(
                        is_the_result, of_a_function_call, which_is_quite_long; dont_you_think="??"
                    )
                )
                this_is_a_function_definition(with_not_one, not_two, but_three_arguments="!!") =
                    and_a_simple_function_body(with_a_small_function_call)
                this_function_call(;
                    only_uses_kwargs=and_nothing_else, so_we_expect_the=";",
                    to_be_printed=immediately_after_the("(")
                )
            end

            function function_with(a_lot_of::Type{Parameters <: Within}) where {
                TheWhereClause <: Just{ToTestThings, AndMakeSure},
                TheyAreCorrectly, Printed <: OnMultiple{
                    Lines <: AndWell{Indented}, AndRecursively, SuchThat <: ItIsAlways{QuiteReadable}
                }
            }
                and = this_is = its = body
            end

            a = (;)
            b = (; c)
            d = (; e=f(g; h=i, j), k=l, m="qiqfmjziprejgqioezjqgmozejgqoiemj")
            n = (;
                o=(; p=[efefefefef, efefe, efefefe, efef, ef], r="fefefefef,efe,fe,feofslefpe", s=efefe),
                t=("ZAZDAZD", "FEZFEGg", Union{String, Vector{Any}}),
                u=1-2*3+4-6^7/8%9*0, v="fefefefefefefefefefefefe", w=[
                    "1234567890", [1, 2, 3, 4, 5, 6, 7, 8, 9], 12345678901234567890
                ]
            )
            (; aaaaaaaaaaaaaa, ooooooooooooooooooooooooo, pppppppppppppppppppp, qqqqqqqqqqqqqqqq) = obj
            x = ()
            y = ("bla",)
            z = ("bla", "ble", "bli")
        end
        e1 = MacroTools.prettify(e1)
        test_multiline_expr(e1)

        e2 = quote
            Base.@propagate_inbounds function k_mag_tw_tx_03104(domain::DomainBounds, x)
                ok, ideal_domain = Tilings.check_domain_fit(
                    Tilings.NoTiling{TileAxes}(WaveFusion.Axis[Axes.Y, Axes.X]), domain
                )
                if !ok
                    error(
                        "the domain cannot be applied to the tiling along the ", "Axes.Y",
                        " and ", "Axes.Y", " axes.",
                        if isnothing(ideal_domain)
                            ("\nUnknown required axes lengths",)
                        else
                            ("\nIdeal axes lengths: ", ideal_domain.layers, ", ", ideal_domain.elements)
                        end...
                    )
                end
                domain_strides = strides(domain)
                domain_info = (;
                    Y = (UnitRange{Int64})(axes(domain, Axes.Y)),
                    X = (UnitRange{Int64})(axes(domain, Axes.X)),
                    stride_Y = (Int64)(domain_strides[Axes.Y]),
                    tile_Y_count₁ = (Int64)(tile_domain_size₁.layers),
                    tile_bb_X₁ = (Int64)(tile_bb₁.elements),
                    tile_bb_Y₁ = (Int64)(tile_bb₁.layers),
                    tile_X_count₁ = (Int64)(tile_domain_size₁.elements)
                )
                if typemin(Int64) ≥ first(domain)
                    error("oopsie", Int64, ")")
                end
                k_mag_tw_tx_03104((WaveFusion.CodeGen.KernelImpl)(), domain_info, x)
            end
        end
        e2 = MacroTools.prettify(e2)
        test_multiline_expr(e2)
    end
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
        @test is_removed("// shmem has been demoted", ptx_sample, cleaned_ptx)
        @test is_removed("// demoted variable", ptx_sample, cleaned_ptx)

        # Demangling
        @test is_removed("14gpu_reverse_ka", ptx_sample, cleaned_ptx)
        @test occursin(r"\bgpu_reverse_ka\b", cleaned_ptx)

        # Removal of all LLVM module numbers for external functions
        @test is_removed(r"throw_boundserror_\d+", ptx_sample, cleaned_ptx)

        # Re-indentation of predicate guards
        @test is_removed(r"\t@%", ptx_sample, cleaned_ptx)

        # Reformat function calls
        @test is_removed(r"call\S+\s+\R", ptx_sample, cleaned_ptx)

        # Others
        @test !has_trailing_spaces(cleaned_ptx)
        @test count(r"\R{2,}", cleaned_ptx) == 0  # no empty lines
        @test count('\t', cleaned_ptx) == 0  # no tabs

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
        @test count(func_name * r"_\d+_param_\d+\b", ptx_sample) == 6
        @test count(r"\bparam_\d+\b", cleaned_ptx) == 6

        # Others
        @test !has_trailing_spaces(cleaned_ptx)
        @test count(r"\R{2,}", cleaned_ptx) == 0  # no empty lines
        @test !endswith(cleaned_ptx, r"\R")  # no trailing newlines
        @test count('\t', cleaned_ptx) == 0  # no tabs

        # Make sure we didn't remove any instruction by mistake
        @test count(';', ptx_sample) == count(';', cleaned_ptx)
    end

    @testset "Sample 3" begin
        # This sample calls a `@noinline` with no arguments and a return value
        ptx_sample = readchomp("./samples/extern_func_with_no_params.ptx")
        cleaned_ptx = CDC.cleanup_code(Val(:ptx), ptx_sample)

        println(TEST_IO, "\nCleaned PTX sample 3:")
        println(TEST_IO, cleaned_ptx)

        # Proper cleanup of the `@noinline f()` external function
        @test is_removed(r"\(\s+\)", ptx_sample, cleaned_ptx)
        @test count("()", cleaned_ptx) == 2  # once for the def, once for the call

        # Others
        @test !has_trailing_spaces(cleaned_ptx)
        @test count(r"\R{2,}", cleaned_ptx) == 0  # no empty lines
        @test !endswith(cleaned_ptx, r"\R")  # no trailing newlines
        @test count('\t', cleaned_ptx) == 0  # no tabs

        # Make sure we didn't remove any instruction by mistake
        @test count(';', ptx_sample) == count(';', cleaned_ptx)
    end
end


@testset "SASS" begin
    @testset "Sample 1" begin
        sass_sample = readchomp("./samples/extern_func_with_no_params.sass")
        cleaned_sass = CDC.cleanup_code(Val(:sass), sass_sample)

        println(TEST_IO, "\nCleaned SASS sample 1:")
        println(TEST_IO, cleaned_sass)

        # No mangled names
        @test is_removed(CDC.MANGLED_NAME_REGEX, sass_sample, cleaned_sass)

        # Make sure we didn't remove any instruction by mistake
        @test count(r";$"m, sass_sample) == count(r";$"m, cleaned_sass)

        # Others
        @test !has_trailing_spaces(cleaned_sass)
        @test !endswith(cleaned_sass, r"\R")  # no trailing newlines
        @test count('\t', cleaned_sass) == 0  # no tabs

        # Location comments should be removed with `dbinfo=false`
        cleaned_sass_no_loc = CDC.cleanup_code(Val(:sass), sass_sample, false)
        @test is_removed("; Location", cleaned_sass, cleaned_sass_no_loc)
        @test count(r"\R{2,}", cleaned_sass) == count(r"\R{2,}", cleaned_sass_no_loc)  # no empty lines were added
    end
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
        @test is_removed(r"\.ident\s\"clang version", gcn_sample, cleaned_gcn)
        @test is_removed(".amdhsa_kernel", gcn_sample, cleaned_gcn)
        @test is_removed(".AMDGPU.csdata", gcn_sample, cleaned_gcn)
        @test is_removed(".amdgpu_metadata", gcn_sample, cleaned_gcn)

        # Code-gen comments are all removed
        @test is_removed(r"; %L\d+", gcn_sample, cleaned_gcn)
        @test is_removed(r"; %bb\.\d+:", gcn_sample, cleaned_gcn)
        @test is_removed("; divergent unreachable", gcn_sample, cleaned_gcn)
        @test is_removed("; -- Begin function", gcn_sample, cleaned_gcn)
        @test is_removed("; -- End function", gcn_sample, cleaned_gcn)

        # Others
        @test !has_trailing_spaces(cleaned_gcn)
        @test count(r"\R{2,}", cleaned_gcn) == 0  # no empty lines
        @test !endswith(cleaned_gcn, r"\R")  # no trailing newlines
        @test count('\t', cleaned_gcn) == 0  # no tabs
    end
end


@testset "SPIRV" begin
    @testset "daxpy" begin
        spirv_sample = readchomp("./samples/daxpy.spirv")
        cleaned_spirv = CDC.cleanup_code(Val(:spirv), spirv_sample)
        with_meta_spirv = CDC.cleanup_code(Val(:spirv), spirv_sample, true, (; metadata=true))

        println(TEST_IO, "\nCleaned SPIRV sample daxpy:")
        println(TEST_IO, cleaned_spirv)

        # No more ultra long mangled names, even in meta operations
        @test is_removed(CDC.MANGLED_NAME_REGEX, spirv_sample, cleaned_spirv)
        @test is_removed(CDC.MANGLED_NAME_REGEX, spirv_sample, with_meta_spirv)

        @test cleaned_spirv != with_meta_spirv
        @test is_removed("OpCapability", with_meta_spirv, cleaned_spirv)

        # Others
        @test !has_trailing_spaces(cleaned_spirv)
        @test count(r"\R{2,}", cleaned_spirv) == 0  # no empty lines
        @test !endswith(cleaned_spirv, r"\R")  # no trailing newlines
        @test count('\t', cleaned_spirv) == 0  # no tabs
    end
end


@testset "AGX" begin
    # TODO
end

end
