using POMDPs, POMDPToolbox, QMDP, JLD

using DiscreteValueIteration
include("avalon.jl")

restore = true
ns = maxState

type State
    game::Game
    agent::Int
end

function getParallelStates(si::Int)
    state = intToState(si)
    states = []
    for i = combinations(3)
        if i[state.agent] == state.game.good[state.agent]
            newS = copy(state)
            newS.game.good = i
            push!(states, stateToInt(newS))
        end
    end
    return states
end

abstract type Agent
end

type StupidAgent <: Agent
    function StupidAgent()
        this = new()
        this
    end
end

type HumanAgent <: Agent
    function HumanAgent()
        this = new()
        this
    end
end

function getActionFromConsole()
    action = parse(readline())
    if action in [:up, :pass]
        action = 1
    elseif action in [:down, :fail]
        action = 10
    elseif action in [:noop]
        action = 1
    elseif typeof(action) != Int
        error()
    end
    return action
end

function getAction(a::HumanAgent, g::Game, agent::Int)
    println("YOU CAN DO $(validActions(g, agent))")
    action = nothing
    while action == nothing
        try
            action = getActionFromConsole()
        catch
            println("TRY AGAIN")
        end
    end
    return action
end

function giveObservation(agent::HumanAgent, a::Int, o::Any;verbose=false)
    println("YOU OBSERVE $o")
end

function reset(agent::HumanAgent)
end

function getAction(a::StupidAgent, g::Game, agent::Int)
    actions = validActions(g, agent)
    #return Int(hash(stateToInt(State(g, agent))) % length(actions)) + 1
    if g.currentEvent in [:mission, :voting]
        return 5
    end
    return Int(hash(g.passes * 10 + g.proposer + g.good[1] * 100 + g.good[2] * 120 + g.good[3] * 420 + g.missionNumber * 719) % length(actions) + 1)
    if length(actions) > 1
        return 2
    elseif length(actions) > 0
        return 1
    end
    return nothing
end

function giveObservation(agent::StupidAgent, a::Int, o::Any;verbose=false)
end

function reset(agent::StupidAgent)
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
    function Avalon(agents)
        this = new()
        this.agents = agents
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
println("GENERATING STATES")
statesArray = []
for i = 1:maxState
    push!(statesArray,intToState(i))
end
POMDPs.states(a::Avalon) = statesArray
POMDPs.observations(a::Avalon) = Array(1:32)

initial_belief(::Avalon) = DiscreteBelief()

mutable struct StateDistribution
    p::Vector{Float64}
    it::Vector{State}
end

mutable struct StateObservationDistribution
    p::Vector{Float64}
    it::Vector{State}
    obs::Vector{Int}
end

mutable struct StateObservationsDistribution # Gives observations for each agent
    p::Vector{Float64}
    it::Vector{State}
    obs::Vector{Vector{Any}}
end

mutable struct Distribution
    p::Float64
    it::Vector{Int64}
end

#println(enumerate(POMDPs.iterator(StateDistribution(1.0, [intToState(1)]))))

POMDPs.iterator(d::Distribution) = d.it
POMDPs.iterator(d::StateDistribution) = d.it
POMDPs.iterator(d::StateObservationDistribution) = d.it
POMDPs.iterator(d::StateObservationsDistribution) = d.it

function POMDPs.pdf(d::StateDistribution, so::State)
    results = find(x->x==so, d.it)
    if length(results) == 0
        return 0
    end
    assert(length(results) == 1)
    index = results[1]
    return d.p[index]
end

function POMDPs.pdf(d::StateObservationDistribution, so::State)
    results = find(x->x==so, d.it)
    if length(results) == 0
        return 0
    end
    assert(length(results) == 1)
    index = results[1]
    return d.p[index]
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

function POMDPs.rand(rng::AbstractRNG, d::StateObservationDistribution)
    weight = 1
    for i = d.it
        if rand(rng) <= pdf(d, i) / weight
            return i
        end
        weight -= d.p
    end
    return State()
end

function POMDPs.rand(rng::AbstractRNG, d::StateObservationsDistribution)
    weight = 1
    for i = 1:length(d.it)
        s = d.it[i]
        o = d.obs[i]
        if rand(rng) <= d.p[i] / weight
            return (s, o)
        end
        weight -= d.p[i]
    end
    return (State(), 0)
end

POMDPs.n_states(a::Avalon) = maxState
POMDPs.n_actions(::Avalon) = 10
POMDPs.n_observations(::Avalon) = 32

function terminal(s::State)
    return s.game.currentEvent in [:bad_wins, :good_wins]
end

function POMDPs.isterminal(pomdp::Avalon, s::State)
    return terminal(s)
end

function enumerateTransitions(s::State, actionProbabilities, actions::Vector{Int}, i, prob, nextProbs::Vector{Float64}, nextStates::Vector{State}, nextObservations::Vector{Vector{Any}};test_time=false)
    if prob == 0
        #if test_time
            #println("BYE")
        #end
        return
    end
    if i > length(actionProbabilities)
        nextState = copy(s)
        #obs = map(observationToInt, performIntActions(nextState.game, actions))
        obs = performIntActions(nextState.game, actions)
        #if test_time
            #println("ADDING")
            #println(actionProbabilities)
            #println(actions, " ", prob)
        #end
        push!(nextStates, nextState)
        push!(nextProbs, prob)
        push!(nextObservations, obs)
        return
    end
    #if s.agent == i
        #push!(actions, a)
        #enumerateTransitions(s, a, actionProbabilities, actions, i + 1, prob, nextProbs, nextStates, nextObservations)
        #pop!(actions)
    #else
    actionProb = min((actionProbabilities[i]) / 11.0, 10/11.0)
    if test_time
        actionProb = min((actionProbabilities[i] - 1) / 9.0, 1.0)
        #if !(actionProb in [0,1])
            #println("Not all or nothing $actionProb")
        #end
    end
    push!(actions, 1)
    enumerateTransitions(s, actionProbabilities, actions, i + 1, prob * actionProb, nextProbs, nextStates, nextObservations, test_time=test_time)
    pop!(actions)
    actionProb = 1 - actionProb
    #if test_time
        #println("HI3 $actionProb")
    #end
    push!(actions, 2)
    enumerateTransitions(s, actionProbabilities, actions, i + 1, prob * actionProb, nextProbs, nextStates, nextObservations, test_time=test_time)
    pop!(actions)
end

function getTransitionProbabilities(s::State, actions::Vector{Int};test_time=false)
    #println("HI")
    if terminal(s)
        return StateObservationsDistribution([1.0], [s], [[1 for _ in 1:numPlayers]])
    end
    if s.game.currentEvent == :begin
        res = []
        obs = []
        for i = 1:10
            nextState = copy(s)
            observationArray = performIntActions(nextState.game, actions, seed=i)
            for j = 1:numPlayers
                nextNextState = copy(nextState)
                nextNextState.agent = j
                push!(res, nextNextState)
                push!(obs, [(observationArray[j]) for j in 1:numPlayers])
            end
        end
        d = StateObservationsDistribution([1.0 / 10 / 5 for i in 1:50], res, obs)
        return d
    end
    if s.game.currentEvent == :proposing
        nextState = copy(s)
        observations = performIntActions(nextState.game, actions)
        ob = [(observations[agent]) for agent in 1:numPlayers]
        p = 0.5
        if test_time
            p = 1.0
        end
        d = StateObservationsDistribution([p], [nextState], [ob])
        for i = 1:10
            actions[s.game.proposer] = i
            nextState = copy(s)
            observations = performIntActions(nextState.game, actions)
            ob = [(observations[agent]) for agent in 1:numPlayers]
            push!(d.p, (1-p) / 10.0)
            push!(d.it, nextState)
            push!(d.obs, ob)
        end
        return d
    end
    if s.game.currentEvent in [:mission, :voting]
        nextProbs::Vector{Float64} = []
        nextStates::Vector{State} = []
        nextObservations::Vector{Vector{Any}} = []
        enumerateTransitions(s, actions, Vector{Int}(), 1, 1.0, nextProbs, nextStates, nextObservations, test_time=test_time)
        return StateObservationsDistribution(nextProbs, nextStates, nextObservations)
    end
    nextState = copy(s)
    observations = performIntActions(nextState.game, actions)
    ob = [(observations[agent]) for agent in 1:numPlayers]
    d = StateObservationsDistribution([1.0], [nextState], [ob])
    d
end

function convert(d::StateObservationsDistribution)
    obs = [observationToInt(d.obs[i][d.it[i].agent]) for i in 1:length(d.obs)]
    return StateObservationDistribution(d.p, d.it, obs)
end

# Resets the problem after opening door; does nothing after listening
function POMDPs.transition(pomdp::Avalon, s::State, a::Int64)
    if POMDPs.isterminal(pomdp, s)
        return StateObservationDistribution([1.0], [s], [1])
    end
    actions::Array{Int, 1} = [getAction(pomdp.agents[i], s.game, i) for i in 1:numPlayers] # todo add agents moves
    actions[s.agent] = a
    return convert(getTransitionProbabilities(s, actions))
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
    if POMDPs.isterminal(pomdp, s)
        return Distribution(1, [1])
    end
    actions::Array{Int, 1} = [getAction(pomdp.agents[i], s.game, i) for i in 1:numPlayers] # todo add agents moves
    actions[s.agent] = a
    if s.game.currentEvent == :begin
        return Distribution(1, [observationToInt(sp.agent * 2 + sp.game.good[sp.agent])])
    end
    nextState = copy(s)
    obs = performIntActions(nextState.game, actions)[sp.agent]
    intObs = observationToInt(obs)
    d = Distribution(1, [intObs])
    d
end

POMDPs.reward(pomdp::Avalon, s::State, a::Int64, sp::State) = Int(reward(sp.game, sp.agent))

POMDPs.initial_state_distribution(pomdp::Avalon) = StateDistribution([1.0], [intToState(maxState)])

POMDPs.actions(::Avalon) = Array(1:10)

POMDPs.discount(pomdp::Avalon) = 1.0

function POMDPs.generate_o(p::Avalon, s::State, a::Int64, sp::State, rng::AbstractRNG) # TODO: retrieve from transition
    d = observation(p, s, a, sp)
    return rand(rng, d)
end

# same for both state and observation
Base.convert(::Type{Array{Float64}}, so::Int64, p::Avalon) = Float64[so]
Base.convert(::Type{Int64}, so::Vector{Float64}, p::Avalon) = Int64(so[1])

type POMDPAgent <: Agent
    pomdp::Any
    policy::Any
    updater::Any
    belief::Any
    
    function POMDPAgent(pomdp, policy, belief_updater)
        this = new()
        this.pomdp = pomdp
        this.policy = policy
        this.updater = belief_updater
        initial_state_dist = POMDPs.initial_state_distribution(pomdp)
		initial_belief = initialize_belief(belief_updater, initial_state_dist)
		# use of deepcopy inspired from rollout.jl
		if initial_belief === initial_state_dist
			initial_belief = deepcopy(initial_belief)
        end
        this.belief = initial_belief

        this
    end
end

function extractNonzero(belief)
    nonzero = []
    for (j, bp) in enumerate(belief.b)
        if bp > 0
            push!(nonzero, (j, bp))
        end
    end
    return nonzero
end

function getAction(a::POMDPAgent, g::Game, agent::Int)
    a = action(a.policy, a.belief)
    return a
end

function giveObservation(agent::POMDPAgent, a::Int, ob::Int;verbose=false)
    o = observationToInt(ob)
    agent.belief = update(agent.updater, agent.belief, a, o)
end

