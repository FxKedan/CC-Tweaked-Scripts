--Place your sound file in the "data" folder and rename it to "sound.dfpwm".
--Sync the length of the sound file with the slowPrint rate you specified in the Host. The modem sound file is 13 seconds long so I set the rate to 1. The loading bar has 13 characters so the print takes 13 seconds.

local color = colors.lime
local Protocol = "Arcdoor_Inc_Main"
local commandid = "speaker.connecting"
peripheral.find("modem", rednet.open)

term.clear()
term.setCursorPos(1,1)
term.setTextColor(color)
print("---------------------------------------------------")
print("-------------FACILITY CONTROLS CLIENT--------------")
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
print("--                                               --")
print("-- ARCDOOR / OMNI LABS           UI Model 2.1.37 --")
print("---------------------------------------------------")
print("---------------------------------------------------")

while true do
    local id, message = rednet.receive(Protocol, nil)
    if message == commandid then
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