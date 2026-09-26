function Init()
    monitor = peripheral.find("monitor")

    peripheral.find("modem", rednet.close)
    peripheral.find("modem", rednet.open)
    monitor.setCursorPos(1, 1)
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.clear()
    term.clear()
    term.setCursorPos(1, 1)
    local file = fs.open(CONFIG_FILE, "r")
    if not file then
        config = default_config()
        save_config()
    else
        config = textutils.unserializeJSON(file.readAll())
        file.close()
    end

    events = { signaller_mes = {}, station_mes = {} }
    render_done = true

    show_id = false
    show_grid = false
end

-- ============================================================================
-- Configuration helpers
-- ============================================================================

computer_id = os.getComputerID()

CONFIG_FILE = "config.json"

local function default_config()
    return {
        stations = {},
        lines = {},
        signallers = {},
        texts = {},
    }
end

local function save_config()
    local file = fs.open(CONFIG_FILE, "w")
    if not file then
        error("Unable to open " .. CONFIG_FILE .. " for writing")
    end

    file.write(textutils.serialiseJSON(config))
    file.close()
end

local function request_render()
    events["update_render"] = true
    wait(function()
        return render_done
    end)
end

-- ============================================================================
-- Monitor helpers
-- ============================================================================

function reset_monitor()
    monitor.setCursorPos(1, 1)
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.clear()
end

function drawLine(start_x, start_y, end_x, end_y, color, show_id, id)
    local func_exp = function(start_x, start_y, end_x, end_y, x)
        return ((end_y - start_y) / (end_x - start_x)) * x +
            (start_y - ((end_y - start_y) / (end_x - start_x)) * start_x)
    end
    if start_x ~= end_x then
        for x = start_x, end_x do
            local y = round(func_exp(start_x, start_y, end_x, end_y, x))
            local last_y = round(func_exp(start_x, start_y, end_x, end_y, x - 1))
            if x ~= start_x then
                for comp = math.min(y, last_y), math.max(y, last_y) do
                    if not show_id then
                        drawPixel(x, comp, color)
                    else
                        drawChar(x, comp, id, colors.black, colors.white)
                    end
                end
            else
                if not show_id then
                    drawPixel(x, y, color)
                else
                    drawChar(x, y, id, colors.black, colors.white)
                end
            end
        end
    else
        for y = math.min(start_y, end_y), math.max(start_y, end_y) do
            local x = start_x
            if not show_id then
                drawPixel(x, y, color)
            else
                drawChar(x, y, id, colors.black, colors.white)
            end
        end
    end
end

function drawPixel(x, y, color)
    monitor.setCursorPos(x, y)
    monitor.setBackgroundColor(color)
    monitor.write(" ")
    monitor.setBackgroundColor(colors.black)
end

function drawChar(x, y, char, back_color, text_color)
    monitor.setCursorPos(x, y)
    monitor.setBackgroundColor(back_color)
    monitor.setTextColor(text_color)
    monitor.write(char)
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
end

-- ============================================================================
-- Toolkits
-- ============================================================================

function round(num)
    if num - math.floor(num) >= 0.5 then
        return math.ceil(num)
    else
        return math.floor(num)
    end
end

function wait(cond)
    repeat
        os.sleep()
    until cond()
    return true
end

function Transmit()
    translist = {}


    function receive()
        while true do
            local id, mes = rednet.receive("SYNC_To_" .. computer_id)
            if mes == "SYNC" then
                rednet.send(id, "SYNC_CON", "SYNC_CON_To_" .. id)
                local id, mes = rednet.receive("DATA_To_" .. computer_id, 10)
                table.insert(translist, mes)
                rednet.send(id, "ACK", "ACK_To_" .. id)
            end
        end
    end

    function process()
        while true do
            local mes = table.remove(translist, 1)
            if mes then
                if mes.class and mes.id then
                    if mes.class == "station" then
                        table.insert(events.station_mes, { id = mes.id, data = mes })
                    elseif mes.class == "signaller" then
                        table.insert(events.signaller_mes, { id = mes.id, data = mes })
                    end
                end
            end
            os.sleep()
        end
    end

    parallel.waitForAny(receive, process)
end

-- ============================================================================
-- Terminal / command interface
-- ============================================================================

function Terminal()
    term.setTextColor(colors.lightBlue)
    term.write("Signaller System | " .. computer_id .. " > Type 'help' for commands")
    term.setTextColor(colors.lime)
    print("\n\n")
    local completion = require("cc.completion")
    local commands = {
        "shutdown",
        "reboot",
        "help",
        "get_id",
        "get_size",
        "add_station",
        "remove_station",
        "reset_config",
        "show_config",
        "refresh_render",
        "reset_rednet",
        "scale",
        "render_move",
        "element_move",
        "add_line",
        "remove_line",
        "add_signaller",
        "add_text",
        "remove_text",
        "toggle_show_id",
        "add_signaller",
        "remove_signaller",
        "add_text",
        "remove_text",
        "toggle_show_grid"
    }
    local history
    while true do
        term.setTextColor(colors.lime)
        write("Signaller System | " .. computer_id .. " > ")
        local command = read(nil, history, function(text)
            return completion.choice(text, commands)
        end, nil)
        print("")

        if command == "shutdown" then
            os.shutdown()
        elseif command == "reboot" then
            os.reboot()
        elseif command == "help" then
            term.setTextColor(colors.yellow)
            print("Commands:")
            print("help - Show this help message")
            print("get_id - Get this computer ID")
            print("get_size - Get the size of the monitor")
            print("shutdown - Shutdown the computer")
            print("reboot - Reboot the computer")
            print("add_station - Add a station")
            print("remove_station - Remove a station")
            print("reset_config - Reset the config to default")
            print("show_config - Show the current config")
            print("refresh_render - Refresh the render manually")
            print("scale - Set the text scale of the monitor")
            print("render_move - Move the render on the monitor by x,y")
            print("element_move - Move an element (station/line/signaller) to x,y")
            print("add_line - Add a line")
            print("remove_line - Remove a line")
            print("add_signaller - Add a signaller")
            print("add_text - Add text")
            print("remove_text - Remove text")
            print("toggle_show_id - Toggle showing IDs of lines on the monitor")
            print("add_signaller - Add a signaller")
            print("remove_signaller - Remove a signaller")
            print("add_text - Add a text")
            print("remove_text - Remove a text")
            print("toggle_show_grid - Toggle showing a grid on the monitor")

            term.setTextColor(colors.lime)
        elseif command == "add_station" then
            write("Station ID:")
            local station_id = read()
            if config.stations[station_id] ~= nil then
                term.setTextColor(colors.red)
                print("Station ID is occupied")
                term.setTextColor(colors.lime)
                goto continue
            end
            write("\nStation Line:")
            local station_line = read()
            write("\nStation X:")
            local station_x = read()
            write("\nStation Y:")
            local station_y = read()
            local station_dir
            repeat
                write("\nStation Direction (U/R/D/L):")
                station_dir = read()
            until (station_dir == "U" or station_dir == "R" or station_dir == "D" or station_dir == "L")
            local file = fs.open("config.json", "w")
            config.stations[station_id] = {
                id = station_id,
                line = station_line,
                x = tonumber(station_x),
                y = tonumber(station_y),
                dir = station_dir,
                pres = false,
                imm = false
            }
            file.write(textutils.serialiseJSON(config))
            file.close()
            term.setTextColor(colors.yellow)
            write("\nSuccessfully added station!\nID: " .. station_id ..
                "\nLine: " .. station_line ..
                "\nX: " .. station_x ..
                "\nY: " .. station_y ..
                "\nDirection: " .. station_dir ..
                "\n")
            term.setTextColor(colors.lime)
            request_render()
        elseif command == "remove_station" then
            write("Station ID:")
            local station_id = read()
            if config.stations[station_id] == nil then
                term.setTextColor(colors.red)
                print("Station doesn't exist")
                term.setTextColor(colors.lime)
                goto continue
            end
            config.stations[station_id] = nil
            save_config()
            request_render()
        elseif command == "reset_config" then
            print("Are you sure to")
            term.blit(" reset the config? (y/n):", "eeeeeeeeeeeeeeeeeeeeeeeee", "fffffffffffffffffffffffff")
            local confirm = read()
            if confirm == "y" then
                config = default_config()
                save_config()
                request_render()
            end
        elseif command == "show_config" then
            term.setTextColor(colors.yellow)
            print(textutils.serialiseJSON(config))
            term.setTextColor(colors.lime)
        elseif command == "refresh_render" then
            request_render()
        elseif command == "scale" then
            write("Set scale (0.5-5):")
            local scale = tonumber(read())
            if scale and scale >= 0.5 and scale <= 5 then
                monitor.setTextScale(scale)
                request_render()
            else
                term.setTextColor(colors.red)
                print("\nInvalid scale. Please enter a number value between 0.5 and 5.")
                term.setTextColor(colors.lime)
            end
        elseif command == "render_move" then
            write("Move render to (x,y):")
            local input = read()
            local x, y = input:match("(%d+),(%d+)")
            x, y = tonumber(x), tonumber(y)
            if x and y then
                for class, _ in pairs(config) do
                    for index, _ in pairs(config[class]) do
                        local item = config[class][index]
                        if item.x and item.y then
                            config[class][index].x = item.x + x
                            config[class][index].y = item.y + y
                        end
                    end
                end
                save_config()
                request_render()
            else
                term.setTextColor(colors.red)
                print("\nInvalid coordinates. Please enter in the format x,y where x and y are numbers.")
                term.setTextColor(colors.lime)
            end
        elseif command == "element_move" then
            write("Move element (class(stations/signallers),id) to (x,y):")
            local input = read()
            local class, index, x, y = input:match("(%a+),(%w+),(%d+),(%d+)")
            x, y = tonumber(x), tonumber(y)
            if class and index and x and y and config[class] and config[class][index] then
                config[class][index].x = x
                config[class][index].y = y
                save_config()
                request_render()
            else
                term.setTextColor(colors.red)
                print("\nInvalid input. Please enter in the format class,index,x,y where class and index exist.")
                term.setTextColor(colors.lime)
            end
        elseif command == "add_line" then
            write("Line ID:")
            local line_id = read()
            if config.lines[line_id] ~= nil then
                term.setTextColor(colors.red)
                print("Line ID is occupied")
                term.setTextColor(colors.lime)
                goto continue
            end

            write("\nStart (x,y):")
            local start_pos = read()
            local start_x, start_y = start_pos:match("(%d+),(%d+)")
            start_x, start_y = tonumber(start_x), tonumber(start_y)

            write("\nEnd (x,y):")
            local end_pos = read()
            local end_x, end_y = end_pos:match("(%d+),(%d+)")
            end_x, end_y = tonumber(end_x), tonumber(end_y)

            write("Is Text (true/false):")
            local is_text = read()
            is_text = is_text == "true"

            write("Text (x,y):")
            local text_pos = read()
            local text_x, text_y = text_pos:match("(%d+),(%d+)")
            text_x, text_y = tonumber(text_x), tonumber(text_y)
            if text_x and text_y then
                if line_id and start_x and start_y and end_x and end_y then
                    config.lines[line_id] = {
                        id = line_id,
                        start_x = start_x,
                        start_y = start_y,
                        end_x = end_x,
                        end_y = end_y,
                        is_text = is_text,
                        text_x = text_x,
                        text_y = text_y,
                        occupied = false,
                        caution = false,
                        text = ""
                    }
                    save_config()
                    request_render()
                end
            else
                term.setTextColor(colors.red)
                print("\nInvalid input. Please enter valid line ID and coordinates.")
                term.setTextColor(colors.lime)
            end
        elseif command == "remove_line" then
            write("Line ID:")
            local line_id = read()
            if config.lines[line_id] == nil then
                term.setTextColor(colors.red)
                print("Line doesn't exist")
                term.setTextColor(colors.lime)
                goto continue
            end
            config.lines[line_id] = nil
            save_config()
            request_render()
        elseif command == "toggle_show_id" then
            show_id = not show_id
            request_render()
        elseif command == "add_signaller" then
            write("Signaller ID:")
            local signaller_id = read()
            if config.signallers[signaller_id] ~= nil then
                term.setTextColor(colors.red)
                print("Signaller ID is occupied")
                term.setTextColor(colors.lime)
                goto continue
            end
            write("\nNext Line ID:")
            local line_id = read()
            if line_id:find("{", 1) then
                line_id = textutils.unserialise(line_id)
                if not line_id then
                    term.setTextColor(colors.red)
                    print("Wrong format (\"{\"n1\",\"n2\",...}\")")
                    term.setTextColor(colors.lime)
                    goto continue
                end
                config.signallers[signaller_id] = { line_id = {}, id = 0, x = 0, y = 0, type = "", state = "", block_train = {}, is_force = false }
                for i = 1, #line_id do
                    if config.lines[line_id[i]] == nil then
                        term.setTextColor(colors.red)
                        print("Line doesn't exist")
                        term.setTextColor(colors.lime)
                        goto continue
                    end

                    table.insert(config.signallers[signaller_id].line_id, 1, line_id[i])
                end
            else
                if config.lines[line_id] == nil then
                    term.setTextColor(colors.red)
                    print("Line doesn't exist")
                    term.setTextColor(colors.lime)
                    goto continue
                end
                config.signallers[signaller_id] = { line_id = "", id = 0, x = 0, y = 0, type = "", state = "", block_train = {}, is_force = false }
                config.signallers[signaller_id].line_id = { line_id }
            end
            write("\nSignaller pos (x,y):")
            local signaller_pos = read()
            local signaller_x, signaller_y = signaller_pos:match("(%d+),(%d+)")
            signaller_x, signaller_y = tonumber(signaller_x), tonumber(signaller_y)
            if signaller_x and signaller_y then
                config.signallers[signaller_id].id = signaller_id
                config.signallers[signaller_id].x = signaller_x
                config.signallers[signaller_id].y = signaller_y
                config.signallers[signaller_id].type = "ENTRY_SIGNAL"
                config.signallers[signaller_id].state = "GREEN"
                config.signallers[signaller_id].block_train = {}
                config.signallers[signaller_id].is_force = false
                save_config()
                request_render()
            end
        elseif command == "remove_signaller" then
            write("Signaller ID:")
            local signaller_id = read()
            if config.signallers[signaller_id] == nil then
                term.setTextColor(colors.red)
                print("Signaller doesn't exist")
                term.setTextColor(colors.lime)
                goto continue
            end
            config.signallers[signaller_id] = nil
            save_config()
            request_render()
        elseif command == "add_text" then
            write("Text ID:")
            local text_id = read()
            if config.texts[text_id] ~= nil then
                term.setTextColor(colors.red)
                print("Text ID is occupied")
                term.setTextColor(colors.lime)
                goto continue
            end
            write("\nText:")
            local text = read()
            write("\nText pos (x,y):")
            local text_pos = read()
            local text_x, text_y = text_pos:match("(%d+),(%d+)")
            text_x, text_y = tonumber(text_x), tonumber(text_y)
            if text_x == nil or text_y == nil then
                goto continue
            end
            write("\nIs vertical (true/false):")
            local is_vertical = read()
            is_vertical = is_vertical == "true"
            config.texts[text_id] = {
                id = text_id,
                text = text,
                x = text_x,
                y = text_y,
                is_vertical = is_vertical
            }
            save_config()
            request_render()
        elseif command == "remove_text" then
            write("Text ID:")
            local text_id = read()
            if config.texts[text_id] == nil then
                term.setTextColor(colors.red)
                print("Text doesn't exist")
                term.setTextColor(colors.lime)
                goto continue
            end
            config.texts[text_id] = nil
            save_config()
            request_render()
        elseif command == "toggle_show_grid" then
            show_grid = not show_grid
            request_render()
        elseif command == "get_id" then
            term.setTextColor(colors.yellow)
            print("PC ID: " .. os.getComputerID())
            term.setTextColor(colors.green)
        elseif command == "get_size" then
            term.setTextColor(colors.yellow)
            local size_x, size_y = monitor.getSize()
            print("Size (x,y): " .. size_x .. "," .. size_y)
            term.setTextColor(colors.lime)
        elseif command == "reset_rednet" then
            peripheral.find("modem", rednet.close)
            peripheral.find("modem", rednet.open)
            local id, mes
            repeat
                id, mes = rednet.receive("Signal_To_" .. computer_id, 0.2)
            until not (id ~= nil and mes ~= nil)
        else
            term.setTextColor(colors.red)
            print("\nUnknown command. Type 'help' for a list of commands.")
            term.setTextColor(colors.lime)
        end
        ::continue::
        print("")
        os.sleep()
    end
end

-- ============================================================================
-- Event handlers
-- ============================================================================

function Signal_Handler()
    while true do
        wait(function() return events.signaller_mes[1] ~= nil end)
        local mes = events.signaller_mes[1].data
        local id = events.signaller_mes[1].id
        table.remove(events.signaller_mes, 1)

        --[[
                class = "signaller",
                id = id,
                type = p.getSignalType(),
                state = p.getState(),
                is_force = p.isForcedRed(),
                block_train = p.listBlockingTrainNames()
        ]]


        if config.signallers[id] ~= nil then
            config.signallers[id].type = mes.type
            config.signallers[id].state = mes.state
            config.signallers[id].is_force = mes.is_force
            config.signallers[id].block_train = mes.block_train
            local line_id = config.signallers[id].line_id
            if type(line_id) == "table" then
                for i = 1, #line_id do
                    if line_id[i] then
                        config.lines[line_id[i]].occupied = (mes.state ~= "GREEN") and true or false
                        config.lines[line_id[i]].caution = (mes.state == "YELLOW") and true or false
                        config.lines[line_id[i]].text = mes.block_train[1] and mes.block_train[1] or ""
                    end
                end
            else
                config.lines[line_id].occupied = (mes.state ~= "GREEN") and true or false
                config.lines[line_id].caution = (mes.state == "YELLOW") and true or false
                config.lines[line_id].text = mes.block_train[1] and mes.block_train[1] or ""
            end
        end

        save_config()
        request_render()


        os.sleep()
    end
end

function Station_Handler()
    while true do
        wait(function() return events.station_mes[1] ~= nil end)
        local mes = events.station_mes[1].data
        local id = events.station_mes[1].id
        table.remove(events.station_mes, 1)


        if config.stations[id] ~= nil then
            config.stations[id].imm = mes.imm
            config.stations[id].pres = mes.pres
        end

        save_config()
        request_render()


        os.sleep()
    end
end

-- ============================================================================
-- Rendering
-- ============================================================================

function Render()
    while true do
        wait(function() return events["update_render"] ~= nil end)
        events["update_render"] = nil
        render_done = false
        term.setTextColor(colors.orange)
        -- print("\nRending...\n")
        reset_monitor()
        function render_grid()
            if show_grid then
                local size_x, size_y = monitor.getSize()
                for x = 1, size_x do
                    for y = 1, size_y do
                        local color = math.fmod(x + y, 2) == 0 and colors.cyan or colors.pink
                        drawPixel(x, y, color)
                    end
                end
            end
        end

        function render_lines()
            local r_lines = config.lines
            for i, line in pairs(r_lines) do
                local color = line.occupied and colors.red or colors.white
                color = line.caution and colors.yellow or color
                local start_x = line.start_x
                local start_y = line.start_y
                local end_x = line.end_x
                local end_y = line.end_y
                local text_x, text_y = line.text_x, line.text_y
                drawLine(start_x, start_y, end_x, end_y, color, show_id, i)
                if line.is_text then
                    drawChar(start_x + text_x, start_y + text_y, line.text, color, colors.lightBlue)
                end
            end
        end

        function render_stations()
            local r_stations = config.stations
            for id, station in pairs(r_stations) do
                local x, y, line, dir = station.x, station.y, station.line, station.dir
                local color = station.pres and colors.orange or (station.imm and colors.purple or colors.brown)
                if dir == "U" then
                    drawChar(x, y, show_id and id or "^", color, colors.white)
                elseif dir == "R" then
                    drawChar(x, y, show_id and id or ">", color, colors.white)
                elseif dir == "D" then
                    drawChar(x, y, show_id and id or "V", color, colors.white)
                elseif dir == "L" then
                    drawChar(x, y, show_id and id or "<", color, colors.white)
                end
            end
        end

        function render_signallers()
            local r_signallers = config.signallers
            for id, signaller in pairs(r_signallers) do
                local x, y, id, type, state, is_forced =
                    signaller.x, signaller.y, signaller.id, signaller.type, signaller.state, signaller.is_forced
                local char, back_color, text_color
                if not show_id then
                    char = (type == "ENTRY_SIGNAL") and "E" or "C"
                    back_color = (state == "YELLOW") and colors.yellow or
                        ((state == "GREEN") and colors.green or colors.red)
                    text_color = is_forced and colors.red or (state == "YELLOW") and colors.blue or colors.white
                else
                    char = id
                    back_color = colors.yellow
                    text_color = colors.white
                end
                drawChar(x, y, char, back_color, text_color)
            end
        end

        function render_texts()
            local r_texts = config.texts
            for id, text in pairs(r_texts) do
                local x, y, id, text, is_vertical = text.x, text.y, text.id, text.text, text.is_vertical

                if not show_id then
                    if not is_vertical then
                        drawChar(x, y, text, colors.black, colors.white)
                    else
                        for h = 1, #text do
                            drawChar(x, y + h - 1, text:sub(h, h), colors.black, colors.white)
                        end
                    end
                else
                    if not is_vertical then
                        drawChar(x, y, id, colors.black, colors.purple)
                    else
                        for h = 1, #text do
                            drawChar(x, y + h - 1, id:sub(h, h), colors.black, colors.purple)
                        end
                    end
                end
            end
        end

        render_grid()
        render_lines()
        render_signallers()
        render_stations()
        render_texts()
        -- term.setTextColor(colors.cyan)
        -- print("\nRender done!\n")
        term.setTextColor(colors.lime)
        render_done = true
    end
end

-- ============================================================================
-- Program entry point
-- ============================================================================

function Main()
    Init()
    while true do
        os.sleep()
    end
end

function modem_test()
    peripheral.find("modem", rednet.close)

    local modem = peripheral.find("modem")
    modem.open(os.getComputerID())

    local log = fs.open("log.txt", "w")
    log.write("")
    log.close()

    local log = fs.open("log.txt", "a")

    while true do
        local event, side, channel, replyChannel, message, distance =
            os.pullEvent("modem_message")

        print(
            "MODEM:",
            "side=" .. tostring(side),
            "channel=" .. tostring(channel),
            "reply=" .. tostring(replyChannel),
            "distance=" .. tostring(distance)
        )

        print(textutils.serialise(message))
        log.write(textutils.serialise(message) .. "\n")
        os.sleep()
    end
end

-- modem_test()

parallel.waitForAny(Main, Terminal, Render, Signal_Handler, Station_Handler, Transmit)
