module CodeDiffsCUDA

using CodeDiffs
using CUDA
import CUDA: GPUCompiler
import KernelAbstractions as KA

gpu_compiler_kwargs() = CUDA.COMPILER_KWARGS

include("gpu_common.jl")


function CodeDiffs.extract_ka_backend_kwargs(kernel::KA.Kernel{CUDABackend})
    # Those two parameters are passed to the `@cuda` kernel constructor in `CUDA.CUDAKernels`
    backend = KA.backend(kernel)
    if KA.workgroupsize(kernel) <: KA.StaticSize
        workgroupsize = prod(KA.get(KA.workgroupsize(kernel)))
    else
        workgroupsize = nothing
    end
    return (; always_inline=backend.always_inline, maxthreads=workgroupsize)
end


function gpu_compiler_job(mi::Core.MethodInstance; kwargs...)
    config = CUDA.compiler_config(CUDA.device(); kwargs...)
    return CUDA.CompilerJob(mi, config)
end


function code_sass(job::CUDA.CompilerJob; dbinfo=true, kwargs...)
    @nospecialize(job)
    return sprint((io, job) -> CUDA.code_sass(io, job; kwargs...), job; context=:color=>false)
end


function code_sass(f, types; world=nothing, dbinfo=true, kwargs...)
    @nospecialize(f, types)
    compiler_kwargs, kwargs = split_kwargs(kwargs, gpu_compiler_kwargs())
    job = gpu_compiler_job(f, types, world; compiler_kwargs...)
    return code_sass(job; kwargs...)
end


CodeDiffs.argconvert(::Val{:cuda_typed},  arg) = CUDA.cudaconvert(arg)
CodeDiffs.argconvert(::Val{:cuda_llvm},   arg) = CUDA.cudaconvert(arg)
CodeDiffs.argconvert(::Val{:ptx},         arg) = CUDA.cudaconvert(arg)
CodeDiffs.argconvert(::Val{:cuda_native}, arg) = CUDA.cudaconvert(arg)
CodeDiffs.argconvert(::Val{:sass},        arg) = CUDA.cudaconvert(arg)
CodeDiffs.argconvert(::Val{:cuda_stats},  arg) = CUDA.cudaconvert(arg)

@nospecialize

CodeDiffs.get_code_dispatch(::Val{:cuda_typed},  f, types; kwargs...) = code_gpu_typed(f, types; kwargs...)
CodeDiffs.get_code_dispatch(::Val{:cuda_llvm},   f, types; kwargs...) = code_gpu_llvm(f, types; kwargs...)
CodeDiffs.get_code_dispatch(::Val{:ptx},         f, types; kwargs...) = CodeDiffs.get_code_dispatch(Val{:cuda_native}(), f, types; kwargs...)
CodeDiffs.get_code_dispatch(::Val{:cuda_native}, f, types; kwargs...) = code_gpu_native(f, types; kwargs...)
CodeDiffs.get_code_dispatch(::Val{:sass},        f, types; kwargs...) = code_sass(f, types; kwargs...)

function CodeDiffs.get_code_dispatch(::Val{:cuda_stats}, f, types; kwargs...)
    ptx_source = code_gpu_native(f, types; kwargs...)
    sass_source = code_sass(f, types; kwargs...)
    return extract_kernel_stats(ptx_source, sass_source)
end

@specialize


CodeDiffs.code_highlighter(::Val{:cuda_typed})  = CodeDiffs.code_highlighter(Val{:typed}())
CodeDiffs.code_highlighter(::Val{:cuda_llvm})   = (io, str) -> highlight_using_pygments(io, str, "llvm")
CodeDiffs.code_highlighter(::Val{:ptx})         = (io, str) -> highlight_using_pygments(io, str, "ptx")
CodeDiffs.code_highlighter(::Val{:cuda_native}) = CodeDiffs.code_highlighter(Val{:ptx}())

function highlight_using_pygments(io::IO, str::AbstractString, lexer)
    if @static(pkgversion(GPUCompiler) < v"1.2.0" && lexer == "ptx")
        write(io, str)
    else
        GPUCompiler.highlight(io, str, lexer)
    end
end


# The PTX output of LLVM's NVPTX backend has a comment with the mangled function name
const PTX_FUNC_NAME_COMMENT_REGEX = r"// -- Begin function "m * CodeDiffs.MANGLED_NAME_REGEX * r"$"m

# Same with SASS but the name is surrounded by a lot of dashes
const SASS_FUNC_NAME_COMMENT_REGEX = r"//-{5,} .text."m * CodeDiffs.MANGLED_NAME_REGEX * r" -{5,}$"m


function CodeDiffs.cleanup_code(::Val{:cuda_typed}, c, dbinfo, cleanup_opts)
    if get(cleanup_opts, :expand_llvmcall, true)
        c = CodeDiffs.cleanup_inline_llvmcall_modules(c)
    end
    return c
end


function CodeDiffs.cleanup_code(::Val{:cuda_llvm}, c, dbinfo, cleanup_opts)
    c = CodeDiffs.replace_llvm_module_name(c)
    c = CodeDiffs.clean_function_name(CodeDiffs.LLVM_IR_FUNC_NAME_MANGLED_REGEX, c)
    return c
end


CodeDiffs.cleanup_code(::Val{:cuda_native}, c, dbinfo, cleanup_opts) =
    CodeDiffs.cleanup_code(Val{:ptx}(), c, dbinfo, cleanup_opts)

function CodeDiffs.cleanup_code(::Val{:ptx}, c, dbinfo, cleanup_opts)
    c = CodeDiffs.replace_llvm_module_name(c)
    c = CodeDiffs.clean_function_name(PTX_FUNC_NAME_COMMENT_REGEX, c)
    c = cleanup_external_functions(c)
    if get(cleanup_opts, :demangle, true)
        c = CodeDiffs.demangle_all(c)  # Demangle only names which aren't the function's name
    end

    extra_patterns = []
    if get(cleanup_opts, :indent_calls, true)
        push!(extra_patterns, indent_ptx_function_calls())
    end
    if !get(cleanup_opts, :keep_loop_comments, false)
        # Loop comments are interesting, but can be quite annoying with complex loop structures
        push!(extra_patterns, r"\n\s+\/\/\s+(=>\s*)?(Parent|This|This Inner|Child|in) Loop[^\n]+" => "")
    end
    if (align_preds = get(cleanup_opts, :align_preds, 8); align_preds > 0)
        # Align guard predicates such that the beginning of the instruction is at the
        # `align_preds`-th column.
        push!(extra_patterns, align_instruction_predicates(align_preds))
    end

    return replace(c,
        # Remove the 3 extra header lines
        r"//\s//\sGenerated by LLVM NVPTX Back-End\s//\s\s" => "",
        # I don't know what `callseq` indicates in comments, but the numbers after change at every call
        r" // callseq .+$"m => "",
        # Remove 'inline asm' comments (remove the newline as well)
        r"^\s+// (begin|end) inline asm\R"m => "",
        # Remove the "end function" comment
        r"\s+// -- End function\n" => "",
        # Remove empty lines
        r"\n{2,}" => "\n",
        extra_patterns...
    )
end


function CodeDiffs.cleanup_code(::Val{:sass}, c, dbinfo, cleanup_opts)
    # SASS problems:
    # Registers seem to be assigned randomly, changing from one call to another with the
    # same input, as well as some immediate values (maybe related to the functions order in PTX?).
    # Some instructions (only `MOV` from what I saw) might be ordered differently, or even
    # in different numbers (max of what I could see is 1, but still surprising).
    c = CodeDiffs.replace_llvm_module_name(c)
    c = CodeDiffs.clean_function_name(SASS_FUNC_NAME_COMMENT_REGEX, c)
    if get(cleanup_opts, :demangle, true)
        c = CodeDiffs.demangle_all(c)  # Demangle only names which aren't the function's name
    end
    if !dbinfo
        c = replace(c, r"; Location .+\n" => "")  # Remove location comments
    end
    return c
end


function cleanup_external_functions(c)
    # In PTX code there can be external functions defined with the actual kernel function.
    # Those can have random positions, and their parameters can have names using the
    # `globalUniqueGeneratedNames` value.
    # To make the output consistent each time, we must filter the parameter names and order
    # the function definitions in a deterministic way.

    # Match external function definitions by following the PTX syntax:
    # https://docs.nvidia.com/cuda/parallel-thread-execution/index.html?highlight=extern#linking-directives-extern
    # https://docs.nvidia.com/cuda/parallel-thread-execution/index.html?highlight=extern#kernel-and-function-directives-func
    re_extern_func = r"\.extern \.func\s+"s
    re_attribute_list = r"(?:\.attribute\(.+?\)\s+)?"s
    re_retval = r"(?:\(.+\)\s+)?"s
    re_func_name = r"(\w+)\s+"s  # Capture the function name
    re_param_list = r"\([^\)]+\)"s
    re_noreturn = r"(?:\s+\.noreturn)?"s
    re_func_end = r"\s*;"s       # Since it is an external function it has no body
    re_extern_func_def = re_extern_func * re_attribute_list * re_retval * re_func_name * re_param_list * re_noreturn * re_func_end

    external_funcs = String[]
    for external_func in eachmatch(re_extern_func_def, c)
        func_def  = external_func.match
        func_name = external_func[1]

        param_idx = 0
        function rename_bad_param(_)
            new_name = func_name * "_param_" * string(param_idx)
            param_idx += 1
            return new_name
        end

        func_def = replace(func_def, func_name * r"_\d+_param" => rename_bad_param)
        push!(external_funcs, func_def)
    end

    isempty(external_funcs) && return c
    sort!(external_funcs)  # Basic attempt at ordering external functions, this might not be enough

    func_idx = 0
    function next_func_def(_)
        func_idx += 1
        return external_funcs[func_idx]
    end

    # Parse the code again but this time replace the external functions with the sorted ones
    return replace(c, re_extern_func_def => next_func_def)
end


function indent_ptx_function_calls()
    # Matches `call func, (param_1, param_2...);`
    # Groups:
    #  - 1: call instruction options
    #  - 2: `func`
    #  - 3: parameters list
    ptx_call_regex = r"call(.*)\s+(.+),\s+\(([^;]+)\n\s+\);"

    function indent_call_params(call_inst)
        m = match(ptx_call_regex, call_inst)
        isnothing(m) && return call_inst
        indent = " "^8
        params = replace(m[3], "\n" => "\n" * indent)
        return "call" * m[1] * m[2] * ", (" * params * "\n" * indent * ");"
    end

    return ptx_call_regex => indent_call_params
end


function align_instruction_predicates(column)
    # The regex extracts from "   @p12 any_instruction" or "    @!p12 any_instruction" the "@p12" or
    # "@!p12" predicate, without the surrounding spaces. The "any_instruction" part is in group 2.
    pred_regex = r"^\s*(@!?[^\s]+)\s*([^\s]+);?"m

    function align_to_nth_column(c)
        m = match(pred_regex, c)
        isnothing(m) && return c
        if !endswith(m.match, ';')
            # If the instruction has operands, then we need to add spaces after the mnemonic such
            # that they stay in their initial column, so that they stay aligned with the other
            # instructions' operands.
            # e.g. "    @p1 bra    $L2;"  =>  " @p1 bra    $L2;"  =>  " @p1 bra        $L2;"
            operands_column = column * 2  # By default, operands are placed after the 16th column
            pred_length     = length(m[1]) + 1  # +1 because of the space afterward
            mnemonic_length = length(m[2])
            if mnemonic_length + column > operands_column
                extra_spaces = ""  # the mnemonic is too long
            else
                extra_spaces = " "^min(pred_length, column)
            end
        else
            extra_spaces = ""
        end
        return lpad(m[1], column - 1) * " " * m[2] * extra_spaces
    end

    return pred_regex => align_to_nth_column
end


function extract_kernel_ptx_stats(ptx_source)
    # Matches most PTX variable declarations, in any memory space (group "space"), with any
    # attributes (group "attributes"), and an optional array/parametric definition (group "array").
    # The data type is in group "type", and any vector attribute is in group "vec".
    # It accepts all valid PTX identifiers: https://docs.nvidia.com/cuda/parallel-thread-execution/index.html?highlight=global#identifiers
    # It does not support all declarations, namely multi-dimentional arrays, implicit array sizes
    # and mutliple declarations per line (".reg .b8 a, b, c;"). I have never seen those syntaxes
    # being generated by a compiler, so it shouldn't matter.
    mem_def_regex = r"\.(?'space'global|const|param|shared|local|reg)(?'attrs'(?:\s+\.(?:attribute\(.+\)|align \d+|(?'vec'v\d+)|(?'type'[busf]\d+|pred)|\w+))+)\s+[a-zA-Z0-9_$%]+(?'array'\[\d+\]|<\d+>)?"

    # The `mem_def_regex` considers all `.param` declarations, even those which are in `.extern`
    # functions, which is wrong. To avoid changing the `mem_def_regex` we must ignore matches within
    # extern function definitions.
    extern_func_regex = r"\.extern\s+\.func[^;]+"

    extern_func_regions = Vector{UnitRange{Int}}()
    last_extern_def = 0
    for extern_func_def in eachmatch(extern_func_regex, ptx_source)
        region = (1:length(extern_func_def.match)) .+ (extern_func_def.offset - 1)
        push!(extern_func_regions, region)
        last_extern_def = max(last_extern_def, last(region))
    end

    mem_definitions = Dict{String, Dict{String, Int}}()
    for mem_def in eachmatch(mem_def_regex, ptx_source)
        if mem_def.offset ≤ last_extern_def && any(Ref(mem_def.offset) .∈ extern_func_regions)
            # The variable definition is in an extern function, so it must be ignored.
            continue
        end

        mem_space = String(mem_def[:space])
        data_type = String(@something mem_def[:type] "unknown")

        if isnothing(mem_def[:array])
            count = 1
        else
            count = @something tryparse(Int, mem_def[:array][2:end-1]) 1
        end

        if !isnothing(mem_def[:vec])
            vec_size = @something tryparse(Int, mem_def[:vec][2:end]) 1
            count *= vec_size
        end

        mem_defs = get!(Dict{String, Int}, mem_definitions, mem_space)
        def_count = get(mem_defs, data_type, 0)
        mem_defs[data_type] = def_count + count
    end

    # Matches all variations (hopefully) of the `ld`, `ld.global.nc`, `ldu`, `st`, `st.async` and `st.bulk`
    # instructions: https://docs.nvidia.com/cuda/parallel-thread-execution/index.html?highlight=global#data-movement-and-conversion-instructions-ld
    # The leading instruction mnemonic is in group "inst". The memory space is in group "space", and
    # does not include the optional "::cta" or "::cluster" which can be found for some variants.
    # The vector size (if any) is in group "vec". The data type is in group "type". Additional
    # attributes are discarded.
    mem_inst_regex = r"\b(?'inst'ld|ldu|st)(?:\.(?:(?'space'global|const|param|shared|local)(?:::[^\s\.]+)?|(?'vec'v\d+)|(?'type'[busf]\d+)|[^\s\.]+))+\b"

    mem_instructions = Dict{String, @NamedTuple{loads::Dict{String, Int}, stores::Dict{String, Int}}}()
    for mem_inst in eachmatch(mem_inst_regex, ptx_source)
        is_load   = mem_inst[:inst] in ("ld", "ldu")
        mem_space = String(@something mem_inst[:space] "global")  # Assume that all generic addressing goes to global memory
        data_type = String(@something mem_inst[:type] "unknown")

        count = 1
        if !isnothing(mem_inst[:vec])
            vec_size = @something tryparse(Int, mem_inst[:vec][2:end]) 1
            count *= vec_size
        end

        mem_insts = get!(mem_instructions, mem_space) do ; (; loads=Dict{String, Int}(), stores=Dict{String, Int}()) end
        inst_counts = is_load ? mem_insts.loads : mem_insts.stores
        inst_count = get(inst_counts, data_type, 0)
        inst_counts[data_type] = inst_count + count
    end

    # Compute the total amount of memory within all variable declarations for each memory space.
    # We only consider fundamental data types: https://docs.nvidia.com/cuda/parallel-thread-execution/index.html?highlight=global#fundamental-types
    # Predicate types (.pred) isn't listed since I don't know how it is stored in reality.
    fundamental_types = Dict(
        "b8" => 1, "b16" => 2, "b32" => 4, "b64" => 8, "b128" => 16,
        "s8" => 1, "s16" => 2, "s32" => 4, "s64" => 8,
        "u8" => 1, "u16" => 2, "u32" => 4, "u64" => 8,
                   "f16" => 2, "f32" => 4, "f64" => 8, "f16x2" => 4,
    )

    mem_sizes = Dict{String, Int}()
    for (mem_type, mem_defs) in pairs(mem_definitions)
        mem_size = 0
        for (data_type, count) in pairs(mem_defs)
            data_size = get(fundamental_types, data_type, 0)
            mem_size += data_size * count
        end
        mem_sizes[mem_type] = mem_size + get(mem_sizes, mem_type, 0)
    end

    return (;
        defs = (;
            var"global" = get(Dict{String, Int}, mem_definitions, "global"),
            constant    = get(Dict{String, Int}, mem_definitions, "const"),
            param       = get(Dict{String, Int}, mem_definitions, "param"),
            shared      = get(Dict{String, Int}, mem_definitions, "shared"),
            var"local"  = get(Dict{String, Int}, mem_definitions, "local"),
            registers   = get(Dict{String, Int}, mem_definitions, "reg"),
        ),
        total = (;
            var"global" = get(mem_sizes, "global", 0),
            constant    = get(mem_sizes, "const",  0),
            param       = get(mem_sizes, "param",  0),
            shared      = get(mem_sizes, "shared", 0),
            var"local"  = get(mem_sizes, "local",  0),
        ),
        inst = (;
            var"global" = get(mem_instructions, "global") do ; (; loads=Dict{String, Int}(), stores=Dict{String, Int}()) end,
            constant    = get(mem_instructions, "const")  do ; (; loads=Dict{String, Int}(), stores=Dict{String, Int}()) end,
            param       = get(mem_instructions, "param")  do ; (; loads=Dict{String, Int}(), stores=Dict{String, Int}()) end,
            shared      = get(mem_instructions, "shared") do ; (; loads=Dict{String, Int}(), stores=Dict{String, Int}()) end,
            var"local"  = get(mem_instructions, "local")  do ; (; loads=Dict{String, Int}(), stores=Dict{String, Int}()) end,
        ),
    )
end


function extract_kernel_sass_stats(sass_source)
    # The amount of registers per thread (I hope? This isn't documented anywhere...)
    m_reg = match(r"SHI_REGISTERS=(\d+)", sass_source)
    registers = isnothing(m_reg) ? 0 : @something(tryparse(Int, m_reg[1]), 0)

    # The SM version the kernel is compiled for
    m_sm = match(r"EF_CUDA_SM(\d+)", sass_source)
    SM = isnothing(m_sm) ? 0 : @something(tryparse(Int, m_sm[1]), 0)

    # This regex tries to match only SASS instructions, ignoring comments, attributes and labels,
    # but including predicates (starting with a "@"). We reject ':' in order to not match labels.
    sass_inst_regex = r"^\s*(@!?\w+\s+)?\w+[^;:]*;"m
    inst_count = count(sass_inst_regex, sass_source)

    # Stats about some notable instructions.
    # External function calls can have important overhead (in some cases, registers need to be
    # saved and restored around a call), so they are included.
    # See https://docs.nvidia.com/cuda/cuda-binary-utilities/index.html#instruction-set-reference
    # Obivously, it may change in future architectures.
    workgroup_sync = count("BSYNC", sass_source)
    warp_sync      = count("WARPSYNC", sass_source)
    function_calls = count("CALL", sass_source)

    return (; SM, registers, inst_count, workgroup_sync, warp_sync, function_calls)
end


struct CUDAKernelStats
    # PTX
    defs :: @NamedTuple{
        var"global" :: Dict{String, Int},
        constant    :: Dict{String, Int},
        param       :: Dict{String, Int},
        shared      :: Dict{String, Int},
        var"local"  :: Dict{String, Int},
        registers   :: Dict{String, Int},
    }

    total :: @NamedTuple{
        var"global" :: Int,  # Total global memory used by the kernel variables (bytes)
        constant    :: Int,  # Total constant memory used by the kernel variables (bytes)
        param       :: Int,  # Total constant memory used by the kernel variables (bytes)
        shared      :: Int,  # Total shared memory used by the kernel (bytes, for each workgroup)
        var"local"  :: Int,  # Total local memory used by the kernel (bytes, for each thread)
    }

    inst :: @NamedTuple{
        var"global" :: @NamedTuple{loads::Dict{String, Int}, stores::Dict{String, Int}},
        constant    :: @NamedTuple{loads::Dict{String, Int}, stores::Dict{String, Int}},
        param       :: @NamedTuple{loads::Dict{String, Int}, stores::Dict{String, Int}},
        shared      :: @NamedTuple{loads::Dict{String, Int}, stores::Dict{String, Int}},
        var"local"  :: @NamedTuple{loads::Dict{String, Int}, stores::Dict{String, Int}},
    }

    # SASS
    SM             :: Int  # Target SM
    registers      :: Int  # Registers used per thread
    instructions   :: Int  # Number of instructions
    workgroup_sync :: Int  # Number of `BSYNC` instructions: `CUDA.sync_threads()`
    warp_sync      :: Int  # Number of `WARPSYNC` instructions: `CUDA.sync_warp()`
    calls          :: Int  # Number of `CALL`s to other functions
end


function extract_kernel_stats(ptx_source, sass_source)
    ptx_stats = extract_kernel_ptx_stats(ptx_source)
    sass_stats = extract_kernel_sass_stats(sass_source)
    return CUDAKernelStats(ptx_stats..., sass_stats...)
end


function Base.show(io::IO, stats::CUDAKernelStats)
    println(io, "Kernel memory stats (static allocations):")
    println(io, " - Global  ", Base.format_bytes(stats.total.global))
    println(io, " - Const   ", Base.format_bytes(stats.total.constant))
    println(io, " - Param   ", Base.format_bytes(stats.total.param))
    println(io, " - Shared  ", Base.format_bytes(stats.total.shared))
    println(io, " - Local   ", Base.format_bytes(stats.total.local))
    println(io)
    println(io, "SASS source stats:")
    println(io, " - Target SM         ", stats.SM)
    println(io, " - Registers usage   ", stats.registers)
    println(io, " - Instructions      ", stats.instructions)
    println(io, " - Workgroup sync    ", stats.workgroup_sync)
    println(io, " - Warp sync         ", stats.warp_sync)
    println(io, " - Function calls    ", stats.calls)

    print(io, "\nPTX variable declarations:")
    all(isempty, stats.defs) && print(io, " none")
    for (name, defs) in pairs(stats.defs)
        isempty(defs) && continue
        print(io, "\n - ", uppercasefirst(String(name)), ":")
        defs_list = collect(pairs(defs))
        sort!(defs_list; by=first)
        for (data_type, count) in defs_list
            print(io, "\n   - ", rpad(data_type, 5), " ", lpad(count, 5))
        end
    end

    print(io, "\n\nPTX memory instructions (loads, stores):")
    all(isempty, stats.inst) && print(io, " none")
    for (name, space) in pairs(stats.inst)
        all(isempty, space) && continue
        print(io, "\n - ", uppercasefirst(String(name)), ":")
        types = collect(keys(space.loads) ∪ keys(space.stores))
        sort!(types)
        for data_type in types
            ld_count = get(space.loads,  data_type, 0)
            st_count = get(space.stores, data_type, 0)
            print(io, "\n   - ", rpad(data_type, 5), " ", lpad(ld_count, 5), " ", lpad(st_count, 5))
        end
    end
end

end
