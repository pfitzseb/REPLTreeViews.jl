module REPLTreeViews

using TreeViews: numberofnodes, treelabel, treenode, hastreeview, nodelabel

struct REPLTreeViewsDisplay <: AbstractDisplay end

function Base.display(::REPLTreeViewsDisplay, x)
    if hastreeview(x)
        println()
        printMenu(stdout, generateTreeView(x), 999)
        println(stdout)
    else
        # fall through to the Displays lower in the display stack
        throw(MethodError(display, "nope"))
    end
end

terminal = nothing  # The user terminal
function __init__()
    global terminal
    terminal = REPL.Terminals.TTYTerminal(get(ENV, "TERM", Sys.iswindows() ? "" : "dumb"), stdin, stdout, stderr)
    pushdisplay(REPLTreeViewsDisplay())
end

include("renderer.jl")
include("default.jl")

end # module
