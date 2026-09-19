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

    events = {}
    render_done = true

    show_id = false
end

-- ============================================================================
-- Configuration helpers
-- ============================================================================

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

function Transmit()
    while true do
        os.sleep()
    end
end

-- ============================================================================
-- Terminal / command interface
-- ============================================================================

function Terminal()
    term.setTextColor(colors.lightBlue)
    term.write("Signaller System | " .. os.getComputerID() .. " > Type 'help' for commands")
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
        "add_signaller",
        "add_text",
        "remove_text",
        "toggle_show_id"
    }
    local history
    while true do
        term.setTextColor(colors.lime)
        write("Signaller System | " .. os.getComputerID() .. " > ")
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
            write("Move element (class(stations/lines/signallers),id) to (x,y):")
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
                save_config()
                request_render()
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
            if config.lines[line_id] == nil then
                term.setTextColor(colors.red)
                print("Line doesn't exist")
                term.setTextColor(colors.lime)
                goto continue
            end
            write("\nSignaller pos (x,y):")
            local signaller_pos = read()
            local signaller_x, signaller_y = signaller_pos:match("(%d+),(%d+)")
            signaller_x, signaller_y = tonumber(signaller_x), tonumber(signaller_y)
            if signaller_x and signaller_y then
                config.signallers[signaller_id] = {
                    id = signaller_id,
                    line_id = line_id,
                    x = signaller_x,
                    y = signaller_y
                }
                save_config()
                request_render()
            end
        elseif command == "add_text" then
            write("Text ID:")
            local text_id = read()
            if config.texts[text_id] ~= nil then
                term.setTextColor(colors.red)
                print("Text ID is occupied")
                term.setTextColor(colors.lime)
                goto continue
            end
            write("Text:")
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
        os.sleep()
    end
end

function Station_Handler()
    while true do
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
        print("\nRendering...\n")
        reset_monitor()
        function render_lines()
            local r_lines = config.lines
            for i, line in pairs(r_lines) do
                local color = line.occupied and colors.red or colors.white
                drawLine(start_x, start_y, end_x, end_y, color, show_id, i)
            end
        end

        function render_stations()
            local r_stations = config.stations
            for id, station in pairs(r_stations) do
                local x, y, line, dir = station.x, station.y, station.line, station.dir
                monitor.setCursorPos(x, y)
                if dir == "U" then
                    monitor.blit("^", "0", "c")
                elseif dir == "R" then
                    monitor.blit(">", "0", "c")
                elseif dir == "D" then
                    monitor.blit("v", "0", "c")
                elseif dir == "L" then
                    monitor.blit("<", "0", "c")
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

-- ============================================================================
-- Program entry point
-- ============================================================================

function Main()
    Init()
    while true do
        os.sleep()
    end
end

parallel.waitForAny(Main, Terminal, Render, Signal_Handler, Station_Handler, Transmit)
