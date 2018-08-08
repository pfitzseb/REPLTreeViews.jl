# TODO: fix width limiting
# TODO: introducing vertical scrolling so nothing breaks when the current Tree is
#       higher than the terminal has lines
using REPL

include("utils.jl")

export @ishow

mutable struct Tree{F}
    head
    children_gen::F
    children::Vector

    materialized::Bool
    expanded::Bool
    options::Vector{String}

    pagesize::Int
    pageoffset::Int

    selected
    lastHeight::Int

    cursor
end

function Tree(head, children::Vector{<:Any})
    Tree(head, () -> (), children, true, false, String[], length(children), 0, nothing, 0, 0)
end

function Tree(head, f::Function)
    Tree(head, f, Any[], false, false, String[], length(f()), 0, nothing, 0, 0)
end

function children(t::Tree)
    if t.materialized
        t.children
    else
        tmp = t.children_gen()
        t.children = tmp
        t.materialized = true
        tmp
    end
end

toggle(t::Tree) = (t.expanded = !t.expanded)

showmethod(T) = which(show, (IO, T))

getfield′(x, f) = isdefined(x, f) ? getfield(x, f) : Text("#undef")

function defaultrepr(x; smethod=false)
    if smethod && showmethod(typeof(x)) ≠ showmethod(Any)
        b = IOBuffer()
        print(b, Text(io -> show(IOContext(io, :limit => true), MIME"text/plain"(), x)))
        Text(String(take!(b)))
    else
        fields = fieldnames(typeof(x))

        if isempty(fields)
            Tree(string(typeof(x), "()"), [])
        else
            Tree(string(typeof(x)),
                 [Tree(string(f), [defaultrepr(getfield′(x, f), smethod=true)]) for f in fields])
        end
    end
end

function generateTreeView(x)
    header = Text(sprint(treelabel, x, MIME"text/plain"()))

    numberofnodes(x) == 0 && return Tree(header, [])

    genchildren = function ()
      children = Any[]
      for i in 1:numberofnodes(x)
        node = treenode(x, i)

        cheader = sprint(nodelabel, x, i, MIME"text/plain"())
        if isempty(cheader)
          push!(children, hastreeview(node) ? generateTreeView(node) : node)
        elseif node === nothing
          push!(children, Text(cheader))
        else
          # would be nicer if this were a SubTree, but works fine as is
          push!(children, Tree(Text(cheader),
                               () -> [(hastreeview(node) ?
                                       generateTreeView(node) :
                                       Text(io -> show(IOContext(io, :limit => true), MIME"text/plain"(), node)))]))
      end
      end
      children
    end

    return Tree(header, genchildren)
end

macro ishow(x)
    :(ishow($(esc(x))))
end

function ishow(x)
    request(hastreeview(x) ? generateTreeView(x) : defaultrepr(x))
end

const INDENTSIZE = 3

indent(level) = " "^INDENTSIZE

function printTreeChild(buf::IOBuffer, child::Tree, cursor, term_width::Int; level::Int = 0)
    cur = cursor == -1
    symbol = length(children(child)) > 0 ? child.expanded ? "▼" : "▶" : " "

    cur ? print(buf, "[$symbol] ") : print(buf, " $symbol  ")
    if child.expanded
        # print Tree with additional nesting, but without an active cursor
        # init=true assures that the Tree printing doesn't mess with anything
        cursor = printMenu(buf, child, cursor; init=true, level = level)
    else
        # only print header
        tb = IOBuffer()
        print(tb, child.head)
        s = String(take!(tb))
        print(buf, join(limitLineLength([s], term_width-(2*level + 10)), '\n'))
    end

    cursor
end

function limitLineLength(strs, term_width)
    outstrs = String[]
    for str in strs
        if length(str) >= term_width
            while length(str) >= term_width
                push!(outstrs, str[1:term_width])
                str = str[max(term_width, 1):end]
            end
        else
            push!(outstrs, str)
        end
    end
    outstrs
end

function writeChild(buf::IOBuffer, t::Tree, idx::Int, cursor, term_width::Int; level::Int = 0)
    tmpbuf = IOBuffer()

    child = children(t)[idx]

    cursor -= 1
    cur = cursor == -1
    if child isa Tree
        cursor = printTreeChild(tmpbuf, child, cursor, term_width, level = level)
    else
        # if there's a specially designed show method we fall back to that
        if showmethod(typeof(child)) ≠ showmethod(Any)
            cur ? print(buf, "[ ] ") : print(buf, "    ")
            b = IOBuffer()
            print(b, Text(io -> show(IOContext(io, :limit => true), MIME"text/plain"(), child)))
            s = join(limitLineLength(split(String(take!(b)), '\n'), term_width-(2*level + 10)), "\n"*indent(level))
            print(tmpbuf, s)
        else
            d = defaultrepr(child)
            if d isa Tree
                cursor = printTreeChild(tmpbuf, d, cursor, term_width, level = level)
            else
                b = IOBuffer()
                print(b, d)
                s = join(limitLineLength(split(String(take!(b)), '\n'), term_width-(2*level + 10)), "\n"*indent(level))
                print(tmpbuf, s)
            end
        end
    end

    str = String(take!(tmpbuf))

    str = join(split(str, '\n'), "\n"*indent(level))

    print(buf, str)

    cursor
end

function printMenu(out, m::Tree, cursor; init::Bool=false, level=0)
    buf = IOBuffer()

    if init
        m.pageoffset = 0
    else
        # move cursor to beginning of current menu
        print(buf, "\x1b[999D\x1b[$(m.lastHeight)A")
        # clear display until end of screen
        print(buf, "\x1b[0J")
    end

    term_width = REPL.Terminals.width(terminal)

    # print header
    tb = IOBuffer()
    print(tb, m.head)
    println(buf, join(limitLineLength([String(take!(tb))], term_width-(2*level + 10)), '\n'))
    cs = children(m)

    for i in 1:length(cs)
        print(buf, "\x1b[2K")

        cursor = writeChild(buf, m, i, cursor, term_width, level=level+1)

        # dont print an \r\n on the last line
        i != (m.pagesize+m.pageoffset) && print(buf, "\r\n")
    end

    str = String(take!(buf))

    m.lastHeight = count(c -> c == '\n', str)

    print(out, str)
    cursor
end

cancel(t::Tree) = nothing

request(m::Tree) = request(terminal, m)

function request(term::REPL.Terminals.TTYTerminal, m::Tree)
    global mem
    mem = Dict{Any, Any}()

    cursor = 0

    printMenu(term.out_stream, m, cursor, init=true)

    raw_mode_enabled = enableRawMode(term)
    raw_mode_enabled && print(term.out_stream, "\x1b[?25l") # hide the cursor
    try
        while true
            c = readKey(term.in_stream)

            currentItem, _ = findItem(m, cursor)

            if c == Int(ARROW_UP)
                if cursor > 0
                    cursor -= 1
                end
            elseif c == Int(ARROW_DOWN)
                cursor += 1
            elseif c == 13 # <enter>
                # will break if pick returns true
                currentItem isa Tree && toggle(currentItem)
            elseif c == UInt32('q')
                cancel(m)
                break
            elseif c == 3 # ctrl-c
                cancel(m)
                break
            else
                # will break if keypress returns true
                keypress(m, c) && break
            end

            printMenu(term.out_stream, m, cursor)
        end
    finally
        # always disable raw mode even even if there is an
        #  exception in the above loop
        if raw_mode_enabled
            print(term.out_stream, "\x1b[?25h") # unhide cursor
            disableRawMode(term)
        end
    end
    println(term.out_stream)

    return m.selected
end

function findItem(t::Tree, cursor)
    i = nothing
    for c in children(t)
        if cursor == 0
            return c, cursor
        end

        cursor -= 1

        if c isa Tree && c.expanded
            i, cursor = findItem(c, cursor)
        end

        if i ≠ nothing
            return i, cursor
        end
    end
    return i, cursor
end

function toggleall(t::Tree, expand)
    for child in children(t)
        if child isa Tree
            child.expanded = expand
            toggleall(child, expand)
        end
    end
end

function keypress(t::Tree, key::UInt32)
    if key == UInt32('e') || key == UInt32('E')
        toggleall(t, true)
    elseif key == UInt32('c') || key == UInt32('C')
        toggleall(t, false)
    end
    false # don't break
end
