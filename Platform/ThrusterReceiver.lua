local args = {...}
local thrusterID = args[1]

if not thrusterID then
    print("Error: No ID provided.")
    print("Run program like this: startup 1")
    return
end

peripheral.find("modem", rednet.open)
local thruster = peripheral.find("ion_thruster")

local protocol = "thruster_" .. thrusterID

-- Clean the screen and set up a static UI
term.clear()
term.setCursorPos(1, 1)
print("=== THRUSTER CONTROL ===")
print("ID: " .. thrusterID)
print("Protocol: " .. protocol)
print("------------------------")
print("Current Thrust: Waiting...")

while true do
    local senderId, receivedThrust = rednet.receive(protocol)
    
    if type(receivedThrust) == "number" then
        -- Apply to hardware
        local normalizedThrust = receivedThrust / 100
        thruster.setPowerNormalized(normalizedThrust)
        
        -- Update the display continuously on line 5
        term.setCursorPos(1, 5)
        term.clearLine()
        
        -- Use string.format to keep it rounded to 2 decimal places
        print(string.format("Current Thrust: %.2f%%", receivedThrust))
    end
end