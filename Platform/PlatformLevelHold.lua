-- ============================================================================
-- SECTION 1: CONFIGURATION & GAINS
-- ============================================================================

-- Peripheral Initialization
if not rednet.isOpen() then
    peripheral.find("modem", rednet.open)
end

if not rednet.isOpen() then
    error("CRITICAL ERROR: No active Rednet modem detected. System halted.")
end

local altitude_sensor = peripheral.find("altitude_sensor")
local gimbal_sensor   = peripheral.find("gimbal_sensor")
local mass_sensor     = peripheral.find("physics_assembler")

-- Strict Startup Peripheral Checks
if not altitude_sensor then error("CRITICAL HARDWARE ERROR: Altitude sensor peripheral missing!") end
if not gimbal_sensor   then error("CRITICAL HARDWARE ERROR: Gimbal sensor peripheral missing!") end
if not mass_sensor     then error("CRITICAL HARDWARE ERROR: Physics assembler missing!") end

-- Rig Constants
local MAIN_THRUSTER_MAX_FORCE    = 30240.0
local CONTROL_THRUSTER_MAX_FORCE = 8320.0
local GRAVITY                    = 11.0 
local RIG_RADIUS                 = 2.5  -- Distance from center to control thrusters (meters). Adjust to match physical rig.

-- Dynamic Flight Targets
local TARGET_ALTITUDE = 10.0
local TARGET_PITCH    = 0.0
local TARGET_ROLL     = 0.0

local MIN_POWER_THRESHOLD = 6.5    -- Hardware ignition threshold (%)
local BASE_CONTROL_POWER  = 35.0   -- New symmetric baseline for corner thrusters
local MAX_CONTROL_DELTA   = 30.0   -- Allows corner thrusters to swing from 5% to 65%

-- Body Frame Alignment Configuration
local FRAME_OFFSET_DEG   = 90
local INVERT_PITCH       = false
local INVERT_ROLL        = false
local INVERT_FF_PITCH    = false -- Toggle if CoM pitch feedforward overcompensates (wrong sign)
local INVERT_FF_ROLL     = false -- Toggle if CoM roll feedforward overcompensates (wrong sign)

local GAINS = {
    pitch = { kp = 0.50, ki = 0.00, kd = 0.35, iLimit = 0.0 },
    roll  = { kp = 0.50, ki = 0.00, kd = 0.35, iLimit = 0.0 },
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
    print(" COM OFF  : X:     Y:     Z:            ")
    print(" FF SHIFT : P:      % R:      %         ")
    print("----------------------------------------")
    print(" MAIN THRUSTER :       %                ")
    print(" CONTROL THRUSTERS:                     ")
    print("  T1:       %  |  T5:       %           ")
    print("  T2:       %  |  T6:       %           ")
    print("  T3:       %  |  T7:       %           ")
    print("  T4:       %  |  T8:       %           ")
    print("========================================")
end

local function updateUI(state, mainPower, outputs, ffPitch, ffRoll)
    -- Dynamic Target Updates
    term.setCursorPos(17, 4); term.write(string.format("%5.1f", TARGET_ALTITUDE))
    term.setCursorPos(28, 4); term.write(string.format("%4.1f", TARGET_PITCH))
    term.setCursorPos(37, 4); term.write(string.format("%4.1f", TARGET_ROLL))

    -- Telemetry Updates
    term.setCursorPos(13, 6); term.write(string.format("%6.1f", state.altitude))
    term.setCursorPos(29, 6); term.write(string.format("%5.1f", state.vertVelocity))

    term.setCursorPos(13, 7); term.write(string.format("%6.2f", state.pitch))
    term.setCursorPos(13, 8); term.write(string.format("%6.2f", state.roll))
    term.setCursorPos(13, 9); term.write(string.format("%6.0f", state.mass))

    -- Center of Mass Offset
    term.setCursorPos(15, 10); term.write(string.format("%4.2f", state.comX))
    term.setCursorPos(22, 10); term.write(string.format("%4.2f", state.comY))
    term.setCursorPos(29, 10); term.write(string.format("%4.2f", state.comZ))

    -- Feedforward Thruster Shift
    term.setCursorPos(15, 11); term.write(string.format("%5.2f", ffPitch))
    term.setCursorPos(25, 11); term.write(string.format("%5.2f", ffRoll))

    -- Main Thruster Update
    term.setCursorPos(18, 13); term.write(string.format("%5.1f", mainPower))

    -- Control Thruster Updates
    term.setCursorPos(7, 15);  term.write(string.format("%5.1f", outputs[1]))
    term.setCursorPos(22, 15); term.write(string.format("%5.1f", outputs[5]))

    term.setCursorPos(7, 16);  term.write(string.format("%5.1f", outputs[2]))
    term.setCursorPos(22, 16); term.write(string.format("%5.1f", outputs[6]))

    term.setCursorPos(7, 17);  term.write(string.format("%5.1f", outputs[3]))
    term.setCursorPos(22, 17); term.write(string.format("%5.1f", outputs[7]))

    term.setCursorPos(7, 18);  term.write(string.format("%5.1f", outputs[4]))
    term.setCursorPos(22, 18); term.write(string.format("%5.1f", outputs[8]))
end

-- ============================================================================
-- SECTION 3: SENSOR & ACTUATOR INTERFACE
-- ============================================================================

local function readSensors()
    if not gimbal_sensor or not altitude_sensor or not mass_sensor then
        error("CRITICAL FAULT: One or more sensor peripherals disconnected during runtime!")
    end

    local rawAngles = gimbal_sensor.getAngles()
    if not rawAngles then
        error("SENSOR ERROR: Failed to retrieve reading from gimbal_sensor.getAngles()!")
    end

    local pitch, roll
    if type(rawAngles) == "table" then
        pitch = rawAngles.pitch or rawAngles.x or rawAngles[1]
        roll  = rawAngles.roll  or rawAngles.y or rawAngles[2]
    else
        local p, r = gimbal_sensor.getAngles()
        pitch, roll = p, r
    end

    if pitch == nil or roll == nil then
        error("SENSOR ERROR: Incomplete pitch/roll telemetry from gimbal_sensor!")
    end

    if not gimbal_sensor.getAngularRates then
        error("HARDWARE ERROR: gimbal_sensor does not support direct getAngularRates() API!")
    end

    local rates = gimbal_sensor.getAngularRates()
    if type(rates) ~= "table" then
        error("SENSOR ERROR: Failed to retrieve rates table from gimbal_sensor.getAngularRates()!")
    end

    local pitchVel = rates.wx or rates[1]
    local rollVel  = rates.wz or rates[3]

    if pitchVel == nil or rollVel == nil then
        error("SENSOR ERROR: Incomplete angular velocity telemetry from gimbal_sensor!")
    end

    local altitude = altitude_sensor.getHeight()
    if altitude == nil then
        error("SENSOR ERROR: Failed to retrieve reading from altitude_sensor.getHeight()!")
    end

    local vertVelocity = altitude_sensor.getVerticalSpeed()
    if vertVelocity == nil then
        error("SENSOR ERROR: Failed to retrieve reading from altitude_sensor.getVerticalSpeed()!")
    end

    local mass = mass_sensor.getMass()
    if mass == nil then
        error("SENSOR ERROR: Failed to retrieve reading from mass_sensor.getMass()!")
    end

    -- Direct Center of Mass (Yields 1 server tick)
    if not mass_sensor.getCenterOfMass then
        error("HARDWARE ERROR: mass_sensor does not support direct getCenterOfMass() API!")
    end

    local com = mass_sensor.getCenterOfMass()
    if type(com) ~= "table" then
        error("SENSOR ERROR: Failed to retrieve reading from mass_sensor.getCenterOfMass()!")
    end

    local comX = com.x or com[1]
    local comY = com.y or com[2]
    local comZ = com.z or com[3]

    if comX == nil or comY == nil or comZ == nil then
        error("SENSOR ERROR: Incomplete Center of Mass telemetry from mass_sensor!")
    end

    return {
        pitch         = pitch,
        roll          = roll,
        pitchVelocity = pitchVel,
        rollVelocity  = rollVel,
        altitude      = altitude,
        vertVelocity  = vertVelocity,
        mass          = mass,
        comX          = comX,
        comY          = comY,
        comZ          = comZ
    }
end

local function applyMainThrust(percent)
    if not rednet.isOpen() then
        error("COMMUNICATION FAULT: Rednet connection lost during main thrust output!")
    end
    rednet.broadcast(percent, "thruster_main")
end

local function applyControlThrust(outputs)
    if not rednet.isOpen() then
        error("COMMUNICATION FAULT: Rednet connection lost during control thrust output!")
    end
    for i = 1, #THRUSTER_ANGLES do
        rednet.broadcast(outputs[i], "thruster_" .. i)
    end
end

-- ============================================================================
-- SECTION 4: CONTROLLER ENGINE (STRICT DIRECT-MEASUREMENT PID)
-- ============================================================================

local function createPIDController(gains)
    local integral = 0

    return function(target, current, dt, directRate)
        if directRate == nil then
            error("CONTROLLER FAULT: Missing required direct rate measurement in PID loop!")
        end

        local err = target - current

        integral = integral + (err * dt)
        local iLimit = gains.iLimit or 15.0
        integral = math.max(-iLimit, math.min(iLimit, integral))

        local pTerm = gains.kp * err
        local iTerm = gains.ki * integral
        local dTerm = -gains.kd * directRate

        return pTerm + iTerm + dTerm
    end
end

local pitchController = createPIDController(GAINS.pitch)
local rollController  = createPIDController(GAINS.roll)
local altController   = createPIDController(GAINS.alt)

-- ============================================================================
-- SECTION 5: MIXING & FEEDFORWARD FUNCTIONS
-- ============================================================================

local function calculateControlMix(uPitch, uRoll, state)
    local outputs = {}

    -- Base PID requests
    local pVal = (INVERT_PITCH and -uPitch or uPitch)
    local rVal = (INVERT_ROLL  and -uRoll  or uRoll)

    -- 1. Center of Mass Feedforward Calculation
    -- Calculate thrust percentage needed to exactly counteract gravitational torque
    local weight = state.mass * GRAVITY

    -- Sable body-X is pitch, body-Z is roll. A mass offset at +Z causes positive torque around X.
    local ffPitchForce = (state.comZ * weight) / RIG_RADIUS
    local ffRollForce  = (state.comX * weight) / RIG_RADIUS

    -- Calculate geometric advantage (8 thrusters / 2 = 4.0 multiplier)
    local THRUSTER_MULTIPLIER = #THRUSTER_ANGLES / 2.0 

    local ffPitchPercent = ((ffPitchForce / CONTROL_THRUSTER_MAX_FORCE) * 100.0) / THRUSTER_MULTIPLIER
    local ffRollPercent  = ((ffRollForce  / CONTROL_THRUSTER_MAX_FORCE) * 100.0) / THRUSTER_MULTIPLIER

    if INVERT_FF_PITCH then ffPitchPercent = -ffPitchPercent end
    if INVERT_FF_ROLL  then ffRollPercent  = -ffRollPercent  end

    -- Inject static feedforward compensation into the requested control deltas
    pVal = pVal + ffPitchPercent
    rVal = rVal + ffRollPercent

    -- 2. Clamp differential requested shift to hardware limits
    pVal = math.max(-MAX_CONTROL_DELTA, math.min(MAX_CONTROL_DELTA, pVal))
    rVal = math.max(-MAX_CONTROL_DELTA, math.min(MAX_CONTROL_DELTA, rVal))

    local offsetRad = math.rad(FRAME_OFFSET_DEG)

    for i = 1, #THRUSTER_ANGLES do
        local angle = THRUSTER_ANGLES[i] + offsetRad
        local delta = (pVal * math.cos(angle)) + (rVal * math.sin(angle))
        
        local rawPower = math.max(0, math.min(100, BASE_CONTROL_POWER + delta))

        -- 3. DEADBAND COMPENSATION
        if rawPower > 0 then
            outputs[i] = MIN_POWER_THRESHOLD + (rawPower / 100.0) * (100.0 - MIN_POWER_THRESHOLD)
        else
            outputs[i] = 0
        end
    end
    
    return outputs, ffPitchPercent, ffRollPercent
end

local function calculateMainPower(uAlt, physicalControlOutputs, currentMass)
    if currentMass == nil then
        error("CALCULATION FAULT: Direct mass measurement missing for main power feedforward!")
    end

    local totalWeight = currentMass * GRAVITY

    local controlLiftForce = 0
    for i = 1, #physicalControlOutputs do
        local physicalPercent = physicalControlOutputs[i] / 100.0
        controlLiftForce = controlLiftForce + (physicalPercent * CONTROL_THRUSTER_MAX_FORCE)
    end

    local baseHoverForce = math.max(0, totalWeight - controlLiftForce)
    local baseMainThrottle = (baseHoverForce / MAIN_THRUSTER_MAX_FORCE) * 100.0

    local finalMainPower = baseMainThrottle + uAlt

    return math.max(0, math.min(100, finalMainPower))
end

-- ============================================================================
-- SECTION 6: MAIN CONTROL LOOP
-- ============================================================================

initUI()
local lastTime = os.epoch("utc") / 1000.0

while true do
    -- Yield happens first
    local state = readSensors()

    -- Capture time immediately after waking up
    local currentTime = os.epoch("utc") / 1000.0
    local dt = math.max(0.05, currentTime - (lastTime or currentTime - 0.05))
    lastTime = currentTime

    -- Calculate dynamic PID logic using verified direct measurements
    local uPitch  = pitchController(TARGET_PITCH, state.pitch, dt, state.pitchVelocity)
    local uRoll   = rollController(TARGET_ROLL, state.roll, dt, state.rollVelocity)
    local uAltRaw = altController(TARGET_ALTITUDE, state.altitude, dt, state.vertVelocity)

    local uAlt = math.max(-30.0, math.min(30.0, uAltRaw))

    -- Calculate thrust allocation, injecting CoM feedforward
    local controlOutputs, ffPitch, ffRoll = calculateControlMix(uPitch, uRoll, state)
    local mainPower = calculateMainPower(uAlt, controlOutputs, state.mass)

    -- Apply actuator commands
    applyMainThrust(mainPower)
    applyControlThrust(controlOutputs)

    -- Update Dashboard
    updateUI(state, mainPower, controlOutputs, ffPitch, ffRoll)

    -- Yield handled intrinsically by getCenterOfMass() inside readSensors()
    --os.sleep(0)
end