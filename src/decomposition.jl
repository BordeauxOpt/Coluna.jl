set_glob_art_var(f::Formulation, is_pos::Bool) = setvar!(
    f, string("global_", (is_pos ? "pos" : "neg"), "_art_var"),
    MasterArtVar; cost = (getobjsense(f) == MinSense ? 100000.0 : -100000.0),
    lb = 0.0, ub = Inf, kind = Continuous, sense = Positive
)

function create_local_art_vars!(masterform::Formulation)
    matrix = getcoefmatrix(masterform)
    constrs = filter(
        v -> getduty(v) == MasterConvexityConstr, getconstrs(masterform)
    )
    for (constr_id, constr) in getconstrs(masterform)
        var = setvar!(
            masterform, string("local_art_of_", getname(constr)),
            MasterArtVar;
            cost = (getobjsense(masterform) == MinSense ? 10000.0 : -10000.0),
            lb = 0.0, ub = Inf, kind = Continuous, sense = Positive
        )
        if getsense(getcurdata(constr)) == Greater
            matrix[constr_id, getid(var)] = 1.0
        elseif getsense(getcurdata(constr)) == Less
            matrix[constr_id, getid(var)] = -1.0
        end
    end
    return
end

function create_global_art_vars!(masterform::Formulation)
    global_pos = set_glob_art_var(masterform, true)
    global_neg = set_glob_art_var(masterform, false)
    matrix = getcoefmatrix(masterform)
    constrs = filter(_active_master_rep_orig_constr_, getconstrs(masterform))
    for (constr_id, constr) in constrs
        if getsense(getcurdata(constr)) == Greater
            matrix[constr_id, getid(global_pos)] = 1.0
        elseif getsense(getcurdata(constr)) == Less
            matrix[constr_id, getid(global_neg)] = -1.0
        end
    end
end

function instantiatemaster!(
    prob::Problem, reform::Reformulation, ::Type{BD.Master}, 
    ::Type{BD.DantzigWolfe}
)
    form = Formulation{DwMaster}(
        prob.form_counter; parent_formulation = reform,
        obj_sense = getobjsense(get_original_formulation(prob))
    )
    setmaster!(reform, form)
    return form
end

function instantiatemaster!(
    prob::Problem, reform::Reformulation, ::Type{BD.Master}, ::Type{BD.Benders}
)
    masterform = Formulation{BendersMaster}(
        prob.form_counter; parent_formulation = reform,
        obj_sense = getobjsense(get_original_formulation(prob))
    )
    setmaster!(reform, masterform)
    return masterform
end

function instantiatesp!(
    prob::Problem, reform::Reformulation, masterform::Formulation{DwMaster}, 
    ::Type{BD.DwPricingSp}, ::Type{BD.DantzigWolfe}
)
    spform = Formulation{DwSp}(
        prob.form_counter; parent_formulation = masterform,
        obj_sense = getobjsense(masterform)
    )
    add_dw_pricing_sp!(reform, spform)
    return spform
end

function instantiatesp!(
    prob::Problem, reform::Reformulation, masterform::Formulation{BendersMaster}, 
    ::Type{BD.BendersSepSp}, ::Type{BD.Benders}
)
    spform = Formulation{BendersSp}(
        prob.form_counter; parent_formulation = masterform,
        obj_sense = getobjsense(masterform)
    )
    add_benders_sep_sp!(reform, spform)
    return spform
end

# Master of Dantzig-Wolfe decomposition

# returns the duty of a variable and whether it is explicit according to the 
# type of formulation it belongs and the type of formulation it will clone in.
_varexpduty(F, BDF, BDD) = error("Cannot deduce duty of original variable in $F annoted in $BDF using $BDD.")
_varexpduty(::Type{DwMaster}, ::Type{BD.DwPricingSp}, ::Type{BD.DantzigWolfe}) = MasterRepPricingVar, false
_varexpduty(::Type{DwMaster}, ::Type{BD.Master}, ::Type{BD.DantzigWolfe}) = MasterPureVar, true

function instantiate_orig_vars!(
    masterform::Formulation{DwMaster}, origform::Formulation, 
    annotations::Annotations, mast_ann
)
    vars_per_ann = annotations.vars_per_ann
    for (ann, vars) in vars_per_ann
        formtype = BD.getformulation(ann)
        dectype = BD.getdecomposition(ann)
        for (id, var) in vars
            duty, explicit = _varexpduty(DwMaster, formtype, dectype)
            clonevar!(masterform, var, duty, is_explicit = explicit)
        end
    end
    return
end

function instantiate_orig_constrs!(
    masterform::Formulation{DwMaster}, origform::Formulation{Original}, 
    annotations::Annotations, mast_ann
)
    !haskey(annotations.constrs_per_ann, mast_ann) && return
    constrs = annotations.constrs_per_ann[mast_ann]
    for (id, constr) in constrs
        cloneconstr!(masterform, constr, MasterMixedConstr) # TODO distinguish Pure versus Mixed
    end
    return
end

function create_side_vars_constrs!(
    masterform::Formulation{DwMaster}, origform::Formulation{Original}, 
    annotations::Annotations
)
    coefmatrix = getcoefmatrix(masterform)
    for spform in masterform.parent_formulation.dw_pricing_subprs
        spuid = getuid(spform)
        ann = get(annotations, spform)
        setupvars = filter(var -> getduty(var) == DwSpSetupVar, getvars(spform))
        @assert length(setupvars) == 1
        setupvar = collect(values(setupvars))[1]
        clonevar!(masterform, setupvar, MasterRepPricingSetupVar, is_explicit = false)
        # create convexity constraint
        lb_mult = Float64(BD.getlowermultiplicity(ann))
        name = string("sp_lb_", spuid)
        lb_conv_constr = setconstr!(
            masterform, name, MasterConvexityConstr; 
            rhs = lb_mult, kind = Core, sense = Greater
        )
        masterform.parent_formulation.dw_pricing_sp_lb[spuid] = getid(lb_conv_constr)
        setincval!(getrecordeddata(lb_conv_constr), 100.0)
        setincval!(getcurdata(lb_conv_constr), 100.0)
        coefmatrix[getid(lb_conv_constr), getid(setupvar)] = 1.0

        ub_mult =  Float64(BD.getuppermultiplicity(ann))
        name = string("sp_ub_", spuid)
        ub_conv_constr = setconstr!(
            masterform, name, MasterConvexityConstr; rhs = ub_mult, 
            kind = Core, sense = Less
        )
        masterform.parent_formulation.dw_pricing_sp_ub[spuid] = getid(ub_conv_constr)
        setincval!(getrecordeddata(ub_conv_constr), 100.0)
        setincval!(getcurdata(ub_conv_constr), 100.0)       
        coefmatrix[getid(ub_conv_constr), getid(setupvar)] = 1.0
    end
    return
end

function create_artificial_vars!(masterform::Formulation{DwMaster})
    create_global_art_vars!(masterform)
    create_local_art_vars!(masterform)
    return
end

# Pricing subproblem of Danztig-Wolfe decomposition
function instantiate_orig_vars!(
    spform::Formulation{DwSp}, origform::Formulation{Original}, 
    annotations::Annotations, sp_ann
)
    !haskey(annotations.vars_per_ann, sp_ann) && return
    vars = annotations.vars_per_ann[sp_ann]
    for (id, var) in vars
        # An original variable annoted in a subproblem is a DwSpPureVar
        clonevar!(spform, var, DwSpPricingVar)
    end
    return
end

function instantiate_orig_constrs!(
    spform::Formulation{DwSp}, origform::Formulation{Original}, 
    annotations::Annotations, sp_ann
)
    !haskey(annotations.constrs_per_ann, sp_ann) && return
    constrs = annotations.constrs_per_ann[sp_ann]
    for (id, constr) in constrs
        cloneconstr!(spform, constr, DwSpPureConstr)
    end
    return
end

function create_side_vars_constrs!(
    spform::Formulation{DwSp}, origform::Formulation{Original}, 
    annotations::Annotations
)
    name = "PricingSetupVar_sp_$(getuid(spform))"
    setvar!(
    spform, name, DwSpSetupVar; cost = 0.0, lb = 1.0, ub = 1.0, 
        kind = Continuous, sense = Positive, is_explicit = true
    ) 
    return
end

function _dutyexpofbendmastvar(
    var::Variable, annotations::Annotations, origform::Formulation{Original}
)
    orig_coef = getcoefmatrix(origform)
    for (constrid, coef) in orig_coef[:, getid(var)]
        constr_ann = annotations.ann_per_constr[constrid]
        #if coef != 0 && BD.getformulation(constr_ann) == BD.Benders  # TODO use haskey instead testing != 0
        if BD.getformulation(constr_ann) == BD.BendersSepSp 
            return MasterBendFirstStageVar, true
        end
    end
    return MasterPureVar, true
end

# Master of Benders decomposition

function instantiate_orig_vars!(
    masterform::Formulation{BendersMaster}, origform::Formulation{Original}, 
    annotations::Annotations, mast_ann
)
    !haskey(annotations.vars_per_ann, mast_ann) && return
    vars = annotations.vars_per_ann[mast_ann]
    for (id, var) in vars
        duty, explicit = _dutyexpofbendmastvar(var, annotations, origform)
        clonevar!(masterform, var, duty, is_explicit = explicit)
    end
    return
end

function _dutyexpofbendmastconstr(
    constr::Constraint, annotations::Annotations, 
    origform::Formulation{Original}
)
    #==orig_coef = getcoefmatrix(origform)
    for (varid, coef) in orig_coef[getid(constr), :]
        var_ann = annotations.ann_per_var[varid]
        if BD.getformulation(var_ann) == BD.BendersSepSp 
            return MasterRepBendSpTechnologicalConstr, false
        end
    end ==# # All constr annotated for master are in master
    return MasterPureConstr, true
end

function instantiate_orig_constrs!(
    masterform::Formulation{BendersMaster}, origform::Formulation{Original}, 
    annotations::Annotations, mast_ann
)
    !haskey(annotations.constrs_per_ann, mast_ann) && return
    constrs = annotations.constrs_per_ann[mast_ann]
    for (id, constr) in constrs
        duty, explicit = _dutyexpofbendmastconstr(constr, annotations, origform)
        cloneconstr!(masterform, constr, duty, is_explicit = explicit)
    end
    return
end

function create_side_vars_constrs!(
    masterform::Formulation{BendersMaster}, origform::Formulation{Original}, 
    annotations::Annotations
)
    coefmatrix = getcoefmatrix(masterform)
    
    for spform in masterform.parent_formulation.benders_sep_subprs
        nu_var = collect(values(filter(
            var -> getduty(var) == BendSpSlackSecondStageCostVar, 
            getvars(spform)
        )))[1]
        
        name = "η[$(split(getname(nu_var), "[")[end])"
        setvar!(
            masterform, name, MasterBendSecondStageCostVar; cost = 1.0,
            lb = getperenelb(nu_var), ub = getpereneub(nu_var), 
            kind = Continuous, sense = Free, is_explicit = true, 
            id = getid(nu_var)
        )                                 
    end
    return
end

create_artificial_vars!(masterform::Formulation{BendersMaster}) = return

function instantiate_orig_vars!(
    spform::Formulation{BendersSp}, origform::Formulation{Original}, 
    annotations::Annotations, sp_ann
)
    if haskey(annotations.vars_per_ann, sp_ann)
        vars = annotations.vars_per_ann[sp_ann]
        for (id, var) in vars
            clonevar!(spform, var, BendSpSepVar, cost = 0.0)
        end
    end
    masterform = getmaster(spform)
    mast_ann = get(annotations, masterform)
    if haskey(annotations.vars_per_ann, mast_ann)
        vars = annotations.vars_per_ann[mast_ann]
        for (id, var) in vars
            duty, explicit = _dutyexpofbendmastvar(var, annotations, origform)
            if duty == MasterBendFirstStageVar
                name = "μ[$(split(getname(var), "[")[end])"
                mu = setvar!(
                    spform, name, BendSpSlackFirstStageVar; 
                    cost = getcurcost(var), lb = getcurlb(var), 
                    ub = getcurub(var), kind = Continuous, 
                    sense = getcursense(var), is_explicit = true, id = id
                )
            end
        end
    end
    return
end

function _dutyexpofbendspconstr(constr, annotations::Annotations, origform)
    orig_coef = getcoefmatrix(origform)
    for (varid, coef) in orig_coef[getid(constr), :]
        var_ann = annotations.ann_per_var[varid]
        if BD.getformulation(var_ann) == BD.Master
            return BendSpTechnologicalConstr, true
        end
    end
    return BendSpPureConstr, true
end

function instantiate_orig_constrs!(
    spform::Formulation{BendersSp}, origform::Formulation{Original}, 
    annotations::Annotations, sp_ann
)
    !haskey(annotations.constrs_per_ann, sp_ann) && return
    constrs = annotations.constrs_per_ann[sp_ann]
    for (id, constr) in constrs
        duty, explicit  = _dutyexpofbendspconstr(constr, annotations, origform)
        cloneconstr!(spform, constr, duty, is_explicit = explicit)
    end
    return
end

function create_side_vars_constrs!(
    spform::Formulation{BendersSp}, origform::Formulation{Original}, 
    annotations::Annotations
)
    sp_has_second_stage_cost = false
    sp_vars = filter(var -> getduty(var) == BendSpSepVar, getvars(spform))
    global_costprofit_ub = 0.0
    global_costprofit_lb = 0.0
    for (var_id, var) in sp_vars
       orig_var = getvar(origform, var_id)
       cost =  getperenecost(orig_var)
        if cost > 0.00001 
             global_costprofit_ub += cost * getcurub(orig_var)
             global_costprofit_lb += cost * getcurlb(orig_var)
        elseif cost < - 0.00001  
             global_costprofit_ub += cost * getcurlb(orig_var)
             global_costprofit_lb += cost * getcurub(orig_var)
        end
    end

    if global_costprofit_ub > 0.00001  || global_costprofit_lb < - 0.00001 
        sp_has_second_stage_cost = true
    end

    if sp_has_second_stage_cost
        sp_coef = getcoefmatrix(spform)
        sp_id = getuid(spform)
        # Cost constraint
        nu = setvar!(
            spform, "ν[$sp_id]", BendSpSlackSecondStageCostVar; cost = 1.0,
            lb = - global_costprofit_lb , ub = global_costprofit_ub, 
            kind = Continuous, sense = Free, is_explicit = true
        )
        setcurlb!(nu, 0.0)                                          
        setcurub!(nu, Inf)                                          

        cost = setconstr!(
            spform, "cost[$sp_id]", BendSpSecondStageCostConstr; rhs = 0.0, 
            kind = Core, sense = Greater, is_explicit = true
        )
        sp_coef[getid(cost), getid(nu)] = 1.0

        for (var_id, var) in sp_vars
            orig_var = getvar(origform, var_id)
            sp_coef[getid(cost), var_id] = - getperenecost(orig_var)         
        end
    end
    return
end

function assign_orig_vars_constrs!(
    form::Formulation, origform::Formulation{Original}, 
    annotations::Annotations, ann
)
    instantiate_orig_vars!(form, origform, annotations, ann)
    instantiate_orig_constrs!(form, origform, annotations, ann)
    clonecoeffs!(form, origform)
end

function getoptbuilder(prob::Problem, ann)
    if BD.getoptimizerbuilder(ann) != nothing
        return BD.getoptimizerbuilder(ann)
    end
    return prob.default_optimizer_builder
end

function buildformulations!(
    prob::Problem, annotations::Annotations, reform::Reformulation, parent, 
    node::BD.Root
)
    ann = BD.annotation(node)
    form_type = BD.getformulation(ann)
    dec_type = BD.getdecomposition(ann)
    masterform = instantiatemaster!(prob, reform, form_type, dec_type)
    store!(annotations, masterform, ann)
    origform = get_original_formulation(prob)
    assign_orig_vars_constrs!(masterform, origform, annotations, ann)
    for (id, child) in BD.subproblems(node)
        buildformulations!(prob, annotations, reform, node, child)
    end
    create_side_vars_constrs!(masterform, origform, annotations)
    create_artificial_vars!(masterform)
    initialize_optimizer!(masterform, getoptbuilder(prob, ann))
    initialize_optimizer!(origform, getoptbuilder(prob, ann))
    return
end

function buildformulations!(
    prob::Problem, annotations::Annotations, reform::Reformulation, 
    parent, node::BD.Leaf
)
    ann = BD.annotation(node)
    form_type = BD.getformulation(ann)
    dec_type = BD.getdecomposition(ann)
    masterform = getmaster(reform)
    spform = instantiatesp!(prob, reform, masterform, form_type, dec_type)
    store!(annotations, spform, ann)
    origform = get_original_formulation(prob)
    assign_orig_vars_constrs!(spform, origform, annotations, ann)
    create_side_vars_constrs!(spform, origform, annotations)
    initialize_optimizer!(spform, getoptbuilder(prob, ann))
    return
end

function reformulate!(
    prob::Problem, annotations::Annotations, strategy::GlobalStrategy
)
    decomposition_tree = annotations.tree                                       
    # Create reformulation
    reform = Reformulation(prob, strategy)
    set_re_formulation!(prob, reform)
    
    if decomposition_tree != nothing
        root = BD.getroot(decomposition_tree)
        buildformulations!(prob, annotations, reform, reform, root)
    end
    return
end

