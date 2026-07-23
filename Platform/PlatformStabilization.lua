-- put a monitor on top of the computer or change the monitor variable
-- also change the MOTOR_ variables to match your setup
-- alt_kp, ki and kd need to be tuned
-- stab_kp, ki and kd also need to be tuned
-- try not tuning first, maybe it works, we'll never know

-- CONFIG
local TARGET_ALT = -5

local MONITOR_SIDE = "top"

peripheral.find("modem", rednet.open)

-- Altitude PID
local ALT_KP = 3.0
local ALT_KI = 0.1
local ALT_KD = 2.0

-- Stabilization PID
local STAB_KP = 0.8
local STAB_KI = 0.005
local STAB_KD = 0.35

-- Stabilization correction limits
local STAB_CORR_MIN, STAB_CORR_MAX = -60, 60
local STAB_INTEG_MIN, STAB_INTEG_MAX = -50, 50

-- Disturbance detection: when a large sudden tilt spike occurs (plane landing or departing)
local DISTURBANCE_THRESHOLD = 3.0
local INTEGRAL_BLEED        = 0.3

-- Motor limits
local LIFT_THRUSTER_MIN, LIFT_THRUSTER_MAX = 0, 100  -- Your big central engine
local CTRL_THRUSTER_MIN, CTRL_THRUSTER_MAX = 0, 100   -- Your corner RCS thrusters

-- Workload Distribution (70% Main Engine, 30% Control Thrusters)
local LIFT_RATIO = 0.70
local CTRL_RATIO = 0.30

-- Altitude correction limits
local ALT_CORR_MIN, ALT_CORR_MAX = -100, 100
local ALT_INTEG_MIN, ALT_INTEG_MAX = -60, 60

-- k: max thrust capacity (in Newtons) when throttle is 1.0:
--    thrust = k * throttle
local k_main = 30240
local k_ctrl = 8320

-- SETUP
local pid     = require("pid")
local monitor = peripheral.wrap(MONITOR_SIDE)

-- Gimbal - .getAngles()
-- a[1] --> yaw (+ left, - right)
-- a[2] --> pitch (+ up, - down)
local gimbal = peripheral.find("gimbal_sensor")
local altitude_sensor = peripheral.find("altitude_sensor")
local physics_assembler = peripheral.find("physics_assembler")

if not monitor then error("No monitor")   end
if not gimbal then error("No gimbal")     end
if not altitude_sensor then error("No altitude sensor") end
if not physics_assembler then error("No physics assembler") end

monitor.setTextScale(0.5)
monitor.clear()

local altPID = pid.new(TARGET_ALT, ALT_KP, ALT_KI, ALT_KD)
altPID:clampOutput(ALT_CORR_MIN, ALT_CORR_MAX)
altPID:limitIntegral(ALT_INTEG_MIN, ALT_INTEG_MAX)

local rollPID  = pid.new(0, STAB_KP, STAB_KI, STAB_KD)
local pitchPID = pid.new(0, STAB_KP, STAB_KI, STAB_KD)
rollPID:limitIntegral(STAB_INTEG_MIN, STAB_INTEG_MAX)
pitchPID:limitIntegral(STAB_INTEG_MIN, STAB_INTEG_MAX)
rollPID:clampOutput(STAB_CORR_MIN, STAB_CORR_MAX)
pitchPID:clampOutput(STAB_CORR_MIN, STAB_CORR_MAX)

-- HELPERS
local function displayLine(row, text)
    monitor.setCursorPos(1, row)
    monitor.clearLine()
    monitor.write(text)
end

-- Clampinsons
local function clamp(val, min, max)
    return math.max(min, math.min(max, val))
end

-- Set thruster output
local function setThrusterOutput(N, NE, E, SE, S, SW, W, NW, Lift)
    rednet.broadcast(N, "thruster_3")
    rednet.broadcast(NE, "thruster_2")
    rednet.broadcast(E, "thruster_1")
    rednet.broadcast(SE, "thruster_8")
    rednet.broadcast(S, "thruster_7")
    rednet.broadcast(SW, "thruster_6")
    rednet.broadcast(W, "thruster_5")
    rednet.broadcast(NW, "thruster_4")
    rednet.broadcast(Lift, "thruster_main")
end

--- Calculates feedforward throttle signal needed to hover/maintain weight
local function getFeedforward(mass, gravity)
    local targetForce = mass * gravity
    local liftForce = targetForce * LIFT_RATIO
    local ctrlForce = (targetForce * CTRL_RATIO) / 8
    local liftThrottle = liftForce / k_main
    local ctrlThrottle = ctrlForce / k_ctrl

    return liftThrottle, ctrlThrottle
end

-- Control loop
local function controlLoop()
    local lastTime = os.clock()
    local prevVelY = 0

    while true do
        local now = os.clock()
        local dt  = math.max(now - lastTime, 0.001)
        lastTime  = now

        -- Taking the data
        local pos_y      = altitude_sensor.getHeight()
        local angVel     = gimbal.getAngularRates()
        local mass       = physics_assembler.getMass()
        local gravityVec = gimbal.getGravity()
        local gravity    = math.abs(gravityVec[2])
        local velY       = altitude_sensor.getVerticalSpeed()
        local com        = physics_assembler.getCenterOfMass()

        -- Vertical acceleration for k and feedforward
        local vertAccel = (velY - prevVelY) / dt
        prevVelY = velY

        --local acceleration = gimbal.getLinearAcceleration()
        --local vertAccel    = math.abs(acceleration[2])

        -- Altitude
        local liftThrottle, ctrlThrottle = getFeedforward(mass, gravity)
        local liftThrottle, ctrlThrottle = liftThrottle * 100, ctrlThrottle * 100
        local altCorr = altPID:step(pos_y, dt) - ALT_KD * velY
        local liftBase = liftThrottle + (altCorr * LIFT_RATIO)
        local ctrlBase = ctrlThrottle + (altCorr * CTRL_RATIO)

        -- Stabilization
        local tiltErr = gimbal.getAngles()
        local rollErr = tiltErr[1]
        local pitchErr = tiltErr[2]

        -- If detect large sudden tilt bleed integral
        if math.abs(rollErr) > DISTURBANCE_THRESHOLD then
            rollPID.integral = rollPID.integral * INTEGRAL_BLEED
        end
        if math.abs(pitchErr) > DISTURBANCE_THRESHOLD then
            pitchPID.integral = pitchPID.integral * INTEGRAL_BLEED
        end

        -- PID outputs with derivative damping based on angular velocity
        local rollOutput  = rollPID:step(rollErr, dt)  - STAB_KD * angVel[3]
        local pitchOutput = pitchPID:step(pitchErr, dt) - STAB_KD * angVel[1]

        rollOutput  = clamp(rollOutput,  STAB_CORR_MIN, STAB_CORR_MAX)
        pitchOutput = clamp(pitchOutput, STAB_CORR_MIN, STAB_CORR_MAX)

        -- Motor mixing for 8-axis octagonal setup + 1 Central Lift
        -- Note: If axes are inverted, simply swap the + and - for pitchOutput or rollOutput here.
        -- Lift motor handles the vertical Feedforward and Altitude PID

        -- Control thrusters need an "idle" state (e.g., halfway to their max) 
        -- so they can throttle up to push a corner up, or throttle down to drop a corner.
        local diagPitch = pitchOutput * 0.707
        local diagRoll  = rollOutput * 0.707

        -- The central engine only handles its share of the altitude base
        local Lift = liftBase

        -- The control thrusters combine their share of the altitude base with the PID stabilization
        local N  = clamp(ctrlBase + pitchOutput, CTRL_THRUSTER_MIN, CTRL_THRUSTER_MAX)
        local S  = clamp(ctrlBase - pitchOutput, CTRL_THRUSTER_MIN, CTRL_THRUSTER_MAX)
        local E  = clamp(ctrlBase + rollOutput, CTRL_THRUSTER_MIN, CTRL_THRUSTER_MAX)
        local W  = clamp(ctrlBase - rollOutput, CTRL_THRUSTER_MIN, CTRL_THRUSTER_MAX)

        local NE = clamp(ctrlBase + diagPitch + diagRoll, CTRL_THRUSTER_MIN, CTRL_THRUSTER_MAX)
        local NW = clamp(ctrlBase + diagPitch - diagRoll, CTRL_THRUSTER_MIN, CTRL_THRUSTER_MAX)
        local SE = clamp(ctrlBase - diagPitch + diagRoll, CTRL_THRUSTER_MIN, CTRL_THRUSTER_MAX)
        local SW = clamp(ctrlBase - diagPitch - diagRoll, CTRL_THRUSTER_MIN, CTRL_THRUSTER_MAX)

        setThrusterOutput(N, NE, E, SE, S, SW, W, NW, Lift)
        
        local k = k_main + (k_ctrl * 8)  -- Total thrust capacity
        local ff_ctrl = ctrlThrottle

        -- Display update
        displayLine(1,  "Target: " .. TARGET_ALT .. " m")
        displayLine(2,  string.format("Alt:   %6.2f m",    pos_y))
        displayLine(3,  string.format("Err:  %+6.2f m",    TARGET_ALT - pos_y))
        displayLine(4,  string.format("FF Lift:   %+6.2f",  liftThrottle))
        displayLine(5,  string.format("FF Ctrl:   %+6.2f",  ff_ctrl))
        displayLine(6,  string.format("Corr: %+6.2f",  altCorr))
        displayLine(7,  string.format("Lift Base: %+6.2f",  liftBase))
        displayLine(8,  string.format("Ctrl Base: %+6.2f",  ctrlBase))
        displayLine(9,  string.format("Lift Throttle: %+6.2f",  liftThrottle))
        displayLine(10, string.format("Ctrl Throttle: %+6.2f",  ctrlThrottle))
        displayLine(11, string.format("Roll: %+6.2f deg / Out: %+5.1f", rollErr, rollOutput))
        displayLine(12, string.format("Ptch: %+6.2f deg / Out: %+5.1f", pitchErr, pitchOutput))
        
        -- Updated thruster display for the octagonal array
        displayLine(13,  string.format("N:%+4.0f S:%+4.0f E:%+4.0f W:%+4.0f", N, S, E, W))
        displayLine(14, string.format("NE:%+4.0f NW:%+4.0f SE:%+4.0f SW:%+4.0f", NE, NW, SE, SW))
        displayLine(15, string.format("Lift: %+4.0f", Lift))
        
        displayLine(16, string.format("K:  %.6f", k) or "K:  (warmup)")
        displayLine(17, string.format("CoM: %.2f %.2f %.2f", com[1], com[2], com[3]))
        displayLine(18, string.format("Mass: %.2f kg", mass))
        --displayLine(19, string.format("Grav: %.2f m/s²", gravity))
        --displayLine(20, string.format("Weight: %.2f N", mass * gravity))
        --displayLine(21, string.format("VelY: %.2f m/s", velY))
        --displayLine(22, string.format("VertAccel: %.2f m/s²", vertAccel))

        sleep(0.05)
    end
end

-- User input loop
local function inputLoop()
    while true do
        io.write("New altitude: ")

        local input = read()
        local newAlt = tonumber(input)

        if newAlt then
            TARGET_ALT = newAlt
            altPID.sp  = newAlt
            altPID.integral   = 0
            altPID.prev_error = 0
            print("Target set to " .. newAlt .. " m")
        else
            -- Fixed termination arguments to shutdown all 9 motors correctly
            setThrusterOutput(0, 0, 0, 0, 0, 0, 0, 0, 0)
            error("Terminated")
        end
    end
end

-- Run both loops in parallel
parallel.waitForAny(controlLoop, inputLoop)