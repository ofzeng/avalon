using POMDPs, POMDPToolbox, QMDP, JLD

using DiscreteValueIteration
include("avalon.jl")

restore = true
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

type HumanAgent <: Agent
    function HumanAgent()
        this = new()
        this
    end
end

function getAction(a::HumanAgent, g::Game, agent::Int)
    println(validActions(g, agent))
    return parse(readline())
end

function giveObservation(agent::HumanAgent, a::Int, o::Int)
    println("YOU OBSERVE $o")
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

function giveObservation(agent::StupidAgent, a::Int, o::Int)
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

mutable struct Distribution
    p::Float64
    it::Vector{Int64}
end

#println(enumerate(POMDPs.iterator(StateDistribution(1.0, [intToState(1)]))))

POMDPs.iterator(d::Distribution) = d.it
POMDPs.iterator(d::StateDistribution) = d.it
POMDPs.iterator(d::StateObservationDistribution) = d.it

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

POMDPs.n_states(a::Avalon) = maxState
POMDPs.n_actions(::Avalon) = 10
POMDPs.n_observations(::Avalon) = 32

function POMDPs.isterminal(pomdp::Avalon, s::State)
    return s.game.currentEvent in [:bad_wins, :good_wins]
end

function enumerateTransitions(s::State, a::Int64, actionProbabilities, actions::Vector{Int}, i, prob, nextProbs::Vector{Float64}, nextStates::Vector{State}, nextObservations::Vector{Int})
    if prob == 0
        return
    end
    if i > length(actionProbabilities)
        nextState = copy(s)
        obs = performIntActions(nextState.game, actions)
        ob = observationToInt(obs[s.agent])
        push!(nextStates, nextState)
        push!(nextProbs, prob)
        push!(nextObservations, ob)
        return
    end
    if s.agent == i
        push!(actions, a)
        enumerateTransitions(s, a, actionProbabilities, actions, i + 1, prob, nextProbs, nextStates, nextObservations)
        pop!(actions)
    else
        actionProb = min((actionProbabilities[i] - 1) / 8.0, 1.0)
        push!(actions, 1)
        enumerateTransitions(s, a, actionProbabilities, actions, i + 1, prob * actionProb, nextProbs, nextStates, nextObservations)
        pop!(actions)
        actionProb = 1 - actionProb
        push!(actions, 2)
        enumerateTransitions(s, a, actionProbabilities, actions, i + 1, prob * actionProb, nextProbs, nextStates, nextObservations)
        pop!(actions)
    end
end

# Resets the problem after opening door; does nothing after listening
function POMDPs.transition(pomdp::Avalon, s::State, a::Int64)
    if POMDPs.isterminal(pomdp, s)
        return StateObservationDistribution([1.0], [s], [1])
    end
    actions::Array{Int, 1} = [getAction(pomdp.agents[i], s.game, i) for i in 1:numPlayers] # todo add agents moves
    actions[s.agent] = a
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
                push!(obs, observationToInt(observationArray[j]))
            end
        end
        d = StateObservationDistribution([1.0 / 10 / 5 for i in 1:50], res, obs)
        return d
    end
    if s.game.currentEvent == :proposing
        nextState = copy(s)
        ob = observationToInt(performIntActions(nextState.game, actions)[s.agent])
        p = 0.5
        d = StateObservationDistribution([p], [nextState], [ob])
        for i = 1:10
            actions[s.game.proposer] = i
            nextState = copy(s)
            ob = observationToInt(performIntActions(nextState.game, actions)[s.agent])
            push!(d.p, (1-p) / 10.0)
            push!(d.it, nextState)
            push!(d.obs, ob)
        end
        return d
    end
    if s.game.currentEvent in [:mission, :voting]
        nextProbs::Vector{Float64} = []
        nextStates::Vector{State} = []
        nextObservations::Vector{Int} = []
        enumerateTransitions(s, a, actions, Vector{Int}(), 1, 1.0, nextProbs, nextStates, nextObservations)
        return StateObservationDistribution(nextProbs, nextStates, nextObservations)
    end
    nextState = copy(s)
    ob = observationToInt(performIntActions(nextState.game, actions)[s.agent])
    d = StateObservationDistribution([1.0], [nextState], [ob])
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

function giveObservation(agent::POMDPAgent, a::Int, o::Int)
    agent.belief = update(agent.updater, agent.belief, a, o)
end

function runGames(pomdp, policy, belief_updater)
    numWins = 0
    for sim = 1:10
        # run a short simulation with the QMDP policy
        println("BEGIN SIMULATING")
        history = simulate(HistoryRecorder(max_steps=100), pomdp, policy, belief_updater)
        println("DONE SIMULATING")

        # look at what happened
        i = 0
        totalScore = 0
        for (s, b, a, o, r) in eachstep(history, "sbaor")
            println("State was $s,")
            nonzero = extractNonzero(b)
            println("Belief state example ", intToState(nonzero[1][1]))
            println("belief was $nonzero,")
            println("action $a was taken,")
            println("and observation $o was received. Reward $r\n")
            i += 1
        end
        println("Discounted reward was $(discounted_reward(history)).")
        numWins += discounted_reward(history)
    end
    println("NUMWINS $numWins")
end

function playGame(pomdp, agents)
    s = intToState(maxState)
    while !isTerminal(s.game)
        actions = [getAction(agents[i], s.game, i) for i = 1:numPlayers]
        println("________________________________________________________")
        println("state $s, \nperforming $(actions[3])")
        obs = performIntActions(s.game, actions)
        println("observations $(obs[3]), new \nstate $s")
        println("belief before $(extractNonzero(agents[3].belief))")
        for (i, ob) = enumerate(obs)
            giveObservation(agents[i], actions[i], observationToInt(ob))
        end
        println("belief after $(extractNonzero(agents[3].belief))")
    end
end

function main()
    pomdp = Avalon()
    policy = nothing
    belief_updater = nothing

    if !restore
        println("BEGIN SOLVE")
        tic = time()
        solver = QMDPSolver(max_iterations=1) # from QMDP
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

    #runGames(pomdp, policy, belief_updater)
    agents::Array{Any, 1} = [StupidAgent() for i in 1:numPlayers]
    agents[3] = POMDPAgent(pomdp, policy, belief_updater)
    #agents[2] = HumanAgent()
    playGame(pomdp, agents)
    
end

#main()
