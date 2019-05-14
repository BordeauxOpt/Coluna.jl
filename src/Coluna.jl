module Coluna

import MathOptInterface
import MathOptInterface.Utilities
import DataStructures
import GLPK
import JuMP
import BlockDecomposition
import Distributed
import TimerOutputs

using Logging
using SparseArrays
using Printf

global const MOI = MathOptInterface
global const MOIU = MathOptInterface.Utilities
global const DS = DataStructures
global const BD = BlockDecomposition
global const TO = TimerOutputs

# Base functions for which we define more methods in Coluna
import Base.isempty
import Base.hash
import Base.isequal
import Base.filter
import Base.length
import Base.iterate
import Base.getindex
import Base.lastindex
import Base.getkey
import Base.delete!
import Base.setindex!
import Base.haskey
import Base.copy
import Base.promote_rule
import Base.convert
import Base.isinteger
import Base.push!

include("types.jl")
include("solvers/solver.jl")
include("strategies/strategy.jl")

include("parameters.jl")
include("counters.jl")

include("containers/members.jl")

include("vcids.jl")
include("variable.jl")
include("constraint.jl")
include("varconstr.jl")
include("manager.jl")
include("filters.jl")
include("solsandbounds.jl")
include("incumbents.jl")
include("formulation.jl")
include("clone.jl")
include("reformulation.jl")
include("projection.jl")
include("problem.jl")
include("decomposition.jl")
include("MOIinterface.jl")

# Concrete Solvers & Strategies :

# Here include solvers
include("solvers/colgen.jl")
include("solvers/masteripheur.jl")
include("solvers/generatechildrennodes.jl")

# Here include conquer strategies
include("strategies/conquer/simplebnp.jl")

# Here include divide strategies
include("strategies/divide/simplebranching.jl")

# Here include tree search strategies
include("strategies/treesearch/simplestrategies.jl")

# Search tree
include("node.jl")
include("bbtree.jl")

# Wrapper functions
include("MOIwrapper.jl")

include("globals.jl") # Structure that holds values useful in all the procedure

global const _params_ = Params()
global const _globals_ = GlobalValues()

end # module
