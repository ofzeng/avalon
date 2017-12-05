include("k.jl")

function playGame(agents; verbose=true)
    for agent in agents
        reset(agent)
    end
    s = intToState(maxState)
    rando = MersenneTwister(Int(time() * 1000000))
    while !isTerminal(s.game)
        actions::Vector{Int} = [getAction(agents[i], s.game, i) for i = 1:numPlayers]
        if verbose
            println("________________________________________________________")
            println("state $s, $(stateToInt(s)), \nperforming $actions, $([intToAction(s.game, i, action) for (i, action) in enumerate(actions)])")
        end
        statePossibilities = getTransitionProbabilities(s, actions, test_time=true)
        s, obs = rand(rando, statePossibilities)
        if verbose
            println("observations $(obs), $([observationToInt(ob) for ob in obs]), new \nstate $s, $(stateToInt(s))")
            #println("belief before $(extractNonzero(agents[3].belief))")
        end
        for (i, ob) = enumerate(obs)
            giveObservation(agents[i], actions[i], ob)
            #giveObservation(agents[i], actions[i], observationToInt(ob))
        end
        if verbose
            #println("belief after $(extractNonzero(agents[3].belief))")
        end
    end
    return s
end

function playNGames(agents, n)
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
        endState = playGame(agents, verbose=true)
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

function getAppropriateSolver(description;verbose=false)
    if typeof(description) == Int
        return retrieveSolver(description, verbose=verbose)
    elseif description == :human
        return HumanAgent()
    elseif description == :stupid
        return StupidAgent()
    end
    assert(false)
end

function runGame(description; n=1, verbose=true)
    num_good_wins = 0
    agent_wins = Dict()
    agent_id_wins = [0 for i in 1:numPlayers]
    for d = description
        agent_wins[d] = 0
    end
    for i = 1:n
        if verbose
            println(description)
        end
        description = shuffle(description)
        agents = map(getAppropriateSolver, description)
        endState = playGame(agents, verbose=verbose)
        if endState.game.currentEvent == :good_wins
            num_good_wins += 1
        else
            assert(endState.game.currentEvent == :bad_wins)
        end
        for agent in 1:numPlayers
            agent_wins[description[agent]] += Int(reward(endState.game, agent))
            agent_id_wins[agent] += Int(reward(endState.game, agent))
        end
    end
    win_rate = num_good_wins / n
    println("--------------------------RESULTS-------------------------")
    println(description)
    println("n $n good $num_good_wins, wr $win_rate")
    for d = unique(description)
        agent_wins[d] /= Float64(count(x->x==d, description))
    end
    println(agent_wins)
    println(agent_id_wins)
    println("-------------------------END RESULTS----------------------")
end

function main()
    runGame([:human,:stupid, :stupid,:stupid,:stupid],n=1,verbose=false)
    return

    k = 1
    runGame([k+1,k,k,k,k], n=1, verbose=true)
    k = 2
    runGame([k+1,k,k,k,k], n=1, verbose=true)
    return
    runGame([:stupid,:stupid,:stupid,:stupid,:stupid], n=10, verbose=false)
    k = 1
    runGame([k,:stupid,:stupid,:stupid,:stupid], n=10, verbose=false)
    runGame([k,k,k,k,k], n=10, verbose=false)
    runGame([k+1,k,k,k,k], n=10, verbose=false)
    k = 2
    runGame([k,:stupid,:stupid,:stupid,:stupid], n=10, verbose=false)
    runGame([k,k,k,k,k], n=10, verbose=false)
    runGame([k+1,k,k,k,k], n=10, verbose=false)
    k = 3
    runGame([k,:stupid,:stupid,:stupid,:stupid], n=10, verbose=false)
    runGame([k,k,k,k,k], n=10, verbose=false)
    runGame([k+1,k,k,k,k], n=10, verbose=false)
    k = 4
    runGame([k,:stupid,:stupid,:stupid,:stupid], n=10, verbose=false)
    runGame([k,k,k,k,k], n=10, verbose=false)
    runGame([k+1,k,k,k,k], n=10, verbose=false)
    #runGame([:stupid, :stupid, :stupid, :stupid, :stupid], n=10, verbose=false)
    #runGame([1,:stupid, :stupid, :stupid, :stupid], n=10, verbose=false)
    #runGame([1,1,1,1,1], n=10, verbose=false)
    #runGame([1,1,1,1,2], n=10, verbose=false)
    #runGame([1,1,1,1,2], n=10, verbose=false)
    #runGame([3,2,2,2,2], n=10, verbose=false)
    #runGame([3,3,3,3,3], n=10, verbose=false)
    #runGame([4,3,3,3,3], n=10, verbose=false)
end

main()
