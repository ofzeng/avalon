type startingInfo
end
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

function combinations(n)
    if n == 1
        return [(1), (2), (3), (4), (5)]
    elseif n == 2
        return [(1, 2), (1, 3), (1, 4), (1, 5), (2, 3), (2, 4), (2, 5), (3, 4), (3, 5), (4, 5)]
    else
        return [(1, 2, 3), (1, 2, 4), (1, 2, 5), (1, 3, 4), (1, 3, 5), (1, 4, 5), (2, 3, 4), (2, 3, 5), (2, 4, 5), (3, 4, 5)]
    end
end

type Game
    numPlayers::Int
    good::Array{Bool, 1}
    missionNumber::Int
    passes::Array{Bool, 1}
    proposer::Int
    proposal::Array{Bool, 1}
    currentEvent::Symbol # :noop, :proposing, :mission

    validActions::Function
    performActions::Function

    function combinations(arr, n::Int)
        combos = []
        function combinations(arr, i, n, combo)
            if n == 0
                push!(combos, copy(combo))
            end
        end
    end
    
    function Game()
        this = new()
        this.numPlayers = 5
        this.missionNumber = 1
        this.proposer = 1
        this.currentEvent = :noop
        this.passes = [false] * 5
        this.good = [false] * 5
        for agent in combinations(3)[rand(1:this.numPlayers)] # Lol
            this.good[agent] = true
        end
        this.validActions = function (agent::Int)
            if this.currentEvent == :noop
                return [0]
            end
            if this.currentEvent == :proposing
                if agent != this.proposer
                    return :noop
                end
                if this.missionNumber == 1
                    return combinations(1)
                elseif this.missionNumber == 2 || this.missionNumber == 3
                    return combinations(2)
                else
                    assert(this.missionNumber == 4 || this.missionNumber == 5)
                    return combinations(3)
                end
            end
            if this.currentEvent == :voting
                return [0, 1]
            end
            if this.currentEvent == :mission
                if this.proposal[agent]
                    return [1, 2]
                else
                    return :noop
                end
            end
            assert(false)
        end

        this.performActions = function (actions::Array{Any, 1})
            if this.currentEvent == :noop
                this.currentEvent = :proposing
                assert(all([i == :noop for i in actions]))
                return [(this.good[agent], 0) for agent in this.numPlayers]
            end
            if this.currentEvent == :proposing
                assert(all([actions[i] == :noop || this.proposer == i for i in actions]))
                return [(:noop, 0) for agent in this.numPlayers]
            end
        end
        return this
    end

end

function main()
    a = Game()
    println(a.validActions(1))
    println("HEY")
end

main()
