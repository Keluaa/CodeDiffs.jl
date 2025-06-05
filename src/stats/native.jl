
function extract_stats(::Val{:native}, code, stats_opts)
    @static if Sys.ARCH === :x86 || Sys.ARCH === :x86_64
        return extract_stats(Val(:x86), code, stats_opts)
    else
        error("unsupported architecture: ", Sys.ARCH)
    end
end
