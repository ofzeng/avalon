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

type LevelKAgent <: Agent
    k::Int
    policy
    updater

    function LevelKAgent(k::Int, policy, updater)
        this = new()
        this.k = k
        this
    end
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

function saveSolver(k, policy, updater)
    save("levelk/my_policy_$k.jld", "policy", policy)
    save("levelk/my_updater_$k.jld", "updater", updater)
    mapping = Dict{Int, Int}
    for i = 1:maxState
        mapping[i] = max(policy.alphas[i, :])
    end
    save("levelk/my_simplified_agent_$k.jld", "agent", DictionaryAgent(mapping))
end

function retrieveSolver(k)
    println("RETRIEVING $k")
    if k == 0
        save("levelk/my_simplified_agent_$k.jld", "agent", StupidAgent())
        return StupidAgent()
    end
    policy, updater = nothing, nothing
    if isfile("levelk/my_policy_$k.jld")
        policy = load("levelk/my_policy_$k.jld")["policy"]
        updater = load("levelk/my_updater_$k.jld")["updater"]
    else
        retrieveSolver(k-1) # Ensure existence of previous policy
        agent = load("levelk/my_simplified_agent_$(k-1).jld")["agent"]
        (policy, updater) = generatePolicy(agent)
        saveSolver(k, policy, updater)
    end
    return LevelKAgent(k, policy, updater)
end

retrieveSolver(1)
