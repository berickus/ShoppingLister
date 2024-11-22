local SL = select(2, ...)

local Debug = {}
SL.Debug = Debug

local private = {}


-- wow api
local GetChatWindowInfo = 
GetChatWindowInfo

-- lua api
local type, tostring, string, pairs =
type, tostring, string, pairs


function Debug.Log(msg, ...)
    local chatFrame = private.GetDebugChatFrame()
    if chatFrame then
        SL:Printf(chatFrame, msg, ...)
    end
end

function Debug.TableToString ( t )
    local print_r_cache={}
    local function sub_print_r(t,indent)
        if (print_r_cache[tostring(t)]) then
            SL.Debug.Log(indent.."*"..tostring(t))
        else
            print_r_cache[tostring(t)]=true
            if (type(t)=="table") then
                for pos,val in pairs(t) do
                    if (type(val)=="table") then
                        SL.Debug.Log(indent.."["..pos.."] => "..tostring(t).." {")
                        sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
                        SL.Debug.Log(indent..string.rep(" ",string.len(pos)+6).."}")
                    elseif (type(val)=="string") then
                        SL.Debug.Log(indent.."["..pos..'] => "'..val..'"')
                    else
                        SL.Debug.Log(indent.."["..pos.."] => "..tostring(val))
                    end
                end
            else
                SL.Debug.Log(indent..tostring(t))
            end
        end
    end
    if (type(t)=="table") then
        SL.Debug.Log(tostring(t).." {")
        sub_print_r(t,"  ")
        SL.Debug.Log("}")
    else
        sub_print_r(t,"  ")
    end
    SL.Debug.Log("")
end


function private.GetDebugChatFrame() -- private
    local tab = -1
    for i = 1, 10 do
        if GetChatWindowInfo(i)=="SLDebug" then
            tab = i
            break
        end
    end

    if(tab ~= -1) then
        return _G["ChatFrame"..tab]
    end
end