-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--
OOB_MSGTYPE_ROLLCOST = "rollcost";
local fOnAttmpt;
local fGetPowerRoll;
local fDeductCost;

function onInit()
    -- Initialize function pointers
    fGetPowerRoll = ActionAttempt.getPowerRoll;
    ActionAttempt.getPowerRoll = getAttemptPowerRoll;
end

function getAttemptPowerRoll(rActor, rAction)
    local rRoll = fGetPowerRoll(rActor, rAction);
    if rAction.sCostTrigger ~= "" and rAction.sCostSource ~= "" then
        local fullmatch = rRoll.sDesc:match("(%[COST: .+%])")
        if fullmatch then
            local prefix = fullmatch:match("(%[COST: .+) %(.+%)%]");
            local suffix = fullmatch:match("%[COST: .+ (%(.+%)%])");
            if prefix and suffix then
                local newCost = prefix .. " " .. StringManager.capitalize(rAction.sCostSource) .. " " .. suffix;
                rRoll.sDesc = rRoll.sDesc:gsub("%[COST: .+%]", newCost); 
            end
        end
    end
    return rRoll;
end