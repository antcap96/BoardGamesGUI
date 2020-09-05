using Gtk
using Cairo
using BoardGames

mutable struct GuiData{G <: Game, M, B, STuple}
    movelist::Vector{M}
    boardlist::Vector{B}
    playable::Bool
    curr_visible_player::Int
    curr_visible_strategy::Vector{Int}
    playerboxes::Vector{GtkBox}
    strategyboxes::Vector{Vector{GtkBox}}
    elemententries::Vector{Vector{Vector{GtkEntry}}}
    playerstrategies::Vector{Int}
    allstrategies::Vector{STuple}
end

GuiData(::Type{G}, playerboxes, strategyboxes, elemententries, strategies) where G<:Game = 
    GuiData{G, movetype(G), boardtype(G), typeof(strategies)}(
        movetype(G)[], 
        boardtype(G)[initialboard(G())], 
        false, 
        0, 
        ones(Int, nplayers(G)), 
        playerboxes,
        strategyboxes,
        elemententries,
        ones(Int, nplayers(G)),
        [copy.(strategies) for i in 1:nplayers(G)]
    )

guidatagame(::GuiData{G,M,B}) where {G,M,B} = G

@guarded function mouseclick_cb(widgetptr::Ptr, eventptr::Ptr, user_data)
    widget = convert(GtkCanvas, widgetptr)
    event = unsafe_load(eventptr)

    (data, strategies) = user_data

    if data.playable
        ctx = Gtk.getgc(widget)
        w = Gtk.width(widget)
        h = Gtk.height(widget)

        x = event.x / w
        y = event.y / h
        move = correspondingmove(data.boardlist[end], x,y)

        if move in getmoves(data.boardlist[end])
            push!(data.movelist, move)
            push!(data.boardlist, play(data.boardlist[end], move))
        end

        println("x: $x, y: $y")

        playgame(data)

        reveal(widget)
    end
    nothing
end

@guarded function draw_cb(widgetptr::Ptr, cairoptr::Ptr, user_data)
    widget = convert(GtkCanvas, widgetptr)

    w, h = width(widget), height(widget)
    ctx = CairoContext(cairoptr)

    draw(ctx, user_data.boardlist[end], w, h)

    nothing
end

@guarded function play_cb(widgetptr::Ptr, user_data)
    widget = convert(GtkToggleButton, widgetptr)

    (data, strategies, canvas) = user_data
    
    data.playable = get_gtk_property(widget, "active", Bool)

    if data.playable
        playgame(data)
    end

    reveal(canvas)
    nothing
end

@guarded function restart_cb(widgetptr::Ptr, user_data)
    widget = convert(GtkButton, widgetptr)
    
    data, canvas = user_data

    data.movelist = []
    data.boardlist = [initialboard(guidatagame(data)())]

    #TODO: set play to false

    reveal(canvas)
    nothing
end

@guarded function paramter_cb(widgetptr::Ptr, user_data)
    entry = convert(GtkEntry, widgetptr)

    strategy, name = user_data
end

@guarded function players_combobox_cb(widgetptr::Ptr, data)
    combobox = convert(GtkComboBoxText, widgetptr)

    if data.curr_visible_player != 0
        visible(data.playerboxes[data.curr_visible_player], false)
    end

    data.curr_visible_player = get_gtk_property(combobox, "active", Int)+1

    visible(data.playerboxes[data.curr_visible_player], true)

    nothing
end

@guarded function parameters_combobox_cb(widgetptr::Ptr, user_data)
    combobox = convert(GtkComboBoxText, widgetptr)

    (data, i) = user_data

    if data.curr_visible_strategy[i] != 0 
        visible(data.strategyboxes[i][data.curr_visible_strategy[i]], false)
    end

    data.curr_visible_strategy[i] = get_gtk_property(combobox, "active", Int)+1

    visible(data.strategyboxes[i][data.curr_visible_strategy[i]], true)

    nothing
end

@guarded function set_parameters_cb(widgetptr::Ptr, user_data)
    data = user_data

    data.playerstrategies .= data.curr_visible_strategy

    #TODO:parameters

    for user in 1:length(data.playerboxes)
        for (sidx, strategy) in enumerate(data.allstrategies[user])
            for (pidx, parameter) in enumerate(getvarsnames(strategy))
                s = get_gtk_property(data.elemententries[user][sidx][pidx], :text, String)
                setvalue!(strategy, parameter, s)
            end
        end
    end

    nothing
end

function mainwindow(game::Type{<:Game}, strategies::Strategy...)
    n = nplayers(game)
    strategies = (UserStrategy(), strategies...)
    win = GtkWindow("A new window", 600, 600)

    mainhbox = GtkBox(:h)
    push!(win, mainhbox)

    w,h = defaultsize(game)
    canvas = GtkCanvas(w, h)
    push!(mainhbox, canvas)

    vbox = GtkBox(:v)
    push!(mainhbox, vbox)

    #side buttons
    restart = GtkButton("restart")
    play = GtkToggleButton("play")

    (
        strategy_frame, 
        players_combobox,
        strategy_combobox, 
        user_boxes, 
        strategy_boxes, 
        parameter_boxes, 
        parameter_inputs
    ) = createframebox(n, strategies)

    set_parameters = GtkButton("set parameters")

    push!(vbox, strategy_frame)
    push!(vbox, set_parameters)
    push!(vbox, play)
    push!(vbox, restart)

    #visibility
    showall(win)

    for i in 1:length(user_boxes)
        visible(user_boxes[i], false)
        set_gtk_property!(strategy_combobox[i], :active, 0)
        for j in 2:length(strategy_boxes[i]) #show user
            visible(strategy_boxes[i][j], false)
        end
    end

    #callbacks
    data = GuiData(game, user_boxes, strategy_boxes, parameter_inputs, strategies)
    strategydict = Dict{String, Int}(zip(name.(strategies),1:length(strategies)))

    signal_connect(mouseclick_cb, canvas, "button_press_event", Nothing, (Ptr{Gtk.GdkEventButton},), false, (data, strategies))
    signal_connect(draw_cb, canvas, "draw", Nothing, (Ptr{Nothing},), false, data)
    signal_connect(play_cb, play, "toggled", Nothing, (), false, (data, strategies, canvas))
    signal_connect(restart_cb, restart, "clicked", Nothing, (), false, (data, canvas))
    signal_connect(players_combobox_cb, players_combobox, "changed", Nothing, (), false, data)
    for i in 1:n
        signal_connect(parameters_combobox_cb, strategy_combobox[i], "changed", Nothing, (), false, (data, i))
    end
    signal_connect(set_parameters_cb, set_parameters, "clicked", Nothing, (), false, data)
end

function createframebox(n, strategies)
    strategy_frame = GtkFrame("Strategies")
    strategy_frame_box = GtkBox(:v)
    push!(strategy_frame, strategy_frame_box)

    players_combobox = GtkComboBoxText()
    append!(players_combobox, "player " .* string.(1:n))
    push!(strategy_frame_box, players_combobox)

    strategy_combobox = [GtkComboBoxText() for i in 1:n]
    choices = map(name, strategies)
    for i in 1:n
        append!(strategy_combobox[i], choices)
    end

    parameter_inputs = Vector{Vector{GtkEntry}}[]
    parameter_names = Vector{Vector{GtkLabel}}[]
    
    user_boxes = GtkBox[]
    strategy_boxes = Vector{GtkBox}[]
    parameter_boxes = Vector{Vector{GtkBox}}[]
    
    for pidx in 1:n
        push!(parameter_inputs, [])
        push!(parameter_names, [])
        push!(strategy_boxes, [])
        push!(parameter_boxes, [])
        push!(user_boxes, GtkBox(:v))

        push!(user_boxes[pidx], strategy_combobox[pidx])

        for (sidx, strategy) in enumerate(strategies)
            push!(parameter_inputs[pidx], [])
            push!(parameter_names[pidx],  [])
            push!(parameter_boxes[pidx], [])
            push!(strategy_boxes[pidx], GtkBox(:v))

            parameters = getvalues(strategy)
            for (nidx, name) in enumerate(getvarsnames(strategy))
                push!(parameter_names[pidx][sidx], GtkLabel(name))

                push!(parameter_inputs[pidx][sidx], GtkEntry())
                set_gtk_property!(parameter_inputs[pidx][sidx][nidx], :text, string(parameters[nidx]))
                
                push!(parameter_boxes[pidx][sidx], GtkBox(:h))
                #put widgets in boxes
                push!(parameter_boxes[pidx][sidx][nidx], parameter_names[pidx][sidx][nidx])
                push!(parameter_boxes[pidx][sidx][nidx], parameter_inputs[pidx][sidx][nidx])
                push!(strategy_boxes[pidx][sidx], parameter_boxes[pidx][sidx][nidx])
            end
            push!(user_boxes[pidx], strategy_boxes[pidx][sidx])
        end
        push!(strategy_frame_box, user_boxes[pidx])
    end

    (
        strategy_frame, 
        players_combobox,
        strategy_combobox, 
        user_boxes, 
        strategy_boxes, 
        parameter_boxes, 
        parameter_inputs
    )
end

function playgame(data::GuiData)
    b = data.boardlist[end]
    p = playerturn(b)
    sidx = data.playerstrategies[p]

    if sidx == 1 || isempty(getmoves(b))
        return
    else
        s = data.allstrategies[p][sidx]
        m = getmove(b, s)
        b = play(b, m)

        push!(data.movelist, m)
        push!(data.boardlist, b)

        #TODO: Reveal?
        playgame(data)
    end
end