
using OhMyREPL
using CodeDiffs
using Asciicast

# We don't use the `cast""` or any of the default Asciicast.jl functions, as we want to
# display the exact terminal colors of diffs.

# Custom palette to better distinguish bright green background from text
const TERMINAL_PALETTE = Dict(
    "fg" => "#CDCDCD",
    "bg" => "#283033",
    # Colors stolen from https://github.com/Gogh-Co/Gogh/blob/master/themes/Obsidian.yml
    "palette" => "#000000:#A60001:#00BB00:#FECD22:#3A9BDB:#BB00BB:#00BBBB:#BBBBBB:#555555:#FF0003:#93C863:#FEF874:#A1D7FF:#FF55FF:#55FFFF:#FFFFFF"
)


function repl_write(str)
    io = IOBuffer()
    io_ctx = IOContext(io, stdout)
    printstyled(io_ctx, "julia> "; color=:green)
    OhMyREPL.test_passes(io_ctx, OhMyREPL.PASS_HANDLER, str)
    return String(take!(io))
end


function repl_write!(cast, str, eval_str=false)
    eval_str && eval(Meta.parse(str))
    str = str * "\n\r"
    write_event!(cast, InputEvent, str)
    write_event!(cast, OutputEvent, repl_write(str))
end


function write_diff!(cast, str, last=false)
    diff = eval(Meta.parse(str))
    buf = IOBuffer()
    repl_write!(cast, str)
    show(IOContext(buf, stdout), MIME"text/plain"(), diff)
    write_event!(cast, OutputEvent, String(take!(buf)) * "\n" * (last ? "" : "\n"))
    return cast
end


function basic_usage(; delay=0.5, height=23)
    # Precompilation
    f1(a) = a + 1; f2(a) = a - 1
    show(devnull, MIME"text/plain"(), @code_diff type=:typed debuginfo=:none f1(1) f2(1))
    show(devnull, MIME"text/plain"(), @code_diff type=:llvm debuginfo=:none f1(1) f2(1))
    show(devnull, MIME"text/plain"(), @code_diff type=:native debuginfo=:none f1(1) f2(1))
    
    ENV["CODE_DIFFS_LINE_NUMBERS"] = false

    cast = Cast(IOBuffer(), Asciicast.Header(; height, theme=TERMINAL_PALETTE); delay)

    repl_write!(cast, "f1(a) = a + 1; f2(a) = a - 1;\n", true)

    write_diff!(cast, "@code_diff type=:typed debuginfo=:none f1(1) f2(1)")

    write_diff!(cast, "@code_diff type=:llvm debuginfo=:none f1(1) f2(1)")

    ENV["CODE_DIFFS_LINE_NUMBERS"] = true
    repl_write!(cast, """ENV["CODE_DIFFS_LINE_NUMBERS"] = true""")
    write_event!(cast, OutputEvent, "true\n\n")

    write_diff!(cast, "@code_diff type=:native debuginfo=:none f1(1) f2(1)", true)

    return cast
end


function ast_diff(; delay=0.5, height=14)
    ENV["CODE_DIFFS_LINE_NUMBERS"] = true

    cast = Cast(IOBuffer(), Asciicast.Header(; height, theme=TERMINAL_PALETTE); delay)

    write_diff!(cast, """@code_diff(type=:ast,
        :(function g(x) iseven(x) ? "even"     : "odd"     end),
        :(function g(x) isodd(x)  ? "not even" : "not odd" end)
    )""", true)

    return cast
end


if !isinteractive()
    Asciicast.save_gif(joinpath(pkgdir(CodeDiffs), "assets", "basic_usage.gif"), basic_usage())
    Asciicast.save_gif(joinpath(pkgdir(CodeDiffs), "assets", "ast_diff.gif"), ast_diff())
end
