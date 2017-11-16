numPlayers = 5
numBadPlayers = 2
numGoodPlayers = 3
maxState = 5 * 5 * 3 * 32 * 10 * 10 * 5 + 3 # proposer, currentEvent, pass/fail, goodpeople, proposal, agent
println("MAX $maxState")

type Agent
    getAction::Function
    function Agent()
        this = new()
        this.getAction = function()
        end
        return this
    end

    function giveObservation()
    end
end

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
    numPlayers::Int
    good::Array{Bool, 1}
    missionNumber::Int
    passes::Array{Bool, 1}
    proposer::Int
    proposal::Array{Bool, 1}
    currentEvent::Symbol # :begin, :proposing, :mission, :done
    
    function Game()
        this = new()
        this.numPlayers = 5
        this.missionNumber = 1
        this.proposer = 1
        this.currentEvent = :begin
        this.passes = [false for _ in 1:this.numPlayers]
        this.proposal = [false for _ in 1:this.numPlayers]
        this.good = [false for _ in 1:this.numPlayers]
        return this
    end
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
    if this.currentEvent == :done
        return []
    end
    assert(false)
end

function isTerminal(this::Game)
    return this.currentEvent == :good_wins || this.currentEvent == :bad_wins
end

function completeGame(this::Game)
    missions_won = sum(this.passes)
    if missions_won >= 3
        this.currentEvent = :good_wins
    else
        this.currentEvent = :bad_wins
    end
end

function completeMission(this::Game, pass::Bool)
    this.passes[this.missionNumber] = pass
    if this.missionNumber == 5
        completeGame(this)
        return
    end
    this.missionNumber += 1
    this.proposer = 1
    this.currentEvent = :proposing
end

function performActions(this::Game, actions::Array{Any, 1})
    if this.currentEvent == :begin
        this.good = combinations(3)[rand(1:this.numPlayers)]
        this.currentEvent = :proposing
        assert(all([i == :noop for i in actions]))
        return [this.good[agent] for agent in 1:this.numPlayers]
    end
    if this.currentEvent == :proposing
        #println(actions, this.proposer)
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
                completeMission(this, true)
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

#States are ordered in dag order to make easier single pass value iteration
function gameToInt(game::Game, agent::Int)
    if game.currentEvent == :begin
        return maxState
    end
    i = 2
    statesPerMission = 5 * 3 * 32 * 10 * 10 * 5 # proposer, currentEvent, pass/fail, goodpeople, proposal, agent
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

    statesPerProposer = 3 * 32 * 10 * 10 * 5 # currentEvent, pass/fail, goodpeople, proposal, agent
    i += (game.proposer - 1) * statesPerProposer
    #println("I $i")

    statesPerEvent = 32 * 10 * 10 * 5 # pass/fail, goodpeople, proposal, agent
    eventNumber = Dict{Symbol, Int}(:proposing => 1, :voting => 2, :mission => 3)[game.currentEvent]
    i += (eventNumber - 1) * statesPerEvent
    #println("I $i")

    statesPerPassFail = 10 * 10 * 5 # goodpeople, proposal, agent
    passFailNumber = sum([game.passes[i] ? 1 << (i - 1) : 0 for i in 1:5]) + 1
    i += (passFailNumber - 1) * statesPerPassFail
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
        proposalNumber = 0
    else
        proposalNumber = proposalNumber[1]
    end
    i += (proposalNumber - 1) * statesPerProposal
    #println("I $i")

    i += (agent - 1) * 1
    assert(i > 0 && i <= maxState)
    return maxState - i + 1
end

function intToGame(state::Int)
    state = maxState - state + 1 # Reverse toposort order
    game = Game()
    if state == 1
        return (game, -1)
    end
    statesPerMission = 5 * 3 * 32 * 10 * 10 * 5 # proposer, currentEvent, pass/fail, goodpeople, proposal
    if state == maxState - 1
        game.currentEvent = :bad_wins
        return (game, -1)
    end
    if state == maxState
        game.currentEvent = :good_wins
        return (game, -1)
    end
    i = state - 2

    game.missionNumber = Int(floor(i / statesPerMission)) + 1
    i -= (game.missionNumber - 1) * statesPerMission

    statesPerProposer = 3 * 32 * 10 * 10 * 5 # currentEvent, pass/fail, goodpeople, proposal, agentId
    game.proposer = Int(floor(i / statesPerProposer)) + 1
    i -= (game.proposer - 1) * statesPerProposer

    statesPerEvent = 32 * 10 * 10 * 5 # pass/fail, goodpeople, proposal, agentId
    eventNumber = Int(floor(i / statesPerEvent)) + 1
    game.currentEvent = Dict{Int, Symbol}(1 => :proposing, 2 => :voting, 3 => :mission)[eventNumber]
    i -= (eventNumber - 1) * statesPerEvent

    statesPerPassFail = 10 * 10 * 5 # goodpeople, proposal, agentId
    passFailNumber = Int(floor(i / statesPerPassFail)) + 1
    game.passes = [(passFailNumber - 1) & (1 << (i - 1)) > 0 for i in 1:5]
    i -= (passFailNumber - 1) * statesPerPassFail

    statesPerGoodPeople = 10 * 5 # proposal, agentId
    goodPeopleNumber = Int(floor(i / statesPerGoodPeople)) + 1
    game.good = combinations(numGoodPlayers)[goodPeopleNumber]
    i -= (goodPeopleNumber - 1) * statesPerGoodPeople

    statesPerProposal = 5 # agentId
    proposalNumber = Int(floor(i / statesPerProposal)) + 1
    proposals = combinations(playersOnTeam(game.missionNumber))
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
    i -= (proposalNumber - 1) * statesPerProposal

    agent = i + 1
    i -= (agent - 1) * 1
    assert(i == 0)
    return (game, agent)
end

function simulate(game::Game)
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
    testGameIntBijection()
    #a = Game()
    #simulate(Game())
end

main()
