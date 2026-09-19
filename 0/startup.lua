function Init()
    monitor = peripheral.find("monitor")

    peripheral.find("modem", rednet.close)
    peripheral.find("modem", rednet.open)

    monitor.setTextScale(0.5)
    monitor.setCursorPos(1, 1)
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.clear()
    term.clear()
    term.setCursorPos(1, 1)
    local file = fs.open("config.json", "r")
    if not file then
        local file = fs.open("config.json", "w")
        file.write(textutils.serialiseJSON({ stations = {}, lines = {}, signallers = {} }))
        file.close()
    else
        file.close()
    end
    local file = fs.open("config.json", "r")
    config = textutils.unserializeJSON(file.readAll())
    file.close()

    events = {}
    render_done = true

    show_id = false
end

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
    for x = start_x, end_x do
        local y = round(func_exp(start_x, start_y, end_x, end_y, x))
        local last_y = round(func_exp(start_x, start_y, end_x, end_y, x - 1))
        if x ~= start_x then
            for comp = math.min(y, last_y), math.max(y, last_y) do
                if not show_id then
                    drawPixel(x, comp, color)
                else
                    monitor.setCursorPos(x, comp)
                    monitor.write(id)
                end
            end
        else
            if not show_id then
                drawPixel(x, y, color)
            else
                monitor.setCursorPos(x, y)
                monitor.write(id)
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

function transmit()

end

function terminal()
    term.setTextColor(colors.lightBlue)
    term.write("Signaller System|" .. os.getComputerID() .. " > Type 'help' for commands")
    term.setTextColor(colors.lime)
    print("\n\n")
    local completion = require("cc.completion")
    local commands = {
        "shutdown",
        "reboot",
        "help",
        "add_station",
        "remove_station",
        "reset_config",
        "show_config",
        "refresh_render",
        "scale",
        "render_move",
        "element_move",
        "add_line",
        "remove_line",
        "toggle_show_id"
    }
    local history
    while true do
        term.setTextColor(colors.lime)
        write("Signaller System|" .. os.getComputerID() .. " > ")
        local command = read(nil, history, function(text) return completion.choice(text, commands) end, nil)
        print("")
        if command == "shutdown" then
            os.shutdown()
        elseif command == "reboot" then
            os.reboot()
        elseif command == "help" then
            term.setTextColor(colors.yellow)
            print("Commands:")
            print("help - Show this help message")
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
            print("toggle_show_id - Toggle showing IDs of lines on the monitor")
            term.setTextColor(colors.lime)
        elseif command == "add_station" then
            write("Station ID:")
            local station_id = read()
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
                dir = station_dir
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
            events["update_render"] = true
            wait(function() return render_done end)
        elseif command == "remove_station" then
            write("Station ID:")
            local station_id = read()
            config.stations[station_id] = nil
            local file = fs.open("config.json", "w")
            file.write(textutils.serialiseJSON(config))
            file.close()
            events["update_render"] = true
            wait(function() return render_done end)
        elseif command == "reset_config" then
            print("Are you sure to")
            term.blit(" reset the config? (y/n):", "eeeeeeeeeeeeeeeeeeeeeeeee", "fffffffffffffffffffffffff")
            local confirm = read()
            if confirm == "y" then
                config = { stations = {}, lines = {}, signallers = {} }
                local file = fs.open("config.json", "w")
                file.write(textutils.serialiseJSON(config))
                file.close()
                events["update_render"] = true
                wait(function() return render_done end)
            end
        elseif command == "show_config" then
            term.setTextColor(colors.yellow)
            print(textutils.serialiseJSON(config))
            term.setTextColor(colors.lime)
        elseif command == "refresh_render" then
            events["update_render"] = true
            wait(function() return render_done end)
        elseif command == "scale" then
            write("Set scale (0.5-5):")
            local scale = tonumber(read())
            if scale and scale >= 0.5 and scale <= 5 then
                monitor.setTextScale(scale)
                events["update_render"] = true
                wait(function() return render_done end)
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
                local file = fs.open("config.json", "w")
                file.write(textutils.serialiseJSON(config))
                file.close()
                events["update_render"] = true
                wait(function() return render_done end)
            else
                term.setTextColor(colors.red)
                print("\nInvalid coordinates. Please enter in the format x,y where x and y are numbers.")
                term.setTextColor(colors.lime)
            end
        elseif command == "element_move" then
            write("Move element (class(stations/lines/signallers),id) to (x,y):")
            local input = read()
            local class, index, x, y = input:match("(%a+),(%w+),(%d+),(%d+)")
            x, y = tonumber(x), tonumber(y)
            if class and index and x and y and config[class] and config[class][index] then
                config[class][index].x = x
                config[class][index].y = y
                local file = fs.open("config.json", "w")
                file.write(textutils.serialiseJSON(config))
                file.close()
                events["update_render"] = true
                wait(function() return render_done end)
            else
                term.setTextColor(colors.red)
                print("\nInvalid input. Please enter in the format class,index,x,y where class and index exist.")
                term.setTextColor(colors.lime)
            end
        elseif command == "add_line" then
            write("Line ID:")
            local line_id = read()

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
                    occupied = false
                }
                local file = fs.open("config.json", "w")
                file.write(textutils.serialiseJSON(config))
                file.close()
                events["update_render"] = true
                wait(function() return render_done end)
            else
                term.setTextColor(colors.red)
                print("\nInvalid input. Please enter valid line ID and coordinates.")
                term.setTextColor(colors.lime)
            end
        elseif command == "remove_line" then
            write("Line ID:")
            local line_id = read()
            config.lines[line_id] = nil
            local file = fs.open("config.json", "w")
            file.write(textutils.serialiseJSON(config))
            file.close()
            events["update_render"] = true
            wait(function() return render_done end)
        elseif command == "toggle_show_id" then
            show_id = not show_id
            events["update_render"] = true
            wait(function() return render_done end)
        else
            term.setTextColor(colors.red)
            print("\nUnknown command. Type 'help' for a list of commands.")
            term.setTextColor(colors.lime)
        end
        print("")
        os.sleep()
    end
end

function render()
    while true do
        wait(function() return events["update_render"] ~= nil end)
        events["update_render"] = nil
        render_done = false
        term.setTextColor(colors.orange)
        print("\nRendering...\n")
        reset_monitor()
        function render_lines()
            local r_lines = config.lines
            for i, line in pairs(r_lines) do
                local start_x, start_y, end_x, end_y = line.start_x, line.start_y, line.end_x, line.end_y
                local text_x, text_y, is_text = line.text_x, line.text_y, line.is_text
                local occupied = line.occupied
                local color = occupied and colors.red or colors.white
                drawLine(start_x, start_y, end_x, end_y, color, show_id, i)
            end
        end

        function render_stations()
            local r_stations = config.stations
            for id, station in pairs(r_stations) do
                local x, y, line, dir = station.x, station.y, station.line, station.dir
                monitor.setCursorPos(x, y)
                if dir == "U" then
                    monitor.write("^")
                elseif dir == "R" then
                    monitor.write(">")
                elseif dir == "D" then
                    monitor.write("v")
                elseif dir == "L" then
                    monitor.write("<")
                end
            end
        end

        render_lines()
        render_stations()
        term.setTextColor(colors.cyan)
        print("\nRender done!\n")
        term.setTextColor(colors.lime)
        render_done = true
    end
end

function Main()
    Init()
    while true do
        os.sleep()
    end
end

parallel.waitForAny(Main, terminal, render)
