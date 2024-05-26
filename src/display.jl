
function print_str_with_tabs(io::IO, str, tab_replacement)
    # 'str' is expected to not have newlines
    full_tab_len = length(tab_replacement)
    str_pos = 1
    column_pos = 1
    while (tab_pos = findnext('\t', str, str_pos); !isnothing(tab_pos))
        str_part_len = (tab_pos - 1) - str_pos + 1
        column_pos += str_part_len
        tab_len = full_tab_len - mod(column_pos - 1, full_tab_len)
        print(io, @view(str[str_pos:tab_pos - 1]), @view(tab_replacement[1:tab_len]))
        column_pos += tab_len
        str_pos = tab_pos + 1
    end
    print(io, @view str[str_pos:end])
end


function print_columns(io, width, left_line, sep, right_line, empty_line, tab_replacement)
    wio = TextWidthLimiter(IOBuffer(), width)
    wio_ctx = IOContext(wio, io)

    print_str_with_tabs(wio_ctx, left_line, tab_replacement)
    left_len = wio.width
    printstyled(io, String(take!(wio)))
    if left_len < width
        printstyled(io, @view(empty_line[1:width - left_len]))
    end

    printstyled(io, sep)

    print_str_with_tabs(wio_ctx, right_line, tab_replacement)
    right_len = wio.width
    printstyled(io, String(take!(wio)))
    if right_len < width
        # Padding needed only for line numbers
        printstyled(io, @view(empty_line[1:width - right_len]))
    end
end


function print_columns_change(io, width, line_diff, highlighted_left, sep, empty_line, tab_replacement)
    wio = TextWidthLimiter(IOBuffer(), width)
    wio_ctx = IOContext(wio, io)

    printstyled_code_line_diff(wio_ctx, line_diff, highlighted_left, true, tab_replacement)
    left_len = wio.width
    printstyled(io, String(take!(wio)))
    if left_len < width
        printstyled(io, @view(empty_line[1:width - left_len]))
    end

    printstyled(io, sep)

    printstyled_code_line_diff(wio_ctx, line_diff, highlighted_left, false, tab_replacement)
    right_len = wio.width
    printstyled(io, String(take!(wio)))
    if right_len < width
        # Padding needed only for line numbers
        printstyled(io, @view(empty_line[1:width - right_len]))
    end
end


function next_ansi_sequence(str, idx, str_len)
    m = (1 ≤ idx ≤ str_len) ? match(ANSI_REGEX, str, idx) : nothing
    if m === nothing
        return typemax(idx), ""
    else
        return m.offset, m.match
    end
end


const ANSI_DEFAULT_BKG = "\e[49m"
const ANSI_RED_BKG = "\e[41m"
const ANSI_GREEN_BKG = "\e[42m"

const ANSI_DEFAULT_FGR = "\e[39m"
const ANSI_RED_FGR = "\e[31m"
const ANSI_GREEN_FGR = "\e[32m"


function printstyled_code_line_diff(
    io::IO, diff::DeepDiffs.StringDiff, highlighted_left, removed_only::Bool,
    tab_replacement
)
    xchars = DeepDiffs.before(diff.diff)
    ychars = DeepDiffs.after(diff.diff)

    if get(io, :color, false)
        default_bkg = ANSI_DEFAULT_BKG
        removed_bkg_color = removed_only ? ANSI_RED_BKG : ""
        added_bkg_color   = removed_only ? "" : ANSI_GREEN_BKG
    else
        default_bkg = ""
        removed_bkg_color = ""
        added_bkg_color = ""
    end

    hl_length = length(highlighted_left)
    idx_before_next_ansi, ansi_seq = next_ansi_sequence(highlighted_left, 1, hl_length)
    highlighted_offset = 0

    full_tab_len = length(tab_replacement)
    column_pos = 1
    tmp_io = IOBuffer()
    prev_state = :same
    DeepDiffs.visitall(diff.diff) do idx, state, _
        if idx + highlighted_offset ≥ idx_before_next_ansi
            write(tmp_io, ansi_seq)
            if prev_state !== :same && occursin("\e[0m", ansi_seq)
                prev_state = :same
            end
            highlighted_offset += length(ansi_seq)
            idx_before_next_ansi, ansi_seq =
                next_ansi_sequence(highlighted_left, idx + highlighted_offset, hl_length)
        end

        if state === :removed
            !removed_only && return
            prev_state !== :removed && write(tmp_io, removed_bkg_color)
            c = xchars[idx]
        elseif state === :added
            removed_only && return
            prev_state !== :added && write(tmp_io, added_bkg_color)
            c = ychars[idx]
        else
            prev_state !== :same && write(tmp_io, default_bkg)
            c = xchars[idx]
        end

        if c == '\t'
            tab_len = full_tab_len - mod(column_pos - 1, full_tab_len)
            write(tmp_io, @view(tab_replacement[1:tab_len]))
            column_pos += tab_len
        else
            write(tmp_io, c)
            column_pos += 1
        end

        prev_state = state
    end

    prev_state !== :same && write(tmp_io, default_bkg)
    write(tmp_io, @view highlighted_left[idx_before_next_ansi:end])

    printstyled(io, String(take!(tmp_io)))
end


"""
    side_by_side_diff([io::IO,] diff::CodeDiff; tab_width=4, width=nothing, line_numbers=nothing)

Side by side display of a [`CodeDiff`](@ref) to `io` (defaults to `stdout`).

`width` defaults to the width of the terminal. It is `80` by default for non-terminal `io`.

`tab_width` is the number of spaces tabs are replaced with.

`line_numbers=true` will add line numbers on each side of the columns. It defaults to the
environment variable `"CODE_DIFFS_LINE_NUMBERS"`, which itself defaults to `false`.
"""
function side_by_side_diff(io::IO, diff::CodeDiff; tab_width=4, width=nothing, line_numbers=nothing)
    line_numbers = !isnothing(line_numbers) ? line_numbers : parse(Bool, get(ENV, "CODE_DIFFS_LINE_NUMBERS", "false"))

    if get(io, :color, false)
        xlines = split(diff.highlighted_before, '\n')
        ylines = split(diff.highlighted_after, '\n')
    else
        xlines = split(diff.before, '\n')
        ylines = split(diff.after, '\n')
    end

    if !(length(diff.diff.before) == length(xlines) && length(diff.diff.after) == length(ylines))
        # Can happen in case of silent highlighting failure (e.g. pygments)
        error("cannot display `CodeDiff` as highlighted code do not match the unhighlighted one")
    end

    width = !isnothing(width) ? width : displaysize(io)[2]
    if line_numbers
        max_line = length(xlines) + length(DeepDiffs.added(diff))
        line_num_width = length(string(max_line))
        width -= 2*(line_num_width + 1)
        empty_line_num = " "^(line_num_width+1)
    else
        line_num_width = 0
        empty_line_num = ""
    end

    left_removed = "⟪"
    right_added = "⟫"
    if get(io, :color, false)
        left_removed = ANSI_RED_FGR * left_removed * ANSI_DEFAULT_FGR
        right_added = ANSI_GREEN_FGR * right_added * ANSI_DEFAULT_FGR
    end

    sep_same       =               " ┃ "
    sep_removed    = left_removed * "┫ "
    sep_added      =               " ┣" * right_added
    sep_changed_to = left_removed * "╋" * right_added

    column_width = fld(width - length(sep_same), 2)
    column_width ≤ 5 && error("output terminal width ($width) is too small")
    empty_column = " "^column_width
    tab = " "^tab_width

    left_line = 1
    right_line = 1
    function print_line_num(side)
        !line_numbers && return
        if side === :left
            line_num = lpad(string(left_line), line_num_width)
            printstyled(io, line_num, ' '; color=:light_black)
            left_line += 1
        else
            line_num = rpad(string(right_line), line_num_width)
            printstyled(io, line_num; color=:light_black)
            right_line += 1
        end
    end

    DeepDiffs.visitall(diff) do idx, state, last
        if state === :removed
            print_line_num(:left)
            print_columns(io, column_width, xlines[idx], sep_removed, "", empty_column, tab)
        elseif state === :added
            printstyled(io, empty_line_num)
            print_columns(io, column_width, "", sep_added, ylines[idx], empty_column, tab)
            print_line_num(:right)
        elseif state === :changed
            print_line_num(:left)
            _, line_diff = diff.changed[idx]
            print_columns_change(io, column_width, line_diff, xlines[idx], sep_changed_to, empty_column, tab)
            print_line_num(:right)
        else
            print_line_num(:left)
            print_columns(io, column_width, xlines[idx], sep_same, xlines[idx], empty_column, tab)
            print_line_num(:right)
        end
        !last && println(io)
    end
end

function side_by_side_diff(diff::CodeDiff; kwargs...)
    side_by_side_diff(stdout, diff; kwargs...)
    println()
end
