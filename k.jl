include("mdp.jl")

type DictionaryAgent <: Agent
    map::Dict{Int, Int}

    function DictionaryAgent(map)
        this = new()
        this.map = map
        this
    end
end

function getAction(a::DictionaryAgent, g::Game, agent::Int)
    i = stateToInt(State(g, agent))
    return a.map[i]
end

function giveObservation(agent::DictionaryAgent, a::Int, o::Int)
end

function reset(agent::DictionaryAgent)
end

type LevelKAgent <: Agent
    k::Int
    policy::Any
    updater::Any
    belief::Any

    function LevelKAgent(k::Int, policy, updater)
        this = new()
        this.k = k
        this.policy = policy
        this.updater = updater
        reset(this)
        this
    end
end

function getAction(a::LevelKAgent, g::Game, agent::Int)
    a = action(a.policy, a.belief)
    return a
end

function giveObservation(agent::LevelKAgent, a::Int, o::Int)
    agent.belief = update(agent.updater, agent.belief, a, o)
end

function reset(agent::LevelKAgent)
    agent.belief = initialize_belief(agent.updater, StateDistribution([1.0], [intToState(maxState)]))
end

function generatePolicy(previous_agent)
    pomdp = Avalon([previous_agent for _ in 1:numPlayers])
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
    return (policy, belief_updater)
end

function simplifySolver(k)
    policy = load("levelk/my_policy_$k.jld")["policy"]
    updater = load("levelk/my_updater_$k.jld")["updater"]
    mapping = Dict{Int, Int}()
    for i = 1:maxState
        #mapping[i] = findmax(policy.alphas[i, :])[2]
        parallelStates = getParallelStates(i)
        bestAction = 0
        bestScore = -1000
        for a = 1:length(policy.alphas[1])
            score = 0
            for j = parallelStates
                score += policy.alphas[j][a]
            end
            if score > bestScore
                bestAction = a
            end
        end
        mapping[i] = bestAction
    end
    save("levelk/my_simplified_agent_noknowledge_$k.jld", "agent", DictionaryAgent(mapping))
end

function saveSolver(k, policy, updater)
    save("levelk/my_policy_$k.jld", "policy", policy)
    save("levelk/my_updater_$k.jld", "updater", updater)
    simplifySolver(k)
end

function retrieveSimplifiedSolver(k)
    return load("levelk/my_simplified_agent_noknowledge_$(k).jld")["agent"]
end

function retrieveSolver(k;verbose=true)
    if verbose
        println("RETRIEVING $k")
    end
    if k == 0
        save("levelk/my_simplified_agent_noknowledge_$k.jld", "agent", StupidAgent())
        return StupidAgent()
    end
    policy, updater = nothing, nothing
    if isfile("levelk/my_policy_$k.jld")
        policy = load("levelk/my_policy_$k.jld")["policy"]
        updater = load("levelk/my_updater_$k.jld")["updater"]
    else
        retrieveSolver(k-1) # Ensure existence of previous policy
        agent = retrieveSimplifiedSolver(k-1)
        (policy, updater) = generatePolicy(agent)
        saveSolver(k, policy, updater)
    end
    return LevelKAgent(k, policy, updater)
end

#retrieveSolver(10)
#main()
