local color = colors.lime
local rsSide = "back"
local hostKey = "@z4dgHmDkAj5FqL"
local PowerStatusProtocol = "PowerStatus"
local MainProtocol = "MainFacilityControl"
local commandidOn, commandidOff = "on.light.X", "off.light.X"
rednet.open("top")

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
file.close()
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
    elseif message == commandidOff and hostKeyR == hostKey then
        rs.setOutput(rsSide, false)
        rednet.send(id, "success", MainProtocol)
        LastStateW = "off"
    end
    local file = fs.open("LastState.txt", "w+")
    file.write(LastStateW)
    file.close()
end