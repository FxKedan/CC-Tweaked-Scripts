--Replace "boil.on" and "boil.off" with the command id's you specified in the Host.
--Create LastState.txt in the root directory before starting the program for the first time. Just save it as an empty file.

local color = colors.lime
local rsSide = "bottom"
local hostKey = "@z4dgHmDkAj5FqL"
local MainProtocol = "MainFacilityControl"
local commandidOn, commandidOff = "boil.on", "boil.off"
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
print("-------------FACILITY CONTROLS CLIENT--------------")
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
    local id, hostKeyR = rednet.receive("hostKey", nil)
    local id, message = rednet.receive(MainProtocol, nil)
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
end