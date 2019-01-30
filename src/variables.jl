@hl mutable struct SubprobVar <: Variable
    # ```
    # To represent global lower bound on sp variable primal value
    # Aggregated bound in master
    # ```
    global_lb::Float

    # ```
    # To represent global upper bound on sp variable primal value
    # Aggregated bound in master
    # ```
    global_ub::Float

    # ```
    # Current global bound values (aggregated in master)
    # Used in preprocessing
    # ```
    cur_global_lb::Float
    cur_global_ub::Float

    # ```
    # Represents the master membership in the master constraints as a map where:
    # - The key is the index of the master constraint including this as member,
    # - The value is the corresponding coefficient.
    # ```
    master_constr_coef_map::Dict{Constraint, Float} # Constraint -> MasterConstr

    # ```
    # Represents the master membership in column solutions as map where:
    # - The key is the index of a column whose solutions includes this as member,
    # - The value is the variable value in the corresponding pricing solution.
    # ```
    master_col_coef_map::Dict{Variable, Float} # Variable -> MasterColumn
end

function SubprobVarBuilder(counter::VarConstrCounter, name::String, costrhs::Float,
        sense::Char, vc_type::Char, flag::Char, directive::Char, priority::Float,
        lowerBound::Float, upperBound::Float, globallb::Float, globalub::Float,
         curgloballb::Float, curglobalub::Float)

    return tuplejoin(VariableBuilder(counter, name, costrhs, sense, vc_type, flag,
            directive, priority, lowerBound, upperBound), globallb, globalub,
            curgloballb, curglobalub, Dict{Constraint,Float}(),
            Dict{Variable,Float}())
end

function bounds_changed(var::SubprobVar)
    changed = @callsuper bounds_changed(var::Variable)
    return (changed || (var.cur_global_lb != var.global_lb)
            || (var.cur_global_ub != var.global_ub))
end

function set_default_currents(var::SubprobVar)
    @callsuper set_default_currents(var::Variable)
    var.cur_global_lb = var.global_lb
    var.cur_global_ub = var.global_ub
end

function set_global_bounds(var::SubprobVar, multiplicity_lb::Float,
                           multiplicity_ub::Float)
    var.global_lb = var.lower_bound * multiplicity_lb
    var.global_ub = var.upper_bound * multiplicity_ub
end

@hl mutable struct MasterVar <: Variable
    # ```
    # Holds the contribution of the master variable in the lagrangian dual bound
    # ```
    dualBoundContrib::Float
end

MasterVarBuilder(v::Variable, counter::VarConstrCounter) = tuplejoin(
        VariableBuilder(v, counter), (0.0,))

function MasterVarBuilder(counter::VarConstrCounter, name::String, costrhs::Float,
        sense::Char, vc_type::Char, flag::Char, directive::Char, priority::Float,
        lowerBound::Float, upperBound::Float)

    return tuplejoin(VariableBuilder(counter, name, costrhs, sense, vc_type,
            flag, directive, priority, lowerBound, upperBound), 0.0)
end

fract_part(val::Float) = (abs(val - round(val)))

function is_value_integer(val::Float, tolerance::Float)
    return (fract_part(val) <= tolerance)
end
