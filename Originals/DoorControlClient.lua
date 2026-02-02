--Replace "door.x.open" and "door.x.close" with the command id's you specified in the Host.

local color = colors.lime
local rsSide = "bottom"
local hostKey = "@z4dgHmDkAj5FqL"
local MainProtocol = "MainFacilityControl"
local commandidOpen, commandidClose, commandidLockdown = "door.x.open", "door.x.close", "facility.lockdown"
local seq_gearshift = peripheral.find("Create_SequencedGearshift")
peripheral.find("modem", rednet.open)

term.clear()
term.setCursorPos(1,1)
term.setTextColor(color)
print("---------------------------------------------------")
print("----------------DOOR CONTROL CLIENT----------------")
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
    if message == commandidOpen and hostKeyR == hostKey then
        seq_gearshift.move(5,-1)
        rednet.send(id, "success", MainProtocol)
    elseif message == commandidClose and hostKeyR == hostKey then
        seq_gearshift.move(5,1)
        rednet.send(id, "success", MainProtocol)
    elseif message == commandidLockdown and hostKeyR == hostKey then
        seq_gearshift.move(5,1)
        rednet.send(id, "success", MainProtocol)
    end
end