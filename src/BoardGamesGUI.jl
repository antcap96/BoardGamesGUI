module BoardGamesGUI

using Gtk
using Cairo
using BoardGames

# Write your package code here.

export 
    draw,
    correspondingmove,
    mainwindow

include("functions.jl")
include("main.jl")
include("userstrategy.jl")


end
