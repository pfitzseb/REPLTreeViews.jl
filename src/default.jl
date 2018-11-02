using TreeViews, IterTools
# Dicts
TreeViews.hastreeview(::AbstractDict) = true
TreeViews.numberofnodes(d::AbstractDict) = length(d)
TreeViews.nodelabel(io::IO, d::AbstractDict, i::Integer, ::MIME"text/plain") = print(io, nth(keys(d), i))
TreeViews.treenode(d::AbstractDict, i::Integer) = d[nth(keys(d), i)]

# Vectors
TreeViews.hastreeview(::AbstractVector) = true
TreeViews.numberofnodes(d::AbstractVector) = length(d)
TreeViews.nodelabel(io::IO, d::AbstractVector, i::Integer, ::MIME"text/plain") = print(io, "")
TreeViews.treenode(d::AbstractVector, i::Integer) = d[i]
