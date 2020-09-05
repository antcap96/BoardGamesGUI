struct UserStrategy <: Strategy end

function BoardGames.getvarsnames(::UserStrategy)
    return String[]
end

BoardGames.name(::UserStrategy) = "User"

Base.copy(s::UserStrategy) = s

BoardGames.getvalues(s::UserStrategy) = ()