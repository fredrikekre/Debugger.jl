module Debugger

using Markdown
using Base.Meta: isexpr
using REPL
using REPL.LineEdit
using REPL.REPLCompletions

using JuliaInterpreter: JuliaInterpreter, Frame, @lookup, FrameCode, BreakpointRef, debug_command, leaf, root

using JuliaInterpreter: pc_expr, moduleof, linenumber, extract_args,
                        root, caller, whereis, get_return, nstatements

const SEARCH_PATH = []
function __init__()
    append!(SEARCH_PATH,[joinpath(Sys.BINDIR,"../share/julia/base/"),
            joinpath(Sys.BINDIR,"../include/")])
    return nothing
end

export @enter, @run, break_on_error

include("LineNumbers.jl")
using .LineNumbers: SourceFile, compute_line

mutable struct DebuggerState
    frame::Union{Nothing, Frame}
    level::Int
    broke_on_error::Bool
    repl
    terminal
    main_mode
    julia_prompt::Ref{LineEdit.Prompt}
    standard_keymap
    overall_result
end
DebuggerState(stack, repl, terminal) = DebuggerState(stack, 1, false, repl, terminal, nothing, Ref{LineEdit.Prompt}(), nothing, nothing)
DebuggerState(stack, repl) = DebuggerState(stack, repl, nothing)

function active_frame(state)
    frame = state.frame
    for i in 1:(state.level - 1)
        frame = caller(frame)
    end
    @assert frame !== nothing
    return frame
end

break_on_error(v::Bool) = JuliaInterpreter.break_on_error[] = v

include("locationinfo.jl")
include("repl.jl")
include("commands.jl")
include("printing.jl")

function _make_frame(mod, arg)
    args = try
        extract_args(mod, arg)
    catch e
        return :(throw($e))
    end
    quote
        theargs = $(esc(args))
        frame = JuliaInterpreter.enter_call_expr(Expr(:call,theargs...))
        frame = JuliaInterpreter.maybe_step_through_wrapper!(frame)
        JuliaInterpreter.maybe_next_call!(frame)
        frame
    end
end

macro make_frame(arg)
    _make_frame(__module__, arg)
end

macro enter(arg)
    quote
        let frame = $(_make_frame(__module__,arg))
            RunDebugger(frame)
        end
    end
end

macro run(arg)
    quote
        let frame = $(_make_frame(__module__,arg))
            RunDebugger(frame; initial_continue=true)
        end
    end
end

end # module
