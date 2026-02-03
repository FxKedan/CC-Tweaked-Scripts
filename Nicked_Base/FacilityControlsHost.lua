local color = colors.lime
local password = "pfoten"
local exitCode = "potato"
local readTime = 1
local Protocol = "Arcdoor_Inc_Main"
local FastBoot = true
os.pullEvent = os.pullEventRaw
peripheral.find("modem", rednet.open)

if FastBoot then
  BootTime = 10
else
  BootTime = 1
end

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
    onCommandId = "example2.on",
    offCommandId = "example2.off",
    onText = "startup example2",
    offText = "shutdown example2",
  },
}

local function animateDots(x, y, base, duration, txtColor)
        local maxDots = 3
        local interval = 0.2
        local iterations = math.max(1, math.floor(duration / interval))
        for i = 1, iterations do
                local count = (i - 1) % (maxDots + 1)
                local dots = string.rep(".", count)
                term.setCursorPos(x, y)
                if txtColor then term.setTextColor(txtColor) end
                term.write(base .. dots .. string.rep(" ", maxDots - #dots))
                sleep(interval)
        end
end

function Communication(targetId, msg)
        rednet.send(targetId, msg, Protocol)
        local respId, respMsg = rednet.receive(Protocol, 2)
        if respMsg == "success" and respId == targetId then
                        term.setCursorPos(22,12)
                        textutils.slowPrint("Success!")
                        sleep(readTime)
        else
                        animateDots(19, 12, "Sending", 5, color)
                        term.setCursorPos(19,12)
                        term.setTextColor(colors.red)
                        textutils.slowPrint("Error! Timeout")
                        sleep(readTime)
        end

end

function Communication_broadcast(msg)
        rednet.broadcast(msg, Protocol)
        animateDots(18, 12, "Broadcasting", 5, color)
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
        print("------------------COMMAND LIBRARY------------------")
        print("---------------------------------------------------")
        print("--   ARCDOOR INDUSTRIES (TM) TERMLINK PROTOCOL   --")
        print("--                                               --")
        print("-- startup <machine>                             --")
        print("-- shutdown <*>                                  --")
        print("-- open <door/room>                              --")
        print("-- close <*>                                     --")
        print("-- help                                          --")
        print("-- get_id                                        --")
        print("-- lockdown                                      --")
        print("-- lock                                          --")
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
textutils.slowPrint("/////////////", BootTime)
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
                -- rednet start: check devices table for matching commands
                local handled = false
                for _, d in ipairs(devices) do
                        if input == d.onText then
                                local tId, cmd = d.id, d.onCommandId
                                Communication(tId, cmd)
                                handled = true
                                break
                        elseif input == d.offText then
                                local tId, cmd = d.id, d.offCommandId
                                Communication(tId, cmd)
                                handled = true
                                break
                        end
                end
                -- rednet end: if not handled by device commands, check for other commands
                if not handled then
                        if input == "lockdown" then
                                Communication_broadcast("facility.lockdown")

                        --rednet end
                        elseif input == exitCode then
                                term.setCursorPos(6,12)
                                textutils.slowPrint("Exit Code Recognised. Exiting to Shell.")
                                sleep(readTime)
                                term.clear()
                                term.setCursorPos(1, 1)
                                return

                        elseif input == "get_id" then
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
