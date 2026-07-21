-- ============================================================================
-- SECTION 1: CONFIGURATION & GAINS
-- ============================================================================

peripheral.find("modem", rednet.open)

local altitude_sensor = peripheral.find("altitude_sensor")
local gimbal_sensor   = peripheral.find("gimbal_sensor")
local mass_sensor     = peripheral.find("physics_assembler")

-- Rig Constants
local MAIN_THRUSTER_MAX_FORCE    = 30240.0
local CONTROL_THRUSTER_MAX_FORCE = 8320.0
local BASELINE_MASS              = 4168.0 
local GRAVITY                    = 11.0 -- Adjust to 9.81 if environment uses standard g

-- Dynamic Flight Targets
local TARGET_ALTITUDE = -30.0 -- Usually positive unless your world frame is inverted
local TARGET_PITCH    = 0.0
local TARGET_ROLL     = 0.0

local MIN_POWER_THRESHOLD = 6.5    -- Hardware ignition threshold (%)
local BASE_CONTROL_POWER  = 40.0    -- Virtual base (%)
local MAX_CONTROL_DELTA   = 30.0    -- Moderate differential range (%)

-- Body Frame Alignment Configuration
local FRAME_OFFSET_DEG = 0
local INVERT_PITCH     = false
local INVERT_ROLL      = false

local GAINS = {
    pitch = { kp = 2.50, ki = 0.00, kd = 0.5, iLimit = 0.0 },
    roll  = { kp = 2.50, ki = 0.00, kd = 0.5, iLimit = 0.0 },
    alt   = { kp = 1.80, ki = 0.20, kd = 0.80, iLimit = 30.0 }
}

-- 8 thrusters in body frame (0 deg = Nominal Forward / Pitch Axis)
local THRUSTER_ANGLES = {
    math.rad(0),   math.rad(45),  math.rad(90),  math.rad(135),
    math.rad(180), math.rad(225), math.rad(270), math.rad(315)
}

-- ============================================================================
-- SECTION 2: UI DISPLAY DASHBOARD
-- ============================================================================

local function initUI()
    term.clear()
    term.setCursorPos(1, 1)
    print("========================================")
    print("      FLIGHT COMPUTER CONTROL SYSTEM    ")
    print("========================================")
    print(string.format(" TARGETS  | Alt:%5.1fm | P:%4.1f | R:%4.1f", TARGET_ALTITUDE, TARGET_PITCH, TARGET_ROLL))
    print("----------------------------------------")
    print(" ALTITUDE :        m  (Vel:       m/s)  ")
    print(" PITCH    :        deg                  ")
    print(" ROLL     :        deg                  ")
    print(" MASS     :        kg                   ")
    print("----------------------------------------")
    print(" MAIN THRUSTER :       %                ")
    print(" CONTROL THRUSTERS:                     ")
    print("  T1:       %  |  T5:       %           ")
    print("  T2:       %  |  T6:       %           ")
    print("  T3:       %  |  T7:       %           ")
    print("  T4:       %  |  T8:       %           ")
    print("========================================")
end

local function updateUI(state, mainPower, outputs)
    -- Dynamic Target Updates (Row 4)
    term.setCursorPos(17, 4); term.write(string.format("%5.1f", TARGET_ALTITUDE))
    term.setCursorPos(28, 4); term.write(string.format("%4.1f", TARGET_PITCH))
    term.setCursorPos(37, 4); term.write(string.format("%4.1f", TARGET_ROLL))

    -- Telemetry Updates
    term.setCursorPos(13, 6); term.write(string.format("%6.1f", state.altitude))
    term.setCursorPos(29, 6); term.write(string.format("%5.1f", state.velocity))

    term.setCursorPos(13, 7); term.write(string.format("%6.2f", state.pitch))
    term.setCursorPos(13, 8); term.write(string.format("%6.2f", state.roll))
    term.setCursorPos(13, 9); term.write(string.format("%6.0f", state.mass))

    -- Main Thruster Update
    term.setCursorPos(18, 11); term.write(string.format("%5.1f", mainPower))

    -- Control Thruster Updates
    term.setCursorPos(7, 13);  term.write(string.format("%5.1f", outputs[1]))
    term.setCursorPos(22, 13); term.write(string.format("%5.1f", outputs[5]))

    term.setCursorPos(7, 14);  term.write(string.format("%5.1f", outputs[2]))
    term.setCursorPos(22, 14); term.write(string.format("%5.1f", outputs[6]))

    term.setCursorPos(7, 15);  term.write(string.format("%5.1f", outputs[3]))
    term.setCursorPos(22, 15); term.write(string.format("%5.1f", outputs[7]))

    term.setCursorPos(7, 16);  term.write(string.format("%5.1f", outputs[4]))
    term.setCursorPos(22, 16); term.write(string.format("%5.1f", outputs[8]))
end

-- ============================================================================
-- SECTION 3: SENSOR & ACTUATOR INTERFACE
-- ============================================================================

local function readSensors()
    local rawAngles = gimbal_sensor.getAngles()
    local pitch, roll = 0, 0

    if type(rawAngles) == "table" then
        pitch = rawAngles.pitch or rawAngles.x or rawAngles[1] or 0
        roll  = rawAngles.roll  or rawAngles.y or rawAngles[2] or 0
    else
        pitch, roll = rawAngles, select(2, gimbal_sensor.getAngles())
    end

    local altitude = altitude_sensor.getHeight()
    local velocity = altitude_sensor.getVerticalSpeed()
    local mass     = mass_sensor.getMass() or BASELINE_MASS -- Fallback if nil

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
    for i = 1, #THRUSTER_ANGLES do
        rednet.broadcast(outputs[i], "thruster_" .. i)
    end
end

-- ============================================================================
-- SECTION 4: CONTROLLER ENGINE (PID WITH FILTERING & ANTI-WINDUP)
-- ============================================================================

local function createPIDController(gains)
    local lastCurrent  = nil
    local filteredRate = 0
    local integral     = 0
    local ALPHA        = 0.35 -- Smoothing factor for derivative (0.1 = heavy filter, 1.0 = raw)

    return function(target, current, dt, directVelocity)
        local err = target - current

        -- 1. Anti-Windup Reset on Setpoint / Zero Cross
        if (err > 0 and integral < 0) or (err < 0 and integral > 0) then
            integral = 0
        else
            integral = integral + (err * dt)
            local iLimit = gains.iLimit or 15.0
            integral = math.max(-iLimit, math.min(iLimit, integral))
        end

        -- 2. Measure Rate of Change (Velocity / Angular Velocity)
        -- Uses direct sensor velocity if available, otherwise calculates change in position
        local rawRate = 0
        if directVelocity ~= nil then
            rawRate = directVelocity
        elseif lastCurrent ~= nil then
            rawRate = (current - lastCurrent) / dt
        end
        lastCurrent = current

        -- Low-pass filter the rate to prevent 20Hz tick jitter
        filteredRate = (ALPHA * rawRate) + ((1.0 - ALPHA) * filteredRate)

        -- 3. Calculate PID Terms
        local pTerm = gains.kp * err
        local iTerm = gains.ki * integral
        -- Derivative always opposes rate of change of the current measurement
        local dTerm = -gains.kd * filteredRate

        return pTerm + iTerm + dTerm
    end
end

-- Instantiate controllers
local pitchController = createPIDController(GAINS.pitch)
local rollController  = createPIDController(GAINS.roll)
local altController   = createPIDController(GAINS.alt)

-- ============================================================================
-- SECTION 5: MIXING & FEEDFORWARD FUNCTIONS
-- ============================================================================

local function calculateControlMix(uPitch, uRoll, currentMass)
    local outputs = {}

    local mass = currentMass or BASELINE_MASS
    local massScale = math.max(0.2, math.min(1.0, mass / BASELINE_MASS))

    -- 1. Apply direction and mass scaling
    local pVal = (INVERT_PITCH and -uPitch or uPitch) * massScale
    local rVal = (INVERT_ROLL  and -uRoll  or uRoll)  * massScale

    -- 2. Clamp differential requested shift
    pVal = math.max(-MAX_CONTROL_DELTA, math.min(MAX_CONTROL_DELTA, pVal))
    rVal = math.max(-MAX_CONTROL_DELTA, math.min(MAX_CONTROL_DELTA, rVal))

    local offsetRad = math.rad(FRAME_OFFSET_DEG)

    for i = 1, #THRUSTER_ANGLES do
        local angle = THRUSTER_ANGLES[i] + offsetRad
        local delta = (pVal * math.cos(angle)) + (rVal * math.sin(angle))
        
        -- Virtual output between 0% and 100%
        local rawPower = math.max(0, math.min(100, BASE_CONTROL_POWER + delta))

        -- 3. DEADBAND COMPENSATION:
        -- Remap 0..100% into active hardware range 6.5%..100%
        if rawPower > 0 then
            outputs[i] = MIN_POWER_THRESHOLD + (rawPower / 100.0) * (100.0 - MIN_POWER_THRESHOLD)
        else
            outputs[i] = 0
        end
    end
    return outputs
end

local function calculateMainPower(uAlt, physicalControlOutputs, currentMass)
    local mass = currentMass or BASELINE_MASS
    local totalWeight = mass * GRAVITY

    -- 1. Calculate actual physical lift from all 8 control thrusters
    local controlLiftForce = 0
    for i = 1, #physicalControlOutputs do
        -- outputs are already scaled past 6.5%, just divide by 100
        local physicalPercent = physicalControlOutputs[i] / 100.0
        controlLiftForce = controlLiftForce + (physicalPercent * CONTROL_THRUSTER_MAX_FORCE)
    end

    -- 2. Net force needed from main thruster
    local baseHoverForce = math.max(0, totalWeight - controlLiftForce)
    local baseMainThrottle = (baseHoverForce / MAIN_THRUSTER_MAX_FORCE) * 100.0

    -- 3. Combine with altitude PID (allowing negative uAlt to force descent)
    local finalMainPower = baseMainThrottle + uAlt

    -- Hard clamp between 0% and 100%
    return math.max(0, math.min(100, finalMainPower))
end

-- ============================================================================
-- SECTION 6: MAIN CONTROL LOOP
-- ============================================================================

initUI()
local lastTime = os.epoch("utc") / 1000.0

while true do
    local currentTime = os.epoch("utc") / 1000.0
    local dt = math.max(0.05, currentTime - lastTime)
    lastTime = currentTime

    local state = readSensors()

    -- Calculate PID logic
    local uPitch  = pitchController(TARGET_PITCH, state.pitch, dt)
    local uRoll   = rollController(TARGET_ROLL, state.roll, dt)
    
    -- Pass state.velocity directly to give altController instant physical braking
    local uAltRaw = altController(TARGET_ALTITUDE, state.altitude, dt, state.velocity)

    -- Clamp Altitude modifier
    local uAlt = math.max(-30.0, math.min(30.0, uAltRaw))

    -- 1. Calculate control thruster mix (returns physical hardware percentages)
    local controlOutputs = calculateControlMix(uPitch, uRoll, state.mass)

    -- 2. Calculate main power, dynamically compensating for physical control lift
    local mainPower = calculateMainPower(uAlt, controlOutputs, state.mass)

    -- Apply changes
    applyMainThrust(mainPower)
    applyControlThrust(controlOutputs)

    -- Update Dashboard
    updateUI(state, mainPower, controlOutputs)

    os.sleep(0.05)
end