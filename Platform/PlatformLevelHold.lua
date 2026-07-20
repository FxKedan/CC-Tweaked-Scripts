-- ============================================================================
-- SECTION 1: CONFIGURATION & GAINS
-- ============================================================================

peripheral.find("modem", rednet.open)

local altitude_sensor = peripheral.find("altitude_sensor")
local gimbal_sensor = peripheral.find("gimbal_sensor")
local mass_sensor = peripheral.find("physics_assembler")

local TARGET_ALTITUDE = 100.0
local BASE_CONTROL_POWER = 20.0
local TARGET_PITCH, TARGET_ROLL = 0, 0

local GAINS = {
    pitch = { kp = 2.5, kd = 0.5 },
    roll  = { kp = 2.5, kd = 0.5 },
    alt   = { kp = 1.8, kd = 0.8 }
}

local THRUSTER_ANGLES = {
    math.rad(0),   math.rad(60),  math.rad(120),
    math.rad(180), math.rad(240), math.rad(300)
}

-- ============================================================================
-- SECTION 2: SENSOR & ACTUATOR INTERFACE
-- ============================================================================

local function readSensors()
    local pitch, roll = gimbal_sensor.getAngles()
    local altitude = altitude_sensor.getHeight()
    local velocity = altitude_sensor.getVerticalSpeed()
    local mass = mass_sensor.getMass()

    return {
        pitch    = pitch,
        roll     = roll,
        altitude = altitude,
        velocity = velocity,
        mass     = mass
    }
end

local function applyMainThrust(percent)
    rednet.broadcast(percent, "thruster_main")
end

local function applyControlThrust(outputs)
    for i = 1, 6 do
        -- Broadcasts only to computers listening on protocol "thruster_1", "thruster_2", etc.
        rednet.broadcast(outputs[i], "thruster_" .. i)
    end
end

-- ============================================================================
-- SECTION 3: CONTROLLER ENGINE (PD)
-- ============================================================================

local function createPDController(gains)
    local lastError = 0
    return function(target, current, dt, directVelocity)
        local err = target - current
        -- Use sensor velocity directly if available, otherwise calculate rate
        local rate = directVelocity or ((err - lastError) / dt)
        lastError = err
        
        return (gains.kp * err) + (gains.kd * rate)
    end
end

local pitchController = createPDController(GAINS.pitch)
local rollController  = createPDController(GAINS.roll)
local altController   = createPDController(GAINS.alt)

-- ============================================================================
-- SECTION 4 & 5: MIXING & FEEDFORWARD FUNCTIONS
-- ============================================================================

local function calculateMainPower(state, uAlt)
    -- Feedforward mass compensation + altitude adjustment
    local baseLift = state.mass * 0.1 -- Multiplier scaled to Create physics
    return baseLift + uAlt
end

local function calculateControlMix(uPitch, uRoll)
    local outputs = {}
    for i = 1, 6 do
        local angle = THRUSTER_ANGLES[i]
        local delta = (uPitch * math.cos(angle)) + (uRoll * math.sin(angle))
        
        -- Add baseline and clamp 0-100%
        outputs[i] = math.max(0, math.min(100, BASE_CONTROL_POWER + delta))
    end
    return outputs
end

-- ============================================================================
-- SECTION 6: MAIN CONTROL LOOP
-- ============================================================================

local lastTime = os.epoch("utc") / 1000.0

while true do
    -- 1. Calculate Delta Time
    local currentTime = os.epoch("utc") / 1000.0
    local dt = math.max(0.05, currentTime - lastTime)
    lastTime = currentTime

    -- 2. Read Sensors
    local state = readSensors()

    -- 3. Calculate Control Forces (u)
    local uPitch = pitchController(TARGET_PITCH, state.pitch, dt)
    local uRoll  = rollController(TARGET_ROLL, state.roll, dt)
    local uAlt   = altController(TARGET_ALTITUDE, state.altitude, dt, -state.velocity)

    -- 4. Calculate Outputs
    local mainPower = calculateMainPower(state, uAlt)
    local controlOutputs = calculateControlMix(uPitch, uRoll)

    -- 5. Write to Hardware
    applyMainThrust(mainPower)
    applyControlThrust(controlOutputs)

    -- 6. Yield to computer clock (20Hz)
    os.sleep(0.05)
end