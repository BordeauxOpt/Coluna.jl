module Containers

import Primes
import Base: <=, setindex!, get, getindex, haskey, keys, values, iterate, 
             length, lastindex, filter, show, keys, copy

export NestedEnum, @nestedenum,
       ElemDict,
       MembersVector, MembersMatrix, getelements

include("nestedenum.jl")
include("elements.jl")
include("members.jl")

end