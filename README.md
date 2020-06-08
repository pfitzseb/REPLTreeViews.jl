# REPLTreeViews.jl

This package provides an experimental macro to interactively show complex data structures in the REPL.

Use `@ishow` to show the argument:
```
julia> @ishow Dict(:a => rand(10), :b => Dict(:c => 3))
Dict{Symbol,Any}
 ▼  a
    ▼  Array{Float64,1}
          0.6010674310215398
          0.1621627174514002
          0.9886458128892404
          0.3731520463002518
          0.7318310542335174
          0.4109065883177705
          0.09802040153654223
          0.25096526653794693
          0.6469920970392866
          0.9278104891830838
[▼] b
    ▶  Dict{Symbol,Int64}
```

You can navigate with the cursor keys, expand/collapse items with Enter, and quit the interactive display with `q`.