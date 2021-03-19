-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--
OOB_MSGTYPE_ROLLCOST = "rollcost";
local fGetPowerRoll;

function onInit()
    OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_ROLLCOST, handleRollCost);
    ActionsManager.registerResultHandler("attempt", onAttempt);

    -- Initialize function pointers
    fGetPowerRoll = ActionAttempt.getPowerRoll;

    -- Look for mastery extension, and update function pointers
    if VigilanteCity.bMasteryLoaded then
        fGetPowerRoll = Mastery.getAttemptPowerRoll;
    end

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

function onAttempt(rSource, rTarget, rRoll)
	local rMessage = ActionsManager.createActionMessage(rSource, rRoll);
	local bTargetArmor = OptionsManager.getOption("NPCT") == "armor";
    rMessage.icon = "action_attempt";

	local bIsSourcePC = ActorManager.isPC(rSource);
	local bIsTargetPC = ActorManager.isPC(rTarget);

	local targetName = ActorManager.getDisplayName(rTarget);
	if targetName then
		-- if the attacker is an NPC targeting a PC's armor, add clarification text
		if bTargetArmor and not bIsSourcePC and bIsTargetPC then
			rMessage.text = rMessage.text .. " -> [at " .. targetName .. " (A)]";
		else
			rMessage.text = rMessage.text .. " -> [at " .. targetName .. "]";
		end
	else
		rMessage.text = rMessage.text .. " -> [vs Room Target]";
	end

	local nRoll;
	if rRoll.aDice[1] then
		nRoll = rRoll.aDice[1].result or 0;
	else 
		nRoll = rRoll.nMod;
	end

	local nTargetDC = 0;
	
	-- If the roll has a defined target, it takes precedence over everything
	-- if not, get the target number
	if rRoll.nTarget then
		-- If a target DC has been set by the roll source, take it above anything else
		nTargetDC = tonumber(rRoll.nTarget) 
	else
		-- If no target DC has been set, PCs always take the room target.
		if bIsSourcePC then
			nTargetDC = TargetManager.getTarget();
		else		
			-- If no target DC has been set, NPCs target based on an option (armor or room target)
			if bIsTargetPC and bTargetArmor then
				-- Target is a PC, so we target their armor
				nTargetDC = ActorManagerICRPG.getStat(rTarget, "armor");
				-- Get effects that would change armor
				local aDice, aArmorMod, nArmorEffectCount = EffectManagerICRPG.getEffectsBonus(rTarget, {"ARMOR"}, false, nil, rSource);
				-- if there are effects, add to the description
				if nArmorEffectCount > 0 then
					nTargetDC = nTargetDC + aArmorMod;
					local sMod = StringManager.convertDiceToString(nil, aArmorMod, true);
					rMessage.text = rMessage.text .. " [" .. Interface.getString("effects_def_tag") .. " " .. sMod .. "]";
				end
			else
				-- Fallback to targeting the Room Target
				nTargetDC = TargetManager.getTarget();
			end
		end	
	end

	if string.match(rRoll.sDesc, "%[EASY%]") then
		nTargetDC = nTargetDC - 3;
	end
	if string.match(rRoll.sDesc, "%[HARD%]") then
		nTargetDC = nTargetDC + 3;
	end

	local bSuccess = false;
	if nRoll == 20 then
		rMessage.text = rMessage.text .. " [CRITICAL SUCCESS]";
		bSuccess = true;
	elseif nRoll == 1 then
		rMessage.text = rMessage.text .. " [BLUNDER]";
	else
		if nTargetDC then
			local nTotal = ActionsManager.total(rRoll);

			if nTotal >= nTargetDC then
				rMessage.text = rMessage.text .. " [SUCCESS]";
				bSuccess = true;
			else
				rMessage.text = rMessage.text .. " [FAILURE]";
			end
		end
	end

	Comm.deliverChatMessage(rMessage);

	-- Handle HP cost, but only if not a crit success
    if rMessage.text:match("%[CRITICAL SUCCESS%]") == nil then
	    local fullmatch = string.match(rRoll.sDesc, "%[COST: (.+)%]")
	    deductCost(rSource, fullmatch, bSuccess);
    end
	
	local msgOOB = {};
	msgOOB.type = OOB_MSGTYPE_SETBATTLEFURY;
	msgOOB.nSecret = 0;

	msgOOB.sSourceNode = ActorManager.getCreatureNodeName(rSource);
	if bSuccess then
		msgOOB.bSuccess = "true";
	else
		msgOOB.bSuccess = "false";
	end

    Comm.deliverOOBMessage(msgOOB, "");

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