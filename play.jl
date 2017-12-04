include("k.jl")

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

function playGame(pomdp, agents; verbose=true)
    for agent in agents
        reset(agent)
    end
    s = intToState(maxState)
    rando = MersenneTwister(Int(time() * 1000000))
    while !isTerminal(s.game)
        actions = [getAction(agents[i], s.game, i) for i = 1:numPlayers]
        if verbose
            println("________________________________________________________")
            println("state $s, $(stateToInt(s)), \nperforming $actions, $([intToAction(s.game, i, action) for (i, action) in enumerate(actions)])")
        end
        statePossibilities = getTransitionProbabilities(pomdp, s, actions)
        s, obs = rand(rando, statePossibilities)
        if verbose
            println("observations $(obs), $([observationToInt(ob) for ob in obs]), new \nstate $s, $(stateToInt(s))")
            #println("belief before $(extractNonzero(agents[3].belief))")
        end
        for (i, ob) = enumerate(obs)
            giveObservation(agents[i], actions[i], observationToInt(ob))
        end
        if verbose
            #println("belief after $(extractNonzero(agents[3].belief))")
        end
    end
    return s
end

function playNGames(pomdp, agents, n)
    num_good_wins = 0
    agent_wins = [0 for i in 1:numPlayers]
    for i = 1:n
        println("Game number $i")
        println("Game number $i")
        println("Game number $i")
        println("Game number $i")
        println("Game number $i")
        println("Game number $i")
        println("Game number $i")
        println("Game number $i")
        endState = playGame(pomdp, agents, verbose=true)
        if endState.game.currentEvent == :good_wins
            num_good_wins += 1
        else
            assert(endState.game.currentEvent == :bad_wins)
        end
        for agent in 1:numPlayers
            agent_wins[agent] += Int(reward(endState.game, agent))
        end
    end
    win_rate = num_good_wins / n
    println("n $n good $num_good_wins, wr $win_rate")
    println(agent_wins)
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

function mainForReal()
    kplusone = retrieveSolver(2)
    #runGames(pomdp, policy, belief_updater)
    agents::Array{Any, 1} = [retrieveSolver(1) for i in 1:numPlayers]
    simplifiedAgents::Array{Any, 1} = [retrieveSolver(1) for i in 1:numPlayers]
    #agents::Array{Any, 1} = [StupidAgent() for i in 1:numPlayers]
    #agents[3] = POMDPAgent(pomdp, policy, belief_updater)
    agents[1] = kplusone
    pomdp = Avalon(simplifiedAgents)
    #agents[2] = HumanAgent()
    #playGame(pomdp, agents)
    playNGames(pomdp, agents, 20)
end

mainForReal()
