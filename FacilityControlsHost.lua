local color = colors.lime
local password = "pipboy"
local exitCode = "Rummel"
local readTime = 1
local hostKey = "@z4dgHmDkAj5FqL"
local MainProtocol = "MainFacilityControl"
os.pullEvent = os.pullEventRaw
rednet.open("top")

--List of possible receivers
local id1 = 1
local id2 = 5

function Communication()
        rednet.send(Id, hostKey, "hostKey")
        rednet.send(Id, Message, MainProtocol)
        local id, message = rednet.receive(MainProtocol, 2)
        if message == "success" and id == Id then
                        term.setCursorPos(22,12)
                        textutils.slowPrint("Success!")
                        sleep(readTime)
        else
                        term.setCursorPos(19,12)
                        term.setTextColor(colors.red)
                        textutils.slowPrint("Error! Timeout")
                        sleep(readTime)
        end

end

term.clear()
term.setTextColor(color)
term.setCursorPos(19,8)
print("Connecting...")
rednet.send(9, hostKey, "hostKey")
rednet.send(9, "speaker.connecting", MainProtocol)
term.setCursorPos(18,10)
print("[             ]")
term.setCursorPos(19,10)
textutils.slowPrint("/////////////", 1)
sleep(readTime)

term.clear()
term.setCursorPos(1,1)
term.setTextColor(color)
print("---------------------------------------------------")
print("----------------FACILITY CONTROLS------------------")
print("---------------------------------------------------")
print("--    ROBCO INDUSTRIES (TM) TERMLINK PROTOCOL    --")
print("--              ENTER PASSWORD NOW               --")
print("--                                               --")
print("--                                               --")
print("--                                               --")
print("--                                               --")
print("--                  PASSWORD:                    --")
print("--                  [      ]                     --")
print("--                                               --")
print("--                                               --")
print("--                                               --")
print("--                                               --")
print("--                                               --")
print("-- ROBCO / VAULT-TEC                UI Model 1.3 --")
print("---------------------------------------------------")
print("---------------------------------------------------")

term.setCursorPos(22,10)
local input = read("*")
if input == password then
        term.setCursorPos(16,12)
        textutils.slowPrint("Password Recognised.")
        sleep(readTime)
        while true do
                CmdStat = nil
                term.clear()
                term.setCursorPos(1,1)
                term.setTextColor(color)
                print("---------------------------------------------------")
                print("----------------FACILITY CONTROLS------------------")
                print("---------------------------------------------------")
                print("--    ROBCO INDUSTRIES (TM) TERMLINK PROTOCOL    --")
                print("--              ENTER COMMAND NOW                --")
                print("--                                               --")
                print("--                                               --")
                print("--                                               --")
                print("--                                               --")
                print("--                  Command:                     --")
                print("--           >                                   --")
                print("--                                               --")
                print("--                                               --")
                print("--                                               --")
                print("--                                               --")
                print("--                                               --")
                print("-- ROBCO / VAULT-TEC                UI Model 1.3 --")
                print("---------------------------------------------------")
                print("---------------------------------------------------")

                term.setCursorPos(15,10)
                input = read()

                if string.find(input, "%f[%w_]startup%f[^%w_]") or string.find(input, "%f[%w_]open%f[^%w_]") then
                    CmdStat = "on"
                elseif string.find(input, "%f[%w_]shutdown%f[^%w_]") or string.find(input, "%f[%w_]close%f[^%w_]") then
                    CmdStat = "off"
                else
                end

                if CmdStat == "on" or CmdStat == "off" then
                    CmdStat2 = true
                else
                    CmdStat2 = false
                end

                --rednet start

                if string.find(input, "%f[%w_]boiler%f[^%w_]") and (CmdStat2 == true) then
                    Id, Message = id2, ""..CmdStat..".boil"
                    Communication()

                elseif string.find(input, "%f[%w_]boiler2%f[^%w_]") and (CmdStat2 == true) then
                    Id, Message = id1, ""..CmdStat..".boil2"
                    Communication()

                --rednet end
                elseif input == exitCode then
                        term.setCursorPos(6,12)
                        textutils.slowPrint("Exit Code Recognised. Exiting to Shell.")
                        sleep(readTime)
                        term.clear()
                        term.setCursorPos(1, 1)
                        return

                elseif input == "get id" then
                        local pcid = os.getComputerID()
                        term.setCursorPos(11,12)
                        textutils.slowPrint("The id of this computer is "..pcid..".")
                        sleep(readTime)

                elseif input == "lock" then
                        term.setCursorPos(17,12)
                        textutils.slowPrint("Locking Computer.")
                        sleep(readTime)
                        os.reboot()

                else
                        term.setCursorPos(18,12)
                        term.setTextColor(colors.red)
                        textutils.slowPrint("Invalid Command.")
                        sleep(readTime)
                end
        end

elseif input == exitCode then
        term.setCursorPos(6,12)
        textutils.slowPrint("Exit Code Recognised. Exiting to Shell.")
        sleep(readTime)
        term.clear()
        term.setCursorPos(1, 1)
        return

else
        term.setCursorPos(14,12)
        term.setTextColor(colors.red)
        textutils.slowPrint("Password not Recognised.")
        sleep(readTime)
        os.reboot()
end