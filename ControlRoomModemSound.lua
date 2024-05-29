--Place your sound file in the "data" folder and rename it to "sound.dfpwm".

local color = colors.lime
local hostKey = "@z4dgHmDkAj5FqL"
local MainProtocol = "MainFacilityControl"
local commandid = "speaker.connecting"
rednet.open("top")

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
    if message == commandid and hostKeyR == hostKey then
        local dfpwm = require("cc.audio.dfpwm")
        local speaker = peripheral.find("speaker")

        local decoder = dfpwm.make_decoder()
        for chunk in io.lines("data/sound.dfpwm", 16 * 1024) do
            local buffer = decoder(chunk)

            while not speaker.playAudio(buffer) do
                os.pullEvent("speaker_audio_empty")
            end
        end

    else
    end
end