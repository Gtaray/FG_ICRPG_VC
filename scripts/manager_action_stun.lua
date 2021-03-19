local fGetEffortRoll;
local fGetPowerEffortRoll;
local fApplyDamageToChunk;
local fApplyDamageToTarget;

function onInit()
    fGetEffortRoll = ActionEffort.getRoll;
    fGetPowerEffortRoll = ActionEffort.getPowerRoll;
    fApplyDamageToChunk = ActionEffort.applyDamageToChunk;
    fApplyDamageToTarget = ActionEffort.applyDamageToTarget;
    ActionEffort.getRoll = getRoll;
    ActionEffort.getPowerRoll = getPowerRoll;
    ActionEffort.applyDamageToChunk = applyDamageToChunk;
    ActionEffort.applyDamageToTarget = applyDamageOrStun;
end

function getRoll(rActor, sStat, sDie, nTargetDC, bSecretRoll)
    local rRoll = fGetEffortRoll(rActor, sStat, sDie, nTargetDC, bSecretRoll);
    rRoll.sDesc = rRoll.sDesc .. " [STUN]";
    return rRoll;
end

function getPowerRoll(rActor, rAction, bHeal) 
	local rRoll = fGetPowerEffortRoll(rActor, rAction, bHeal);
    local dmgtype = "STUN"
    if rAction.sEffortTarget == "hp" then
        dmgtype = "HP";
    end
    rRoll.sDesc = rRoll.sDesc .. " [" .. dmgtype:upper() .. "]";
    return rRoll;
end

function applyDamageToChunk(rSource, rTarget, bSecret, sDamage, nTotal)
    local bStun = string.match(sDamage, "%[STUN%]")
    -- Only apply HP damage to chunks. 
    if bStun then
	    ActionEffort.messageDamage(rSource, rTarget, bSecret, false, "0", "");
    else
        fApplyDamageToChunk(rSource, rTarget, bSecret, sDamage, nTotal);
    end
end

function applyDamageOrStun(rSource, rTarget, bSecret, sDamage, nTotal)
    local bStun = string.match(sDamage, "%[STUN%]")
    if bStun then
        applyStunToTarget(rSource, rTarget, bSecret, sDamage, nTotal);
    else
        fApplyDamageToTarget(rSource, rTarget, bSecret, sDamage, nTotal);
        -- If option is set, apply 1 STUN with HP damage
        local bApplyStunOnHP = OptionsManager.getOption("HPDS") == "on";
        if bApplyStunOnHP then
            applyStunToTarget(rSource, rTarget, bSecret, "[DRAIN]", 0);
        end
    end
end

function applyStunToTarget(rSource, rTarget, bSecret, sDamage, nTotal)
    local nodeTarget = ActorManager.getCreatureNode(rTarget);
	local bHeal = string.match(sDamage, "%[HEAL%]") or nTotal < 0;
    local bDrain = string.match(sDamage, "%[DRAIN%]");

	local nTotalStun, nStunDmg, nRemainder;
	nTotalStun = DB.getValue(nodeTarget, "health.stun", 0);
	nStunDmg = DB.getValue(nodeTarget, "health.stundmg", 0);

	local aNotifications = {};
	
	-- get the current status
	local _,sOriginalStatus = ActorManagerVC.getStunPercent(rTarget);

	if bHeal then
		if nStunDmg <= 0 then
			table.insert(aNotifications, "[NOT DAMAGED]");
		else
			nStunDmg = math.max(nStunDmg - math.abs(nTotal), 0);
			table.insert(aNotifications, " [HEALING]");
		end
	else
        local nAdjustedWounds = 0;
        if nTotal > 0 then
            local piercing = sDamage:match("%[PIERCING%]");
            if piercing == nil and bDrain == nil then
                -- Get DR or DT effects
                local nDR = 0;
                local nDT = 0;
                nDR, nDT = ActionEffort.getDamageReduction(rSource, rTarget, nTotal);		
                -- Modify and apply wounds
                if nDR ~= 0 then
                    table.insert(aNotifications, "[REDUCED]");
                    nTotal = math.max(nTotal - math.abs(nDR), 0);
                end
                if nDT ~= 0 and nTotal  < nDT then
                    table.insert(aNotifications, "[GLANCING]");
                    nTotal = 0;
                end
            end
        end

        -- Handle misses always dealing 1 damage
        local bDamageState = DamageState.getDamageState(rSource, rTarget);

        -- only do this if damage would otherwise be 0, or the previous attack missed
        local bApplyMinStun = OptionsManager.getOption("MINS") == "on";
        if bApplyMinStun and (bDamageState == false or nTotal == 0) then
            nTotal = 1;
            table.insert(aNotifications, "[DRAIN]");
        end

        nStunDmg = math.max(nStunDmg + nTotal, 0);
	end

	-- set wounds field
	DB.setValue(nodeTarget, "health.stundmg", "number", nStunDmg);

	-- Check for status change
	local bShowStatus = false;
	if ActorManager.getFaction(rTarget) == "friend" then
		bShowStatus = not OptionsManager.isOption("SHPC", "off");
	else
		bShowStatus = not OptionsManager.isOption("SHNPC", "off");
	end
	if bShowStatus then
		local _,sNewStatus = ActorManagerVC.getStunPercent(rTarget);
		if sOriginalStatus ~= sNewStatus then
			table.insert(aNotifications, "[" .. Interface.getString("combat_tag_status") .. ": " .. sNewStatus .. "]");
		end
	end
	
    -- Output results
	ActionEffort.messageDamage(rSource, rTarget, bSecret, bHeal, nTotal, table.concat(aNotifications, " "));

	-- Modify effects on the target
	if nTotal > 0 then
		-- add or remove the stunned effect based on current HP.
		if nStunDmg < nTotalStun then
			if EffectManagerICRPG.hasCondition(rTarget, "Stunned") then
				EffectManager.removeEffect(ActorManager.getCTNode(rTarget), "Stunned");
			end
		elseif nStunDmg == nTotalStun then
            if EffectManagerICRPG.hasCondition(rTarget, "Stunned") then
				EffectManager.removeEffect(ActorManager.getCTNode(rTarget), "Stunned");
			end
			if not EffectManagerICRPG.hasCondition(rTarget, "Fatigued") then
				EffectManager.addEffect("", "", ActorManager.getCTNode(rTarget), { sName = "Fatigued", nDuration = 0 }, true);
			end
        elseif nStunDmg > nTotalStun then
            if EffectManagerICRPG.hasCondition(rTarget, "Fatigued") then
				EffectManager.removeEffect(ActorManager.getCTNode(rTarget), "Fatigued");
			end
			if not EffectManagerICRPG.hasCondition(rTarget, "Stunned") then
				EffectManager.addEffect("", "", ActorManager.getCTNode(rTarget), { sName = "Stunned", nDuration = 0 }, true);
			end
		end
	end
end