function add_watch_entry!(state::DebuggerState, cmd::AbstractString)
    expr = Base.parse_input_line(cmd)
    if isexpr(expr, :error) || isexpr(expr, :incomplete)
        err_repl(state, "ERROR: syntax: ", expr.args[1], "\n")
        return false
    end
    push!(state.watch_list, expr)
    return true
end

function show_watch_list(io, state::DebuggerState)
    frame = active_frame(state)
    outbuf = IOContext(IOBuffer(), io)

    for (i, expr) in enumerate(state.watch_list)
        vars = filter(v -> v.name != Symbol(""), JuliaInterpreter.locals(frame))
        eval_expr = Expr(:let,
            Expr(:block, map(x->Expr(:(=), x...), [(v.name, v.value) for v in vars])...),
            expr)
        res = try
            Core.eval(moduleof(frame), eval_expr)
        catch err
            err
        end
        print(outbuf, "$i] $expr: "); show(outbuf, res); println(outbuf)
    end
    print(io, String(take!(outbuf.io)))
    println(io)
end

clear_watch_list!(state::DebuggerState) = empty!(state.watch_list)
function clear_watch_list!(state::DebuggerState, i::Int)
    if !checkbounds(Bool, state.watch_list, i)  
        printstyled(stderr, "ERROR: watch entry $i does not exist\n\n"; color=Base.error_color())
        return
    end
    deleteat!(state.watch_list, i)
end