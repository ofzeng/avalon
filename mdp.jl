using POMDPs, POMDPToolbox, QMDP
using DiscreteValueIteration
ns = 10000
mutable struct TigerPOMDP <: POMDP{Int64, Int64, Int64}
    r_listen::Float64
    r_findtiger::Float64
    r_escapetiger::Float64
    p_listen_correctly::Float64
    discount_factor::Float64
    num_states::Int64
end
TigerPOMDP() = TigerPOMDP(-1.0, -100.0, 10.0, 0.5, 0.95, ns)

POMDPs.state_index(::TigerPOMDP, s::Int64) = s
POMDPs.action_index(::TigerPOMDP, a::Int64) = a
POMDPs.obs_index(::TigerPOMDP, o::Int64) = o + 1

POMDPs.states(a::TigerPOMDP) = Array(1:a.num_states)
POMDPs.observations(a::TigerPOMDP) = Array(0:1)

initial_belief(::TigerPOMDP) = DiscreteBelief(7)

mutable struct TigerDistribution
    p::Float64
    it::Vector{Int64}
end
#TigerDistribution() = TigerDistribution(0.5, [1,2])
POMDPs.iterator(d::TigerDistribution) = d.it

function POMDPs.pdf(d::TigerDistribution, so::Int64)
    #println(d, " ", so)
    so in d.it ? (return d.p) : (return 0)
    return
    so == 1 ? (return d.p) : (return 1.0-d.p)
end

function POMDPs.rand(rng::AbstractRNG, d::TigerDistribution)
    weight = 1
    for i = d.it
        if rand(rng) <= d.p / weight
            return i
        end
        weight -= d.p
    end
    return 100000000
end

POMDPs.n_states(a::TigerPOMDP) = a.num_states
POMDPs.n_actions(::TigerPOMDP) = 3
POMDPs.n_observations(::TigerPOMDP) = 2

function POMDPs.isterminal(pomdp::TigerPOMDP, s)
    #return s == ns
    return s == 1
end

# Resets the problem after opening door; does nothing after listening
function POMDPs.transition(pomdp::TigerPOMDP, s::Int64, a::Int64)
    d = TigerDistribution(0.5, [max(s - 1, 1), max(s - 2, 1)])
    #if a == 1 || a == 2
        #d.p = 0.5
    #elseif s == 1
        #d.p = 1.0
    #else
        #d.p = 0.0
    #end
    d
end

function POMDPs.observation(pomdp::TigerPOMDP, a::Int64, sp::Int64)
    assert(sp > 0)
    d = TigerDistribution(0.5, [0, 1])
    #d = TigerDistribution(0.5, [sp, sp % pomdp.num_states + 1])
    pc = pomdp.p_listen_correctly
    if a == 1
        sp == 1 ? (d.p = pc) : (d.p = 1.0-pc)
    else
        d.p = 0.5
    end
    d
end

function POMDPs.observation(pomdp::TigerPOMDP, s::Int64, a::Int64, sp::Int64)
    return observation(pomdp, a, sp)
end


function POMDPs.reward(pomdp::TigerPOMDP, s::Int64, a::Int64)
    assert(s > 0)
    return 1
    r = 0.0
    a == 1 ? (r+=pomdp.r_listen) : (nothing)
    if a == 2
        s == 1 ? (r += pomdp.r_findtiger) : (r += pomdp.r_escapetiger)
    end
    if a == 3
        s == 1 ? (r += pomdp.r_escapetiger) : (r += pomdp.r_findtiger)
    end
    return r
end
POMDPs.reward(pomdp::TigerPOMDP, s::Int64, a::Int64, sp::Int64) = reward(pomdp, s, a)

POMDPs.initial_state_distribution(pomdp::TigerPOMDP) = TigerDistribution(1, [ns])

POMDPs.actions(::TigerPOMDP) = [1,2,3]

function upperbound(pomdp::TigerPOMDP, s::Int64)
    return pomdp.r_escapetiger
end

POMDPs.discount(pomdp::TigerPOMDP) = pomdp.discount_factor

function POMDPs.generate_o(p::TigerPOMDP, s::Int64, rng::AbstractRNG)
    assert(s > 0)
    d = observation(p, 0, s) # obs distrubtion not action dependant
    return rand(rng, d)
end

# same for both state and observation
Base.convert(::Type{Array{Float64}}, so::Int64, p::TigerPOMDP) = Float64[so]
Base.convert(::Type{Int64}, so::Vector{Float64}, p::TigerPOMDP) = Int64(so[1])

function main()
    pomdp = TigerPOMDP()

    #solver = ValueIterationSolver()
    #policy = solve(solver, pomdp, verbose=true)
    #return
    #probability_check(pomdp)
    # initialize a solver and compute a policy
    tic = time()
    solver = QMDPSolver() # from QMDP
    policy = solve(solver, pomdp)
    toc = time()
    println(toc - tic)
    tic = time()
    belief_updater = updater(policy) # the default QMDP belief updater (discrete Bayesian filter)
    toc = time()
    println(toc - tic)
    return

    # run a short simulation with the QMDP policy
    history = simulate(HistoryRecorder(max_steps=3), pomdp, policy, belief_updater)

    # look at what happened
    i = 0
    totalScore = 0
    for (s, b, a, o, r) in eachstep(history, "sbaor")
        println("State was $s,")
        println("belief was $b,")
        println("action $a was taken,")
        println("and observation $o was received. Reward $r\n")
        discounted = r * (0.95 ^ i)
        totalScore += discounted
        println("D $discounted, total $totalScore\n")
        i += 1
    end
    println("Discounted reward was $(discounted_reward(history)).")
end

main()
