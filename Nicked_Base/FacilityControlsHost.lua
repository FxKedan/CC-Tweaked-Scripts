local color = colors.lime
local password = "pfoten"
local exitCode = "potato"
local readTime = 1
local Protocol = "Arcdoor_Inc_Main"
os.pullEvent = os.pullEventRaw
peripheral.find("modem", rednet.open)

--Table of possible receivers
local devices = {
  [1] = {
    id = 1,
    onCommandId = "example.on",
    offCommandId = "example.off",
    onText = "startup example",
    offText = "shutdown example",
  },
  [2] = {
    id = 2,
    onCommandId = "example.on",
    offCommandId = "example.off",
    onText = "startup example",
    offText = "shutdown example",
  },
}

function Communication()
        rednet.send(targetId, Message, Protocol)
        local id, message = rednet.receive(Protocol, 2)
        if message == "success" and id == targetId then
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

function Communication_broadcast()
        rednet.broadcast(Message, Protocol)
        term.setCursorPos(18,12)
        term.setTextColor(color)
        textutils.slowPrint("Broadcasting...")
        sleep(5)        
end

function PasswordUI()
        term.clear()
        term.setCursorPos(1,1)
        term.setTextColor(color)
        print("---------------------------------------------------")
        print("----------------FACILITY CONTROLS------------------")
        print("---------------------------------------------------")
        print("--   ARCDOOR INDUSTRIES (TM) TERMLINK PROTOCOL   --")
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
        print("-- ARCDOOR / OMNI LABS           UI Model 2.1.37 --")
        print("---------------------------------------------------")
        print("---------------------------------------------------")
end

function CommandUI()
        term.clear()
        term.setCursorPos(1,1)
        term.setTextColor(color)
        print("---------------------------------------------------")
        print("----------------FACILITY CONTROLS------------------")
        print("---------------------------------------------------")
        print("--   ARCDOOR INDUSTRIES (TM) TERMLINK PROTOCOL   --")
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
        print("-- ARCDOOR / OMNI LABS           UI Model 2.1.37 --")
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
        print("--   ARCDOOR INDUSTRIES (TM) TERMLINK PROTOCOL   --")
        print("--                                               --")
        print("-- startup <machine>                             --")
        print("-- shutdown <*>                                  --")
        print("-- open <door/room>                              --")
        print("-- close <*>                                     --")
        print("-- help                                          --")
        print("-- get_id                                        --")
        print("-- lock                                          --")
        print("--                                               --")
        print("--                                               --")
        print("--           Press any key to continue           --")
        print("--                                               --")
        print("-- ARCDOOR / OMNI LABS           UI Model 2.1.37 --")
        print("---------------------------------------------------")
        print("---------------------------------------------------")
end

term.clear()
term.setTextColor(color)
term.setCursorPos(19,8)
print("Connecting...")
rednet.send(9, "speaker.connecting", Protocol)
term.setCursorPos(18,10)
print("[             ]")
term.setCursorPos(19,10)
textutils.slowPrint("/////////////", 1)
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
                if input == devices[1].onText then
                        targetId, Message = devices[1].id, devices[1].onCommandId
                        Communication()
                        elseif input == devices[1].offText then
                                targetId, Message = devices[1].id, devices[1].offCommandId
                                Communication()

                elseif input == devices[2].onText then
                        targetId, Message = devices[2].id, devices[2].onCommandId
                        Communication()
                        elseif input == devices[2].offText then
                                targetId, Message = devices[2].id, devices[2].offCommandId
                                Communication()

                elseif input == "lockdown" then
                        Message = "facility.lockdown"
                        Communication_broadcast()

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
