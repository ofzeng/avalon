using POMDPs, POMDPToolbox, QMDP

using DiscreteValueIteration
include("avalon.jl")
ns = maxState

type State
    game::Game
    agent::Int
end

abstract type Agent
end

type StupidAgent <: Agent
    getAction::Function

    function StupidAgent()
        this = new()
        this.getAction = function(s::State)
            actions = validActions(s.game, s.agent)
            if length(actions) > 0
                return actions[1]
            end
            return nothing
        end
        this
    end
end

function copy(state::State)
    return State(copy(state.game), state.agent)
end

function stateToInt(state::State)
    assert(state.agent in 1:numPlayers)
    return gameToInt(state.game, state.agent)
end

function intToState(int::Int)
    assert(int >= 1 && int <= maxState)
    if int % 10000 == 0
        println("Converting $int")
    end
    game, agent = intToGame(int)
    return State(game, agent)
end

mutable struct Avalon <: POMDP{State, Int64, Int64}
    agents::Array{Agent, 1}
    function Avalon()
        this = new()
        this.agents = []
        for i = 1:numPlayers
            push!(this.agents, StupidAgent())
        end
        this
    end
end

POMDPs.state_index(::Avalon, s::State) = stateToInt(s)
POMDPs.action_index(::Avalon, a::Int64) = a
POMDPs.obs_index(::Avalon, o::Int64) = o + 1

type AvalonIterator
end
Base.start(::AvalonIterator) = 1
Base.next(::AvalonIterator, state::Int) = intToState(state), state + 1
Base.done(::AvalonIterator, state::Int) = state == maxState + 1
#Base.done(::AvalonIterator, state::Int) = state == 50000 + 1
POMDPs.iterator(a::AvalonIterator) = a
POMDPs.states(a::Avalon) = AvalonIterator()
POMDPs.observations(a::Avalon) = Array(0:1)

initial_belief(::Avalon) = DiscreteBelief()

mutable struct StateDistribution
    p::Float64
    it::Vector{State}
end

mutable struct Distribution
    p::Float64
    it::Vector{Int64}
end

POMDPs.iterator(d::Distribution) = d.it
POMDPs.iterator(d::StateDistribution) = d.it

function POMDPs.pdf(d::StateDistribution, so::State)
    #println(d, " ", so)
    so in d.it ? (return d.p) : (return 0)
    return
end

function POMDPs.pdf(d::Distribution, so::Int64)
    so in d.it ? (return d.p) : (return 0)
    return
end

function POMDPs.rand(rng::AbstractRNG, d::Distribution)
    weight = 1
    for i = d.it
        if rand(rng) <= d.p / weight
            return i
        end
        weight -= d.p
    end
    return 100000000
end

POMDPs.n_states(a::Avalon) = maxState
POMDPs.n_actions(::Avalon) = 10
POMDPs.n_observations(::Avalon) = 2

function POMDPs.isterminal(pomdp::Avalon, s::State)
    return s.game.currentEvent in [:bad_wins, :good_wins]
end

# Resets the problem after opening door; does nothing after listening
function POMDPs.transition(pomdp::Avalon, s::State, a::Int64)
    if POMDPs.isterminal(pomdp, s)
        return StateDistribution(1, [s])
    end
    actions::Array{Int, 1} = [1 for i in 1:numPlayers] # todo add agents moves
    actions[s.agent] = a
    nextState = copy(s)
    performIntActions(nextState.game, actions)
    d = StateDistribution(1, [nextState])
    d
end

#function POMDPs.observation(pomdp::Avalon, a::Int64, sp::State)
    #d = Distribution(0.5, [0, 1])
    #d
#end

function POMDPs.observation(pomdp::Avalon, s::Int64, a::Int64, sp::Int64)
    if POMDPs.isterminal(pomdp, s)
        return StateDistribution(1, [s])
    end
    actions::Array{Int, 1} = [1 for i in 1:numPlayers] # todo add agents moves
    actions[s.agent] = a
    nextState = copy(s)
    obs = performIntActions(nextState.game, actions)[s.agent]
    intObs = observationToAction(obs)
    d = StateDistribution(1, [intObs])
    d
    #return observation(pomdp, a, sp)
end

POMDPs.reward(pomdp::Avalon, s::State, a::Int64, sp::State) = Int(reward(sp.game, sp.agent))

POMDPs.initial_state_distribution(pomdp::Avalon) = StateDistribution(1, [intToState(maxState)])

POMDPs.actions(::Avalon) = Array(1:10)

POMDPs.discount(pomdp::Avalon) = 1

#function POMDPs.generate_o(p::Avalon, s::Int64, rng::AbstractRNG)
    #assert(s > 0)
    #d = observation(p, 0, s) # obs distrubtion not action dependant
    #return rand(rng, d)
#end

# same for both state and observation
Base.convert(::Type{Array{Float64}}, so::Int64, p::Avalon) = Float64[so]
Base.convert(::Type{Int64}, so::Vector{Float64}, p::Avalon) = Int64(so[1])

function main()
    pomdp = Avalon()
    copy(State(Game(), 1))
    transition(pomdp, State(Game(), 1), 1)
    intToState(maxState - 240001 + 1)
    stateToInt(State(Game(0, 5, [true, true, true, false, false], 1, [false, false, false, false, false], 1, [false, false, false, false, false], :proposing), 1))

    #solver = ValueIterationSolver()
    #policy = solve(solver, pomdp, verbose=true)
    #return
    #probability_check(pomdp)
    # initialize a solver and compute a policy
    println("BEGIN SOLVE")
    tic = time()
    solver = QMDPSolver() # from QMDP
    policy = solve(solver, pomdp, verbose=true)
    #save("my_policy.jld", "policy", policy)
    toc = time()
    println(toc - tic)
    tic = time()
    belief_updater = updater(policy) # the default QMDP belief updater (discrete Bayesian filter)
    #save("my_updater.jld", "belief_updater", belief_updater)
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
