peripheral.find("modem", rednet.open)

term.clear()
term.setCursorPos(1, 1)
print("=== DIAGNOSTIC SENDER ===")
print("Sweeping power 0% -> 100%")
print("Press Ctrl+T to terminate.")
print("-------------------------")

local protocols = {
    "thruster_1", "thruster_2", "thruster_3",
    "thruster_4", "thruster_5", "thruster_6",
    "thruster_main"
}

local tick = 0

while true do
    -- Generates a smooth oscillating wave between 0 and 100
    local testPower = (math.sin(tick) + 1) * 50
    
    -- Update the display
    term.setCursorPos(1, 6)
    term.clearLine()
    print(string.format("Broadcasting: %.2f%%", testPower))
    
    -- Blast the test value to every thruster protocol
    for i = 1, #protocols do
        rednet.broadcast(testPower, protocols[i])
    end
    
    -- Advance the math and wait 0.1 seconds (10 updates per second)
    tick = tick + 0.1
    os.sleep(0.1)
end