
"""
    CodeDiff(code₁, code₂)
    CodeDiff(code₁, code₂, highlighted₁, highlighted₂)

A difference between `code₁` and `code₂`.

`code₁` and `code₂` should have no highlighting. Only `highlighted₁` and `highlighted₂`
should have syntax highlighting. When showing the differences, their formatting will be
re-applied.

For cleaner differences, use [`replace_llvm_module_name`](@ref) on all codes.

Use [`optimize_line_changes!`](@ref) to improve the difference.

Fancy REPL output is done with [`side_by_side_diff`](@ref).
"""
struct CodeDiff <: DeepDiffs.DeepDiff
    before::String
    after::String
    # line idx => (line idxs added before the change, line after change, change diff)
    changed::Dict{Int, Tuple{Vector{Int}, Int, DeepDiffs.StringDiff}}
    # Line idxs which are part of `changed`, including line idxs added before changes
    ignore_added::Set{Int}
    # Line by line diff, without highlighting
    diff::DeepDiffs.VectorDiff
    highlighted_before::String
    highlighted_after::String
end


function CodeDiff(
    diff::DeepDiffs.StringLineDiff,
    highlighted_before::AbstractString, highlighted_after::AbstractString
)
    return CodeDiff(
        diff.before, diff.after, Dict(), Set(), diff.diff,
        String(highlighted_before), String(highlighted_after)
    )
end

function CodeDiff(X, Y, highlighted_X, highlighted_Y)
    return CodeDiff(DeepDiffs.deepdiff(X, Y), highlighted_X, highlighted_Y)
end

CodeDiff(X, Y) = CodeDiff(X, Y, X, Y)


DeepDiffs.before(diff::CodeDiff) = diff.before
DeepDiffs.after(diff::CodeDiff) = diff.after
DeepDiffs.added(diff::CodeDiff) = DeepDiffs.added(diff.diff)
DeepDiffs.removed(diff::CodeDiff) = DeepDiffs.removed(diff.diff)
DeepDiffs.changed(diff::CodeDiff) = diff.changed

issame(diff::CodeDiff) = isempty(DeepDiffs.added(diff)) && isempty(DeepDiffs.removed(diff))

Base.:(==)(d1::CodeDiff, d2::CodeDiff) = DeepDiffs.fieldequal(d1, d2)

Base.show(io::IO, ::MIME"text/plain", diff::CodeDiff) = side_by_side_diff(io, diff)

function Base.show(io::IO, diff::CodeDiff)
    xlines = split(diff.before, '\n')
    ylines = split(diff.after, '\n')
    DeepDiffs.visitall(diff) do idx, state, last
        if state === :removed
            printstyled(io, "- ", xlines[idx], color=:red)
        elseif state === :added
            printstyled(io, "+ ", ylines[idx], color=:green)
        elseif state === :changed
            printstyled(io, "~ ", color=:yellow)
            io_buf = IOBuffer()
            io_ctx = IOContext(io_buf, io)
            Base.show(io_ctx, diff.changed[idx][3])
            printstyled(io, String(take!(io_buf))[2:end-1])  # unquote the line diff
        else
            print(io, "  ", xlines[idx])
        end
        !last && println(io)
    end
end


"""
    optimize_line_changes!(diff::CodeDiff; dist=Levenshtein(), tol=0.7)

Merges consecutive line removals+additions into single line changes in `diff`, when they
are within the `tol`erance of the normalized string `dist`ance.

This does not aim to produce an optimal `CodeDiff`, but simply improve its display.
"""
function optimize_line_changes!(diff::CodeDiff; dist=StringDistances.Levenshtein(), tol=0.7)
    xlines = split(diff.before, '\n')
    ylines = split(diff.after, '\n')

    empty!(diff.changed)
    empty!(diff.ignore_added)
    previously_removed = Vector{Int}()
    added_before = Vector{Int}()
    removed_start = 1
    iadded = 1

    DeepDiffs.visitall(diff.diff) do idx, state, _
        if state == :removed
            # Removed lines are always iterated first, so they are compared against added lines
            push!(previously_removed, idx)
        elseif state == :added
            iadded += 1
            changed = false
            for (li, removed_line) in enumerate(previously_removed[removed_start:end])
                if StringDistances.compare(xlines[removed_line], ylines[idx], dist) ≥ tol
                    # `(lines added before this changed line, ylines idx, change diff)`
                    diff.changed[removed_line] =
                        (copy(added_before), idx, DeepDiffs.deepdiff(xlines[removed_line], ylines[idx]))
                    if !isempty(added_before)
                        push!(diff.ignore_added, added_before...)
                        empty!(added_before)
                    end
                    push!(diff.ignore_added, idx)
                    removed_start += li  # The next added lines will start from the next removed line
                    changed = true
                    break
                end
            end
            !changed && push!(added_before, idx)
        else
            # Treat conserved lines as a "reset" point
            empty!(previously_removed)
            empty!(added_before)
            removed_start = 1
        end
    end

    return diff
end


function DeepDiffs.visitall(f, diff::CodeDiff)
    DeepDiffs.visitall(diff.diff) do idx, state, last
        if state == :removed
            if haskey(diff.changed, idx)
                added_lines_before, _, _ = diff.changed[idx]
                for line_idx in added_lines_before
                    f(line_idx, :added, false)
                end
                f(idx, :changed, last)
            else
                f(idx, :removed, last)
            end
        elseif state == :added
            idx ∉ diff.ignore_added && f(idx, state, last)
        else
            f(idx, state, last)
        end
    end
end
