using POMDPs, POMDPToolbox, QMDP, JLD

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
    function StupidAgent()
        this = new()
        this
    end
end

function getAction(a::StupidAgent, s::State)
    actions = validActions(s.game, s.agent)
    if length(actions) > 0
        return actions[1]
    end
    return nothing
end

function copy(state::State)
    return State(copy(state.game), state.agent)
end

statesArray = nothing

function stateToInt(state::State)
    assert(state.agent in 1:numPlayers)
    return gameToInt(state.game, state.agent)
end

function intToState(int::Int)
    assert(int >= 1 && int <= maxState)
    if int % 50000 == 0
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
POMDPs.obs_index(::Avalon, o::Int64) = o

#type AvalonIterator
#end
#Base.start(::AvalonIterator) = 1
#Base.next(::AvalonIterator, state::Int) = intToState(state), state + 1
#Base.done(::AvalonIterator, state::Int) = state == maxState + 1
##Base.done(::AvalonIterator, state::Int) = state == 50000 + 1
#POMDPs.iterator(a::AvalonIterator) = a
statesArray = []
for i = 1:maxState
    push!(statesArray,intToState(i))
end
POMDPs.states(a::Avalon) = statesArray
POMDPs.observations(a::Avalon) = Array(1:32)

initial_belief(::Avalon) = DiscreteBelief()

mutable struct StateDistribution
    p::Float64
    it::Vector{State}
end

mutable struct Distribution
    p::Float64
    it::Vector{Int64}
end

#println(enumerate(POMDPs.iterator(StateDistribution(1.0, [intToState(1)]))))

POMDPs.iterator(d::Distribution) = d.it
POMDPs.iterator(d::StateDistribution) = d.it

function POMDPs.pdf(d::StateDistribution, so::State)
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

function POMDPs.rand(rng::AbstractRNG, d::StateDistribution)
    weight = 1
    for i = d.it
        if rand(rng) <= d.p / weight
            return i
        end
        weight -= d.p
    end
    return State()
end

POMDPs.n_states(a::Avalon) = maxState
POMDPs.n_actions(::Avalon) = 10
POMDPs.n_observations(::Avalon) = 32

function POMDPs.isterminal(pomdp::Avalon, s::State)
    return s.game.currentEvent in [:bad_wins, :good_wins]
end

# Resets the problem after opening door; does nothing after listening
function POMDPs.transition(pomdp::Avalon, s::State, a::Int64)
    if POMDPs.isterminal(pomdp, s)
        return StateDistribution(1, [s])
    end
    actions::Array{Int, 1} = [2 for i in 1:numPlayers] # todo add agents moves
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

#function POMDPs.observation(pomdp::Avalon, a::Int64, sp::State)
    #return Distribution(1, [1])
    #if POMDPs.isterminal(pomdp, s)
        #return Distribution(1, [1])
    #end
    #actions::Array{Int, 1} = [2 for i in 1:numPlayers] # todo add agents moves
    #actions[s.agent] = a
    #nextState = copy(s)
    #obs = performIntActions(nextState.game, actions)[s.agent]
    #intObs = observationToInt(obs)
    #d = Distribution(1, [intObs])
    #d
#end

function POMDPs.observation(pomdp::Avalon, s::State, a::Int64, sp::State)
    return Distribution(1, [1])
    if POMDPs.isterminal(pomdp, s)
        return Distribution(1, [1])
    end
    actions::Array{Int, 1} = [2 for i in 1:numPlayers] # todo add agents moves
    actions[s.agent] = a
    nextState = copy(s)
    obs = performIntActions(nextState.game, actions)[s.agent]
    intObs = observationToInt(obs)
    d = Distribution(1, [intObs])
    d
end

POMDPs.reward(pomdp::Avalon, s::State, a::Int64, sp::State) = Int(reward(sp.game, sp.agent))

POMDPs.initial_state_distribution(pomdp::Avalon) = StateDistribution(1, [intToState(maxState)])

POMDPs.actions(::Avalon) = Array(1:10)

POMDPs.discount(pomdp::Avalon) = 1.0

function POMDPs.generate_o(p::Avalon, s::State, a::Int64, sp::State, rng::AbstractRNG)
    d = observation(p, s, a, sp)
    return rand(rng, d)
end

# same for both state and observation
Base.convert(::Type{Array{Float64}}, so::Int64, p::Avalon) = Float64[so]
Base.convert(::Type{Int64}, so::Vector{Float64}, p::Avalon) = Int64(so[1])

function main()
    restore = true
    pomdp = Avalon()
    policy = nothing
    belief_updater = nothing

    if !restore
        println("BEGIN SOLVE")
        tic = time()
        solver = QMDPSolver(max_iterations=0) # from QMDP
        policy = solve(solver, pomdp, verbose=true)
        toc = time()
        println(toc - tic)
        tic = time()
        belief_updater = updater(policy) # the default QMDP belief updater (discrete Bayesian filter)
        toc = time()
        println(toc - tic)

        println("BEGIN SAVING")
        save("my_policy.jld", "policy", policy)
        save("my_updater.jld", "belief_updater", belief_updater)
        println("DONE SAVING")
    else
        println("BEGIN RESTORE")
        policy = load("my_policy.jld")["policy"]
        belief_updater = load("my_updater.jld")["belief_updater"]
        println("END RESTORE")
    end
    # run a short simulation with the QMDP policy
    println("BEGIN SIMULATING")
    history = simulate(HistoryRecorder(max_steps=40), pomdp, policy, belief_updater)
    println("DONE SIMULATING")

    # look at what happened
    i = 0
    totalScore = 0
    for (s, b, a, o, r) in eachstep(history, "sbaor")
        println("State was $s,")
        println("belief was $b,")
        println("action $a was taken,")
        println("and observation $o was received. Reward $r\n")
        i += 1
    end
    println("Discounted reward was $(discounted_reward(history)).")
end

main()
