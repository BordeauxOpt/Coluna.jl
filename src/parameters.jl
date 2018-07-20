@with_kw type Params
    max_num_nodes::Int = 5
    open_nodes_limit::Int = 5
    mip_tolerance_integrality::Float = 1e-5
    cut_up::Float = 1e+75
    cut_lo::Float = -Inf
end
