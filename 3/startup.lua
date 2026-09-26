computer_id = os.getComputerID()

term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)
peripheral.find("modem", rednet.close)
peripheral.find("modem", rednet.open)

::invalid_class::

write("Class:")
class = read()
if class ~= "station" and class ~= "signaller" then
    print("\nInvaild class (station,signaller)")
    goto invalid_class
end
write("\nHost PC ID:")

::invalid_target::

target = read()
target = tonumber(target)
if not target then
    print("\nInvalid target")
    goto invalid_target
end

write("\nDevice ID:")

::invalid_id::

id = read()
if not tonumber(id) then
    print("\nInvalid ID")
    goto invalid_id
end


function Send()
    local data = {}
    local last_data = {}
    local num = 1
    while true do
        ::back_loop::
        os.sleep()

        if class == "station" then
            local p = peripheral.find("Create_Station")

            if not p.isTrainPresent() then
                data = {
                    class = "station",
                    id = id,
                    imm = false,
                    pres = false,
                    has_sch = false,
                    sch = {},
                    train_name = ""
                }
                if not tableEqual(data, last_data) then
                    Handshake(target, data)
                    last_data = data
                end
                goto back_loop
            end

            data = {
                class = "station",
                id = id,
                imm = p.isTrainImminent(),
                pres = p.isTrainPresent(),
                has_sch = p.hasSchedule()
            }

            if p.hasSchedule() then data.sch = p.getSchedule() end
            if p.isTrainPresent() then data.train_name = p.getTrainName() end

            if tableEqual(data, last_data) then
                goto back_loop
            end
            print(textutils.serialiseJSON(data))
            print(num)
            num = num + 1
            Handshake(target, data)
            last_data = data
        elseif class == "signaller" then
            local p = peripheral.find("Create_Signal")

            data = {
                class = "signaller",
                id = id,
                type = p.getSignalType(),
                state = p.getState(),
                is_force = p.isForcedRed(),
                block_train = p.listBlockingTrainNames()
            }

            if tableEqual(data, last_data) then
                goto back_loop
            end
            local invalid = (data.state == "GREEN" and not tableEqual(data.block_train, {})) or
                (data.state == "RED" and tableEqual(data.block_train, {})) or
                (data.state == "YELLOW" and not tableEqual(data.block_train, {}))
            if invalid then
                goto back_loop
            end
            print(not invalid)
            print(textutils.serialiseJSON(data))
            print(num)
            num = num + 1
            Handshake(target, data)
            last_data = data
        end
        os.sleep()
    end
end

function Recive()
    while true do
        ::back_loop::
        os.sleep()
    end
end

function Handshake(target, data)
    repeat
        rednet.send(target, "SYNC", "SYNC_To_" .. target)
        local id, mes = rednet.receive("SYNC_CON_To_" .. computer_id, 0.5)
    until mes
    rednet.send(target, data, "DATA_To_" .. target)
    local id, mes = rednet.receive("ACK_To_" .. computer_id, 0.5)
end

function tableEqual(t1, t2)
    -- 引用相同，直接相等
    if t1 == t2 then return true end

    -- 类型不同（比如一个是 table 一个不是）
    if type(t1) ~= "table" or type(t2) ~= "table" then
        return false
    end

    -- 比较 t1 中每个键值
    for k, v in pairs(t1) do
        if not tableEqual(v, t2[k]) then
            return false
        end
    end

    -- 检查 t2 是否有 t1 没有的键
    for k in pairs(t2) do
        if t1[k] == nil then
            return false
        end
    end

    return true
end

parallel.waitForAny(Send, Recive)
