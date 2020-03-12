function masteripheur_tests()
    infeasible_master_ip_heur_tests()
end

function ClA.run!(alg::ClA.SolveIpForm, reform::ClMP.Reformulation, input::ClA.NewOptimizationInput)
    master = ClMP.getmaster(reform)
    ipforminput = ClA.SolveIpFormInput(ClMP.ObjValues(master))
    return ClA.run!(alg, master, ipforminput)
end

function infeasible_master_ip_heur_tests()
    @testset "play gap" begin
        data = CLD.GeneralizedAssignment.data("play2.txt")

        # Apply directly master ip heuristic => infeasible        
        coluna = JuMP.optimizer_with_attributes(
            Coluna.Optimizer,
            "params" => CL.Params(
                solver = ClA.SolveIpForm()
            ),
            "default_optimizer" => GLPK.Optimizer
        )

        problem, x, dec = CLD.GeneralizedAssignment.model(data, coluna)

        JuMP.optimize!(problem)
        @test JuMP.objective_value(problem) == Inf
    end
end