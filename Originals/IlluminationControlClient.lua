--Replace "RoomX" with the room name you specified in the Host.
--Create LastState.txt in the root directory before starting the program for the first time. Just save it as an empty file.

local color = colors.lime
local rsSide = "back"
local hostKey = "@z4dgHmDkAj5FqL"
local PowerStatusProtocol = "PowerStatus"
local MainProtocol = "MainFacilityControl"
local commandidOn, commandidOff = "on.light.RoomX", "off.light.RoomX"
peripheral.find("modem", rednet.open)

function ApplyLastState()
    if LastState == "on" then
        rs.setOutput(rsSide, true)
    elseif LastState == "off" then
        rs.setOutput(rsSide, false)
    else
    end
end

local file = fs.open("LastState.txt", "r")
LastState = file.readAll()
ApplyLastState()

term.clear()
term.setCursorPos(1,1)
term.setTextColor(color)
print("---------------------------------------------------")
print("-----------ILLUMINATION CONTROLS CLIENT------------")
print("---------------------------------------------------")
print("--    ROBCO INDUSTRIES (TM) TERMLINK PROTOCOL    --")
print("--                                               --")
print("--                                               --")
print("--                                               --")
print("--                                               --")
print("--                                               --")
print("--       THIS IS A RECEIVER. DO NOT TOUCH.       --")
print("--          HOW DID YOU EVEN GET HERE?           --")
print("--                                               --")
print("--                                               --")
print("--                                               --")
print("--                                               --")
print("--                                               --")
print("-- ROBCO / VAULT-TEC                UI Model 1.3 --")
print("---------------------------------------------------")
print("---------------------------------------------------")

while true do
    while true do
        local id, message = rednet.receive(PowerStatusProtocol, 0.5)
        if message == "false" then
            rs.setOutput(rsSide, false)
            --Implement emergency lights here
        elseif message == "true" then
            ApplyLastState()
            break
        else
            rs.setOutput(rsSide, false)
        end
    end

    local id, hostKeyR = rednet.receive("hostKey", 1)
    local id, message = rednet.receive(MainProtocol, 0.05)
    if message == commandidOn and hostKeyR == hostKey then
        rs.setOutput(rsSide, true)
        rednet.send(id, "success", MainProtocol)
        LastStateW = "on"
        local file = fs.open("LastState.txt", "w+")
        file.write(LastStateW)
        file.close()
    elseif message == commandidOff and hostKeyR == hostKey then
        rs.setOutput(rsSide, false)
        rednet.send(id, "success", MainProtocol)
        LastStateW = "off"
        local file = fs.open("LastState.txt", "w+")
        file.write(LastStateW)
        file.close()
    end

    local file = fs.open("LastState.txt", "r")
    LastState = file.readAll()
end