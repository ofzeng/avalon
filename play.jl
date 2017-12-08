include("k.jl")

seed = Int(time() * 1000000000)
println("SEED $seed")
rando = MersenneTwister(seed)

function playGame(agents; verbose=true)
    for agent in agents
        reset(agent)
    end
    s = intToState(maxState)
    #rando = MersenneTwister(Int(time() * 1000000))
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
        #if verbose
            #for (sn, prob) in extractNonzero(agents[2].belief)
                #ss = intToState(sn)
                #good = ss.game.good
                #println("State number $sn good $good prob $prob")
            #end
        #end
    end
    return s
end

function getAppropriateSolver(description;verbose=false)
    if typeof(description) == Int
        return retrieveSolver(description, verbose=verbose)
    elseif description == :human
        return HumanAgent()
    elseif description == :stupid
        return StupidAgent()
    elseif typeof(description) == Tuple{Int, Int}
        policy = retrieveSimplifiedSolver(description[2])
        #println("CHECKING")
        #for i = 100000:maxState
            #s = intToState(i)
            #a = getAction(policy, s.game, s.agent)
            #for agent = 1:numPlayers
                #a2 = getAction(policy, s.game, agent)
                #if a != 1#a2
                    #println("s $s i $i a $(s.agent) a2 $agent $a $a2")
                #else
                    ##println("bad: s $s i $i a $(s.agent) a2 $agent $a $a2")
                #end
            #end
            ##states = getParallelStates(i)
            ##println("i $i, action $(getAction(policy, s.game, s.agent))")
        #end
        #println("CHECKINGDONE")
        return policy
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
        description = shuffle(description)
        if verbose
            println(description)
        end
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

    retrieveSolver(50)

    for k = 1:7
        runGame([k+1, (0,k), (0,k), (0,k), (0,k)], n=20, verbose=false)
        runGame([k,k,k,k,k], n=20, verbose=false)
        runGame([k+1,k,k,k,k], n=20, verbose=false)
        runGame([k,1,1,1,1], n=20, verbose=false)
    end 
end

main()
