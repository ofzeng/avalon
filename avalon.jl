import Base.copy
numPlayers = 5
numBadPlayers = 2
numGoodPlayers = 3
maxState = 5 * 5 * 3 * 4 * 10 * 10 * 5 + 3 # missionNumber, proposer, currentEvent, pass/fail, goodpeople, proposal, agent
println("MAX $maxState")

function combinations_numbers(n)
    if n == 1
        return [(1), (2), (3), (4), (5)]
    elseif n == 2
        return [(1, 2), (1, 3), (1, 4), (1, 5), (2, 3), (2, 4), (2, 5), (3, 4), (3, 5), (4, 5)]
    elseif n == 3
        return [(1, 2, 3), (1, 2, 4), (1, 2, 5), (1, 3, 4), (1, 3, 5), (1, 4, 5), (2, 3, 4), (2, 3, 5), (2, 4, 5), (3, 4, 5)]
    end
end

# One hot
function combinations(n)
    arrs = []
    for combo in combinations_numbers(n)
        arr = [false for _ in 1:5]
        for i in combo
            arr[i] = true
        end
        push!(arrs, arr)
    end
    arrs
end

function playersOnTeam(missionNumber)
    if missionNumber == 1
        return 1
    elseif missionNumber == 2 || missionNumber == 3
        return 2
    else
        assert(missionNumber == 4 || missionNumber == 5)
        return 3
    end
end

type Game
    realIndex::Int
    numPlayers::Int
    good::Array{Bool, 1}
    missionNumber::Int
    passes::Int
    proposer::Int
    proposal::Array{Bool, 1}
    currentEvent::Symbol # :begin, :proposing, :mission, :done
    
    function Game()
        this = new()
        this.realIndex = 0
        this.numPlayers = 5
        this.missionNumber = 1
        this.proposer = 1
        this.currentEvent = :begin
        this.passes = 0
        this.proposal = [false for _ in 1:this.numPlayers]
        this.good = [false for _ in 1:this.numPlayers]
        return this
    end

    function Game(realIndex, numPlayers, good, missionNumber, passes, proposer, proposal, currentEvent)
        this = new()
        #this.realIndex = 0
        this.realIndex = realIndex
        this.numPlayers = numPlayers
        this.missionNumber = missionNumber
        this.proposer = proposer
        this.currentEvent = currentEvent
        this.passes = passes
        this.proposal = proposal
        this.good = good
        return this
    end
end

function copy(game::Game)
    return Game(0, game.numPlayers, copy(game.good), game.missionNumber, copy(game.passes), game.proposer, game.proposal, game.currentEvent)
end

function reward(game::Game, agent::Int) # reward for entering state
    if game.currentEvent in [:bad_wins, :good_wins]
        if game.good[agent]
            return Int(game.currentEvent == :good_wins)
        else
            return Int(game.currentEvent == :bad_wins)
        end
    end
    return 0
end

function validActions(this::Game, agent::Int)
    if this.currentEvent == :begin
        return [:noop]
    end
    if this.currentEvent == :proposing
        if agent != this.proposer
            return [:noop]
        end
        teamSize = playersOnTeam(this.missionNumber)
        return combinations(teamSize)
    end
    if this.currentEvent == :voting
        return [:up, :down]
    end
    if this.currentEvent == :mission
        if this.proposal[agent]
            return [:pass, :fail]
        else
            return [:noop]
        end
    end
    if this.currentEvent in [:good_wins, :bad_wins]
        return []
    end
    assert(false)
end

function isTerminal(this::Game)
    return this.currentEvent == :good_wins || this.currentEvent == :bad_wins
end

function completeGame(this::Game)
    if this.passes >= 3
        this.currentEvent = :good_wins
    else
        this.currentEvent = :bad_wins
    end
end

function completeMission(this::Game, pass::Bool)
    this.passes = min(this.passes + Int(pass), 3)
    if this.missionNumber == 5
        completeGame(this)
        return
    end
    this.missionNumber += 1
    this.proposer = 1
    this.currentEvent = :proposing
end

function performActions(this::Game, actions::Array{Any, 1}; seed::Int=-1)
    if seed < 0
        seed = rand(1:10)
    end
    this.realIndex = 0
    if this.currentEvent == :begin
        this.good = combinations(3)[seed]
        this.currentEvent = :proposing
        assert(all([i == :noop for i in actions]))
        return [this.good[agent] + 2 * agent for agent in 1:this.numPlayers]
    end
    if this.currentEvent == :proposing
        assert(all([(actions[i] == :noop && this.proposer != i) || 
                    (this.proposer == i && typeof(actions[i]) == Array{Bool, 1}) for i in 1:this.numPlayers]))
        this.proposal = actions[this.proposer]
        this.currentEvent = :voting
        return [this.proposal for agent in 1:this.numPlayers]
    end
    if this.currentEvent == :voting
        assert(all([i in [:up, :down] for i in actions]))
        if sum([action == :up for action in actions]) > this.numPlayers / 2.0
            this.currentEvent = :mission
        else
            if this.proposer == 5
                completeMission(this, false)
            else
                this.proposer += 1
                this.currentEvent = :proposing
            end
        end
        return [actions for agent in 1:this.numPlayers]
    end
    if this.currentEvent == :mission
        assert(all([(actions[agent] in [:pass, :fail] && this.proposal[agent]) || 
                    (actions[agent] == :noop && !this.proposal[agent]) for agent in 1:this.numPlayers]))
        num_fails = sum([action == :fail for action in actions])
        if this.missionNumber in [1,2,3,5] && num_fails >= 1
            completeMission(this, false)
        elseif this.missionNumber == 4 && num_fails >= 2
            completeMission(this, false)
        else
            completeMission(this, true)
        end
        return [num_fails for agent in 1:this.numPlayers]
    end
    if this.isTerminal()
        return []
    end
    assert(false)
end

function observationToInt(obs::Any)
    if typeof(obs) == Int
        return obs + 1
    else
        conversion = Dict(true => 1, false => 0, :pass => 1, :fail => 0, :up => 1, :down => 0)
        newObs = sum([(conversion[obs[i]]) << (i - 1) for i in 1:length(obs)])
        return newObs + 1
    end
end

function intToAction(this::Game, agent::Int, action::Int)
    trueAction::Any = :noop
    if this.currentEvent == :begin
    elseif this.currentEvent == :proposing
        if agent == this.proposer
            options = combinations(playersOnTeam(this.missionNumber))
            choice = action
            if choice > length(options)
                choice = 1
            end
            trueAction = options[choice]
        end
    elseif this.currentEvent == :voting
        trueAction = action == 1 ? :down : :up
    elseif this.currentEvent == :mission
        if this.proposal[agent]
            trueAction = action == 1 ? :fail : :pass
        end
    end
    return trueAction
end

function performIntActions(this::Game, intActions::Array{Int, 1}; seed::Int=-1)
    trueActions::Array{Any, 1} = [:noop for i in intActions]
    if this.currentEvent == :begin
    elseif this.currentEvent == :proposing
        options = combinations(playersOnTeam(this.missionNumber))
        choice = intActions[this.proposer]
        if choice > length(options)
            choice = 1
        end
        trueActions[this.proposer] = options[choice]
    elseif this.currentEvent == :voting
        trueActions = [i == 1 ? :down : :up for i in intActions]
    elseif this.currentEvent == :mission
        for i in 1:length(intActions)
            if this.proposal[i]
                trueActions[i] = intActions[i] == 1 ? :fail : :pass
            end
        end
    end
    return performActions(this, trueActions, seed=seed)
end

#States are ordered in dag order to make easier single pass value iteration
function gameToInt(game::Game, agent::Int;ignore_cache=false)
    if game.realIndex > 0 && !ignore_cache
        return game.realIndex
    end
    if game.currentEvent == :begin
        return maxState
    end
    i = 2
    statesPerMission = 5 * 3 * 4 * 10 * 10 * 5 # proposer, currentEvent, pass/fail, goodpeople, proposal, agent
    assert(maxState == statesPerMission * 5 + 3)
    #println("MAXSTATE $maxState")
    if game.currentEvent == :bad_wins
        i += 5 * statesPerMission
        return maxState - i + 1
    end
    if game.currentEvent == :good_wins
        i += 5 * statesPerMission + 1
        return maxState - i + 1
    end
    i += (game.missionNumber - 1) * statesPerMission

    statesPerProposer = 3 * 4 * 10 * 10 * 5 # currentEvent, pass/fail, goodpeople, proposal, agent
    i += (game.proposer - 1) * statesPerProposer
    #println("I $i")

    statesPerEvent = 4 * 10 * 10 * 5 # pass/fail, goodpeople, proposal, agent
    eventNumber = Dict{Symbol, Int}(:proposing => 1, :voting => 2, :mission => 3)[game.currentEvent]
    i += (eventNumber - 1) * statesPerEvent
    #println("I $i")

    statesPerPassFail = 10 * 10 * 5 # goodpeople, proposal, agent
    passFailNumber = game.passes
    i += (passFailNumber) * statesPerPassFail
    #println("I $i")

    statesPerGoodPeople = 10 * 5 # proposal, agent
    goodPeople = Tuple(game.good)
    goodPeopleNumber = find(x -> Tuple(x) == goodPeople, combinations(numGoodPlayers))[1]
    i += (goodPeopleNumber - 1) * statesPerGoodPeople
    #println("I $i")

    statesPerProposal = 5 # agent
    proposal = Tuple(game.proposal)
    proposalNumber = find(x -> Tuple(x) == proposal, combinations(playersOnTeam(game.missionNumber)))
    if length(proposalNumber) == 0
        proposalNumber = 1
    else
        proposalNumber = proposalNumber[1]
    end
    i += (proposalNumber - 1) * statesPerProposal
    #println("I $i")

    i += (agent - 1) * 1
    if (!(i > 0 && i <= maxState))
        println("Game $game agent $agent i $i")
    end
    assert(i > 0 && i <= maxState)
    return maxState - i + 1
end

function intToGame(s::Int)
    state = maxState - s + 1 # Reverse toposort order
    game = Game()
    game.realIndex = s
    if state == 1
        return (game, 1) # Fake agent id; assign a crappy agent until we have a real one
    end
    statesPerMission = 5 * 3 * 4 * 10 * 10 * 5 # proposer, currentEvent, pass/fail, goodpeople, proposal
    if state == maxState - 1
        game.currentEvent = :bad_wins
        return (game, 1)
    end
    if state == maxState
        game.currentEvent = :good_wins
        return (game, 1)
    end
    i = state - 2

    game.missionNumber = Int(floor(i / statesPerMission)) + 1
    i -= (game.missionNumber - 1) * statesPerMission

    statesPerProposer = 3 * 4 * 10 * 10 * 5 # currentEvent, pass/fail, goodpeople, proposal, agentId
    game.proposer = Int(floor(i / statesPerProposer)) + 1
    i -= (game.proposer - 1) * statesPerProposer

    statesPerEvent = 4 * 10 * 10 * 5 # pass/fail, goodpeople, proposal, agentId
    eventNumber = Int(floor(i / statesPerEvent)) + 1
    game.currentEvent = Dict{Int, Symbol}(1 => :proposing, 2 => :voting, 3 => :mission)[eventNumber]
    i -= (eventNumber - 1) * statesPerEvent

    statesPerPassFail = 10 * 10 * 5 # goodpeople, proposal, agentId
    game.passes = Int(floor(i / statesPerPassFail))
    #game.passes = [(passFailNumber - 1) & (1 << (i - 1)) > 0 for i in 1:5]
    i -= (game.passes) * statesPerPassFail

    statesPerGoodPeople = 10 * 5 # proposal, agentId
    goodPeopleNumber = Int(floor(i / statesPerGoodPeople)) + 1
    game.good = combinations(numGoodPlayers)[goodPeopleNumber]
    i -= (goodPeopleNumber - 1) * statesPerGoodPeople

    statesPerProposal = 5 # agentId
    proposalNumber = Int(floor(i / statesPerProposal)) + 1
    proposals = combinations(playersOnTeam(game.missionNumber))
    i -= (proposalNumber - 1) * statesPerProposal
    if proposalNumber > length(proposals)
        proposalNumber = 1
    end
    game.proposal = combinations(playersOnTeam(game.missionNumber))[proposalNumber]
    #proposal = Tuple(game.proposal)
    #proposalNumber = find(x -> Tuple(x) == proposal, combinations(playersOnTeam(game.missionNumber)))
    #if length(proposalNumber) == 0
        #proposalNumber = 0
    #else
        #proposalNumber = proposalNumber[1]
    #end

    agent = i + 1
    if (!(agent in 1:numPlayers))
        println(i)
        println("Agent $agent i $state g $game")
        println(maxState - state + 1)
        error()
    end
    i -= (agent - 1) * 1
    assert(i == 0)
    return (game, agent)
end

function simulateGame(game::Game)
    function getAction()
        try
            a = readline()
            return Int(a)
            if a[1] == ':'
                return Symbol(a[2:end])
            elseif a[1] == '['
                return include_string(a)
            elseif all(isnumber, a)
                return Int(a)
            else
                return a
            end
        end
        return nothing
    end
    while !isTerminal(game)
        actions = []
        for i = 1:5
            int = gameToInt(game, i)
            #println(int)
            #println(intToGame(int))
            valid = validActions(game, i)
            action = nothing
            while true
                try
                    println("You are agent $i, you can perform $valid")
                    action = valid[parse(Int, readline())]
                end
                if !(action in valid)
                    println("Bad action, try again")
                else
                    break
                end
            end
            push!(actions, action)
        end
        results = performActions(game, actions)
        println("All players moved, result is $results")
        #intResults = [observationToInt(result) for result in results]
        #println("All players moved, result is $intResults")
    end
    println(game.currentEvent)
end

function testGameIntBijection()
    for i = 1:maxState
        if i % 10000 == 0
            println("i $i")
        end
        game, agent = intToGame(i)
        int = gameToInt(game, agent)
        if int != i
            println("BAD: $i $int")
            println("Game $game agent $agent")
            return
        end
    end
end

function main()
    #testGameIntBijection()
    #a = Game()
    #simulateGame(Game())
end

main()
