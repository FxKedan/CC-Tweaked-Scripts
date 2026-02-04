--Replace "door.x.open" and "door.x.close" with the command id's you specified in the Host.

local color = colors.lime
local rsSide = "bottom"
local Protocol = "Arcdoor_Inc_Main"
local openCommandId, closeCommandId, lockdownCommandId = "door.x.open", "door.x.close", "facility.lockdown"
local seq_gearshift = peripheral.find("Create_SequencedGearshift")
peripheral.find("modem", rednet.open)

term.clear()
term.setCursorPos(1,1)
term.setTextColor(color)
print("---------------------------------------------------")
print("----------------DOOR CONTROL CLIENT--------ID:-----")
print("---------------------------------------------------")
print("--   ARCDOOR INDUSTRIES (TM) TERMLINK PROTOCOL   --")
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
print("-- ARCDOOR / OMNI LABS           UI Model 2.1.37 --")
print("---------------------------------------------------")
print("---------------------------------------------------")

local pcid = os.getComputerID()
term.setCursorPos(47,2)
print(""..pcid.."")

while true do
    local id, message = rednet.receive(Protocol, nil)
    if message == openCommandId then
        seq_gearshift.move(5,-1)
        rednet.send(id, "success", Protocol)
    elseif message == closeCommandId then
        seq_gearshift.move(5,1)
        rednet.send(id, "success", Protocol)
    elseif message == lockdownCommandId then
        seq_gearshift.move(5,1)
    end
end