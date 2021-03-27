function bound_unit()
    Primal = Coluna.AbstractPrimalSpace
    Dual = Coluna.AbstractDualSpace
    MinSense = Coluna.AbstractMinSense
    MaxSense = Coluna.AbstractMaxSense

    @testset "Bound" begin
        pb = Coluna.ColunaBase.Bound{Primal,MinSense}()
        @test pb == Inf
        @test getvalue(pb) == Inf
        
        pb = Coluna.ColunaBase.Bound{Primal,MaxSense}()
        @test pb == -Inf
        @test getvalue(pb) == -Inf
        
        db = Coluna.ColunaBase.Bound{Dual,MinSense}()
        @test db == -Inf
        @test getvalue(db) == -Inf
        
        db = Coluna.ColunaBase.Bound{Dual,MaxSense}()
        @test db == Inf
        @test getvalue(db) == Inf
        
        pb = Coluna.ColunaBase.Bound{Primal,MinSense}(100)
        @test pb == 100
        @test getvalue(pb) == 100
        @test typeof(float(db)) <: Float64

        db = Coluna.ColunaBase.Bound{Dual,MinSense}(-π)
        @test db == -π
        @test getvalue(db) == -π
    end

    @testset "isbetter" begin
        # In minimization, pb with value 10 is better than pb with value 15
        pb1 = Coluna.ColunaBase.Bound{Primal,MinSense}(10.0)
        pb2 = Coluna.ColunaBase.Bound{Primal,MinSense}(15.0)
        @test Coluna.ColunaBase.isbetter(pb1, pb2) == !Coluna.ColunaBase.isbetter(pb2, pb1) == true

        # In maximization, pb with value 15 is better than pb with value 10
        pb1 = Coluna.ColunaBase.Bound{Primal,MaxSense}(10.0)
        pb2 = Coluna.ColunaBase.Bound{Primal,MaxSense}(15.0)
        @test Coluna.ColunaBase.isbetter(pb2, pb1) == !Coluna.ColunaBase.isbetter(pb1, pb2) == true

        # In minimization, db with value 15 is better than db with value 10
        db1 = Coluna.ColunaBase.Bound{Dual,MinSense}(15.0)
        db2 = Coluna.ColunaBase.Bound{Dual,MinSense}(10.0)
        @test Coluna.ColunaBase.isbetter(db1, db2) == !Coluna.ColunaBase.isbetter(db2, db1) == true

        # In maximization, db with value 10 is better than db with value 15
        db1 = Coluna.ColunaBase.Bound{Dual,MaxSense}(15.0)
        db2 = Coluna.ColunaBase.Bound{Dual,MaxSense}(10.0)
        @test Coluna.ColunaBase.isbetter(db2, db1) == !Coluna.ColunaBase.isbetter(db1, db2) == true

        # Cannot compare a primal & a dual bound
        db1 = Coluna.ColunaBase.Bound{Dual,MaxSense}(-10.0)
        @test_throws MethodError Coluna.ColunaBase.isbetter(db1, pb1)

        # Cannot compare a bound from maximization & a bound from minimization
        db2 = Coluna.ColunaBase.Bound{Dual,MinSense}(10.0)
        @test_throws MethodError Coluna.ColunaBase.isbetter(db1, db2)
    end

    @testset "diff" begin
        # Compute distance between primal bound and dual bound
        # In minimization, if pb = 10 & db = 5, distance is 5
        pb = Coluna.ColunaBase.Bound{Primal,MinSense}(10)
        db = Coluna.ColunaBase.Bound{Dual,MinSense}(5)
        @test Coluna.ColunaBase.diff(pb, db) == Coluna.ColunaBase.diff(db, pb) == 5

        # In maximisation if pb = 10 & db = 5, distance is -5
        pb = Coluna.ColunaBase.Bound{Primal,MaxSense}(10)
        db = Coluna.ColunaBase.Bound{Dual,MaxSense}(5)
        @test Coluna.ColunaBase.diff(pb, db) == Coluna.ColunaBase.diff(db, pb) == -5

        # Cannot compute the distance between two primal bounds
        pb1 = Coluna.ColunaBase.Bound{Primal,MaxSense}(10)
        pb2 = Coluna.ColunaBase.Bound{Primal,MaxSense}(15)
        @test_throws MethodError Coluna.ColunaBase.diff(pb1, pb2)

        # Cannot compute the distance between two dual bounds
        db1 = Coluna.ColunaBase.Bound{Dual,MaxSense}(5)
        db2 = Coluna.ColunaBase.Bound{Dual,MaxSense}(50)
        @test_throws MethodError Coluna.ColunaBase.diff(db1, db2)

        # Cannot compute the distance between two bounds from different sense
        pb = Coluna.ColunaBase.Bound{Primal,MaxSense}(10)
        db = Coluna.ColunaBase.Bound{Dual,MinSense}(5)
        @test_throws MethodError Coluna.ColunaBase.diff(pb, db)
    end

    @testset "gap" begin
        # In minimisation, gap = (pb - db)/db
        pb = Coluna.ColunaBase.Bound{Primal,MinSense}(10.0)
        db = Coluna.ColunaBase.Bound{Dual,MinSense}(5.0)
        @test Coluna.ColunaBase.gap(pb, db) == Coluna.ColunaBase.gap(db, pb) == (10.0-5.0)/5.0
    
        # In maximisation, gap = (db - pb)/pb
        pb = Coluna.ColunaBase.Bound{Primal,MaxSense}(5.0)
        db = Coluna.ColunaBase.Bound{Dual,MaxSense}(10.0)
        @test Coluna.ColunaBase.gap(pb, db) == Coluna.ColunaBase.gap(db, pb) == (10.0-5.0)/5.0
    
        pb = Coluna.ColunaBase.Bound{Primal,MinSense}(10.0)
        db = Coluna.ColunaBase.Bound{Dual,MinSense}(-5.0)
        @test Coluna.ColunaBase.gap(pb, db) == Coluna.ColunaBase.gap(db, pb) == (10.0+5.0)/5.0   

        # Cannot compute the gap between 2 primal bounds
        pb1 = Coluna.ColunaBase.Bound{Primal,MaxSense}(10)
        pb2 = Coluna.ColunaBase.Bound{Primal,MaxSense}(15)
        @test_throws MethodError Coluna.ColunaBase.gap(pb1, pb2)

        # Cannot compute the gap between 2 dual bounds
        db1 = Coluna.ColunaBase.Bound{Dual,MaxSense}(5)
        db2 = Coluna.ColunaBase.Bound{Dual,MaxSense}(50)
        @test_throws MethodError Coluna.ColunaBase.gap(db1, db2)

        # Cannot compute the gap between 2 bounds with different sense
        pb = Coluna.ColunaBase.Bound{Primal,MaxSense}(10)
        db = Coluna.ColunaBase.Bound{Dual,MinSense}(5)
        @test_throws MethodError Coluna.ColunaBase.gap(pb, db)
    end

    @testset "printbounds" begin
        # In minimisation sense
        pb1 = Coluna.ColunaBase.Bound{Primal, MinSense}(100)
        db1 = Coluna.ColunaBase.Bound{Dual, MinSense}(-100)
        Coluna.ColunaBase.printbounds(db1, pb1)

        # In maximisation sense
        pb2 = Coluna.ColunaBase.Bound{Primal, MaxSense}(-100)
        db2 = Coluna.ColunaBase.Bound{Dual, MaxSense}(100)
        Coluna.ColunaBase.printbounds(db2, pb2)
    end

    @testset "show" begin
        pb = Coluna.ColunaBase.Bound{Primal,MaxSense}(4)
        @test repr(pb) == "4.0"
    end

    @testset "Promotions & conversions" begin
        pb = Coluna.ColunaBase.Bound{Primal,MaxSense}(4.0)
        db = Coluna.ColunaBase.Bound{Dual,MaxSense}(2.0)
        @test eltype(promote(pb, 1)) == typeof(pb)
        @test eltype(promote(pb, 2.0)) == typeof(pb)
        @test eltype(promote(pb, π)) == typeof(pb)
        @test eltype(promote(pb, 1, 2.0, π)) == typeof(pb)
        @test eltype(promote(pb, db)) == Float64
        
        @test typeof(pb + 1) == typeof(pb) # check that promotion works

        @test convert(Float64, pb) == pb.value
        @test convert(Integer, pb) == pb.value
        @test convert(Irrational, pb) == pb.value
        # @test convert(Coluna.ColunaBase.Bound{Coluna.AbstractPrimalSpace, Coluna.AbstractMaxSense}, 4.0) = pb
        # @test convert(Coluna.ColunaBase.Bound{Coluna.AbstractPrimalSpace, Coluna.AbstractMaxSense}, 4) = pb
        # @test convert(Coluna.ColunaBase.Bound{Coluna.AbstractPrimalSpace, Coluna.AbstractMaxSense}, π) = Coluna.ColunaBase.Bound{Primal, MaxSense}(π)
        
        pb_min_1 = Coluna.ColunaBase.Bound{Primal,MaxSense}(3.0)
        pb_plus_1 = Coluna.ColunaBase.Bound{Primal,MaxSense}(5.0)

        @test -pb == Coluna.ColunaBase.Bound{Primal,MaxSense}(-4.0)
        @test pb + pb == 8
        @test pb - pb == 0
        @test pb * pb == 16
        @test pb / pb == 1
        @test pb == pb
        @test pb < pb_plus_1
        @test pb <= pb
        @test pb >= pb
        @test pb_plus_1 > pb
        @test pb < 5
        @test pb > 3
        @test pb <= 4
        @test pb >= 4
        @test pb == 4
        @test pb != 3
        @test pb + 1 == 5
        @test pb - 1 == 3
        @test pb / 4 == 1
        @test pb * 2 == 8

        db = Coluna.ColunaBase.Bound{Dual,MaxSense}(2.5)
        # In a given sense, promotion of pb & a db gives a float
        @test eltype(promote(pb, db)) == Float64

        # Promotion between two bounds of different senses does not work
        pb1 = Coluna.ColunaBase.Bound{Primal,MaxSense}(2.5)
        pb2 = Coluna.ColunaBase.Bound{Primal,MinSense}(2.5)
        @test_throws ErrorException promote(pb1, pb2)

        db1 = Coluna.ColunaBase.Bound{Dual,MaxSense}(2.5)
        db2 = Coluna.ColunaBase.Bound{Dual,MinSense}(2.5)
        @test_throws ErrorException promote(db1, db2)

        pb = Coluna.ColunaBase.Bound{Primal,MaxSense}(2.5)
        db = Coluna.ColunaBase.Bound{Dual,MinSense}(2.5)
        @test_throws ErrorException promote(pb, db)
    end
end

function fake_solution_factory(nbdecisions)
    decisions = Set{Int}()
    i = 0
    while i < nbdecisions
        v = rand(rng, 1:100)
        if v ∉ decisions
            push!(decisions, v)
            i += 1
        end
    end
    dict = Dict{Int, Float64}()
    soldecisions = Vector{Int}()
    solvals = Vector{Float64}()
    for d in decisions
        val = rand(rng, 0:0.0001:1000)
        dict[d] = val
        push!(soldecisions, d)
        push!(solvals, val)
    end
    return dict, soldecisions, solvals
end

function test_solution_iterations(solution::Coluna.ColunaBase.Solution, dict::Dict)
    prev_decision = nothing
    for (decision, value) in solution
        if prev_decision !== nothing
            @test prev_decision < decision
        end
        @test solution[decision] == dict[decision]
        solution[decision] += 1
        @test solution[decision] == dict[decision] + 1
    end
    return
end

struct FakeModel <: Coluna.ColunaBase.AbstractModel end

function solution_unit()
    @testset "MOI Termination Status" begin
        @test Coluna.ColunaBase.convert_status(MOI.OPTIMAL) == Coluna.ColunaBase.OPTIMAL
        @test Coluna.ColunaBase.convert_status(MOI.INFEASIBLE) == Coluna.ColunaBase.INFEASIBLE
        @test Coluna.ColunaBase.convert_status(MOI.TIME_LIMIT) == Coluna.ColunaBase.TIME_LIMIT
        @test Coluna.ColunaBase.convert_status(MOI.NODE_LIMIT) == Coluna.ColunaBase.NODE_LIMIT
        @test Coluna.ColunaBase.convert_status(MOI.OTHER_LIMIT) == Coluna.ColunaBase.OTHER_LIMIT
        #uncovered?
    end

    @testset "Coluna Termination Status" begin
        @test Coluna.ColunaBase.convert_status(Coluna.ColunaBase.OPTIMAL) == MOI.OPTIMAL
        @test Coluna.ColunaBase.convert_status(Coluna.ColunaBase.INFEASIBLE) == MOI.INFEASIBLE
        @test Coluna.ColunaBase.convert_status(Coluna.ColunaBase.TIME_LIMIT) == MOI.TIME_LIMIT
        @test Coluna.ColunaBase.convert_status(Coluna.ColunaBase.NODE_LIMIT) == MOI.NODE_LIMIT
        @test Coluna.ColunaBase.convert_status(Coluna.ColunaBase.OTHER_LIMIT) == MOI.OTHER_LIMIT
        @test Coluna.ColunaBase.convert_status(Coluna.ColunaBase.UNCOVERED_TERMINATION_STATUS) == MOI.OTHER_LIMIT
    end

    @testset "MOI Result Status Code" begin
        @test Coluna.ColunaBase.convert_status(MOI.NO_SOLUTION) == Coluna.ColunaBase.UNKNOWN_SOLUTION_STATUS
        @test Coluna.ColunaBase.convert_status(MOI.FEASIBLE_POINT) == Coluna.ColunaBase.FEASIBLE_SOL
        @test Coluna.ColunaBase.convert_status(MOI.INFEASIBLE_POINT) == Coluna.ColunaBase.INFEASIBLE_SOL
        #uncovered?
    end

    @testset "Coluna Solution Status" begin
        @test Coluna.ColunaBase.convert_status(Coluna.ColunaBase.FEASIBLE_SOL) == MOI.FEASIBLE_POINT
        @test Coluna.ColunaBase.convert_status(Coluna.ColunaBase.INFEASIBLE_SOL) == MOI.INFEASIBLE_POINT
        @test Coluna.ColunaBase.convert_status(Coluna.ColunaBase.UNCOVERED_SOLUTION_STATUS) == MOI.OTHER_RESULT_STATUS
    end

    Primal = Coluna.AbstractPrimalSpace
    Dual = Coluna.AbstractDualSpace
    MinSense = Coluna.AbstractMinSense
    MaxSense = Coluna.AbstractMaxSense

    model = FakeModel()

    Solution = Coluna.ColunaBase.Solution{FakeModel,Int,Float64}

    dict_sol, soldecs, solvals = fake_solution_factory(100)
    primal_sol = Solution(model, soldecs, solvals, 12.3, Coluna.ColunaBase.FEASIBLE_SOL)
    test_solution_iterations(primal_sol, dict_sol)
    @test Coluna.ColunaBase.getvalue(primal_sol) == 12.3
    #Coluna.ColunaBase.setvalue!(primal_sol, 123.4)
    #@test Coluna.ColunaBase.getvalue(primal_sol) == 123.4
    return
end