local color = colors.lime
local password = "pipboy"
local exitCode = "Rummel"
local readTime = 1
local hostKey = "@z4dgHmDkAj5FqL"
local MainProtocol = "MainFacilityControl"
os.pullEvent = os.pullEventRaw
peripheral.find("modem", rednet.open)

--List of possible receivers
local doorid, commandidOpen, commandidClose, commandOpen, commandClose = 1, "door.x.open", "door.x.close", "open door", "close door"

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

function PasswordUI()
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
end

function CommandUI()
        term.clear()
        term.setCursorPos(1,1)
        term.setTextColor(color)
        print("---------------------------------------------------")
        print("-------------------DOOR TERMINAL-------------------")
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
end

function HelpUI()
        term.clear()
        term.setCursorPos(1,1)
        term.setTextColor(color)
        print("---------------------------------------------------")
        print("------------------Command Library------------------")
        print("---------------------------------------------------")
        print("--    ROBCO INDUSTRIES (TM) TERMLINK PROTOCOL    --")
        print("--                                               --")
        print("-- open door                                     --")
        print("-- close <*>                                     --")
        print("-- help                                          --")
        print("-- get_id                                        --")
        print("-- lock                                          --")
        print("-- call_elevator                                 --")
        print("--                                               --")
        print("--                                               --")
        print("--                                               --")
        print("--           Press any key to continue           --")
        print("--                                               --")
        print("-- ROBCO / VAULT-TEC                UI Model 1.3 --")
        print("---------------------------------------------------")
        print("---------------------------------------------------")
end

term.clear()
term.setTextColor(color)
term.setCursorPos(19,8)
print("Connecting...")
term.setCursorPos(18,10)
print("[             ]")
term.setCursorPos(19,10)
textutils.slowPrint("/////////////", 13)
sleep(readTime)

PasswordUI()
term.setCursorPos(22,10)
local input = read("*")
if input == password then
        term.setCursorPos(16,12)
        textutils.slowPrint("Password Recognised.")
        sleep(readTime)
        while true do
                CommandUI()
                term.setCursorPos(15,10)
                input = read()
                --rednet start
                if input == commandOpen then
                        Id, Message = doorid, commandidOpen
                        Communication()
                        elseif input == commandClose then
                                Id, Message = doorid, commandidClose
                                Communication()

                elseif input == "call elevator" then
                        rs.setOutput("bottom", true)
                        sleep(0.5)
                        rs.setOutput("bottom", false)
                        term.setCursorPos(22,12)
                        textutils.slowPrint("Success!")
                        sleep(readTime)

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

                elseif input == "help" then
                        HelpUI()
                        os.pullEvent("key")
                        --Page 2, 3 etc.
                        goto continue
                else
                        term.setCursorPos(18,12)
                        term.setTextColor(colors.red)
                        textutils.slowPrint("Invalid Command.")
                        sleep(readTime)
                end
                ::continue::
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