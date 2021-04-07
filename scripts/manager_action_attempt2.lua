-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--
OOB_MSGTYPE_ROLLCOST = "rollcost";
local fOnAttmpt;
local fGetPowerRoll;
local fDeductCost;

function onInit()
    OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_ROLLCOST, handleRollCost);

    -- Initialize function pointers
    fGetPowerRoll = ActionAttempt.getPowerRoll;
	fOnAttempt = ActionAttempt.onAttempt;
	fDeductCost = ActionAttempt.deductCost;

    -- Look for mastery extension, and update function pointers
	-- Not needed, since Mastery sets ActionAttempt.getPowerRoll already
    -- if VigilanteCity.bMasteryLoaded then
    --     fGetPowerRoll = Mastery.getAttemptPowerRoll;
    -- end

    ActionAttempt.getPowerRoll = getAttemptPowerRoll;
	ActionAttempt.onAttempt = onAttempt;
	ActionAttempt.deductCost = deductCost;
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

function onAttempt(rSource, rTarget, rRoll)
	fOnAttempt(rSource, rTarget, rRoll);
	if rSource and rTarget then
		DamageState.setDamageState(rSource, rTarget, bSuccess);
	end
end

function deductCost(rSource, sCost, bSuccess)
	if not sCost then return; end
    -- try with mastery type
    
    local sCostTrigger = string.match(sCost, "%(.+, (.+)%)");
    if not sCostTrigger then
        -- try to match without mastery type
	    sCostTrigger = string.match(sCost, "%((.+)%)");
    end
    
	if (sCostTrigger == "S/F") or (sCostTrigger == "S" and bSuccess == true) or (sCostTrigger == "F" and bSuccess == false) then
		local sCostDice = string.match(sCost, "(.+) %(.+%)");
		local costOOB = {};
		costOOB.type = OOB_MSGTYPE_ROLLCOST;
		costOOB.nSecret = 0;
		costOOB.sSourceNode = ActorManager.getCreatureNodeName(rSource);
		costOOB.sCost = sCostDice;

        -- Handle mastery type
        if bMasteryLoaded then
            local mastery = string.match(sCost, ".+ %((.+), .+%)")
            if mastery then
                costOOB.sMastery = mastery;
            end
        end

        -- Handle cost source
        local stuncost = string.match(sCost, "Stun");
        local hpcost = string.match(sCost, "Hp");
        costOOB.sCostSource = stuncost or hpcost;

		Comm.deliverOOBMessage(costOOB, "");
	end
end

function handleRollCost(msgOOB)
	local rActor = ActorManager.resolveActor(msgOOB.sSourceNode);
	local sCost = msgOOB.sCost;
	local rCostRoll = {};
	rCostRoll.sType = "cost";
	rCostRoll.sDesc = ""; 

    if msgOOB.sCostSource then
        rCostRoll.sDesc = rCostRoll.sDesc .. "[" .. msgOOB.sCostSource:upper() .. "]";
    end
    if msgOOB.sMastery then
        local nMastery = Mastery.getMasteryLevel(DB.findNode(msgOOB.sSourceNode), msgOOB.sMastery);
        if nMastery >= 4 then
            rCostRoll.sDesc = rCostRoll.sDesc .. " [MASTERED]";
        end
    end
	rCostRoll.aDice, rCostRoll.nMod = StringManager.convertStringToDice(sCost);
	ActionCost.performAction(rActor, rCostRoll);
end