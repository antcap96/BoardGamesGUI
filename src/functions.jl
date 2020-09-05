
"""
draw(ctx::CairoContext, board, w, h)

draw `board` on `ctx` with width `w` and height `h`
"""
function draw end

"""
defaultsize(::Type{Game})

returns the default size of the drawing board in pixels for `Game`
"""
function defaultsize end

defaultsize(::Type{<:Game}) = (500,500)

"""
correspondingmove(board, x, y)

take normalized coordinates (between 0 and 1) `x` and `y` and return the corresponding move 

TODO: can return missing for no move?
"""
function correspondingmove end
