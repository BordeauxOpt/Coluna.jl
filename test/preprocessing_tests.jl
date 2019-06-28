function preprocessing_tests()
    @testset "play gap with preprocessing" begin
        play_gap_with_preprocessing_tests()
    end
    @testset "Preprocessing with random instances" begin
        random_instances_tests()
    end
end

function gen_random_small_gap_instance()
    nb_jobs = rand(7:15)
    nb_machs = rand(2:3)
    data = CLD.GeneralizedAssignment.Data(nb_machs, nb_jobs)
    for m in 1:nb_machs
        data.capacity[m] = rand(100:120)
    end
    avg_weight = sum(data.capacity)/nb_jobs
    for j in 1:nb_jobs, m in 1:nb_machs
        data.cost[j,m] = rand(1:10)
    end
    for j in 1:nb_jobs, m in 1:nb_machs
        data.weight[j,m] = Int(ceil(0.1*rand(9:25)*avg_weight))
    end
    return data
end

function play_gap_with_preprocessing_tests()
    data = CLD.GeneralizedAssignment.data("play2.txt")
    coluna = JuMP.with_optimizer(
        CL.Optimizer, default_optimizer = with_optimizer(GLPK.Optimizer),
        params = CL.Params(
            ; global_strategy = CL.GlobalStrategy(CL.BnPnPreprocess,
            CL.SimpleBranching, CL.DepthFirst)
    ))
    problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)
    JuMP.optimize!(problem)
    @test abs(JuMP.objective_value(problem) - 75.0) <= 0.00001
    @test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.OPTIMAL
    @test CLD.GeneralizedAssignment.print_and_check_sol(data, problem, x)
end

function random_instances_tests()
    for problem_idx in 1:10
        test_random_gap_instance()
    end
    return
end

function test_random_gap_instance()
    data = gen_random_small_gap_instance()
    coluna = JuMP.with_optimizer(CL.Optimizer,
        default_optimizer = with_optimizer(GLPK.Optimizer),
        params = CL.Params(; global_strategy = CL.GlobalStrategy(CL.BnPnPreprocess,
           CL.NoBranching, CL.DepthFirst)
        )
    )
        
    problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)
    #we flip a coin to decide if we add a branching constraint
    if rand(1:2) == 1
        j = rand(1:nb_jobs)
        m = rand(1:nb_mach)
        if rand(1:2) == 1 
	    @constraint(problem, random_br, x[j,m] <= 0)
	else 
	    @constraint(problem, random_br, x[j,m] >= 1)
	end
    end
    JuMP.optimize!(problem)

    if MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.INFEASIBLE
        coluna = JuMP.with_optimizer(CL.Optimizer,
                    default_optimizer = with_optimizer(GLPK.Optimizer)
                 )
        problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)
        JuMP.optimize!(problem)
        @test MOI.get(problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.INFEASIBLE
    else
        coluna_optimizer = problem.moi_backend.optimizer
        master = CL.getmaster(coluna_optimizer.inner.re_formulation)
        for (moi_index, var_id) in coluna_optimizer.varmap
            var = CL.getvar(master, var_id)
            if CL.getcurlb(var) == CL.getcurub(var)
                var_name = CL.getname(var)
                m = parse(Int, split(split(var_name, ",")[1], "[")[2])
                j = parse(Int, split(split(var_name, ",")[2], "]")[1])
                forbidden_machs = CL.getcurlb(var) == 0 ? [m] : [mach_idx for mach_idx in data.machines if mach_idx != m]
                modified_data = deepcopy(data)
                for mach_idx in forbidden_machs
                    modified_data.weights[j,mach_idx] = modified_data.capacity[mach_idx] + 1
	        end
                coluna = JuMP.with_optimizer(CL.Optimizer,
                    default_optimizer = with_optimizer(GLPK.Optimizer)
                )
                modified_problem, x, dec = CLD.GeneralizedAssignment.model(modified_data, coluna)
                JuMP.optimize!(modified_problem)
                @test MOI.get(modified_problem.moi_backend.optimizer, MOI.TerminationStatus()) == MOI.INFEASIBLE
	    end
        end
    end
    return
end
