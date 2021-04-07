local fGetEffortRoll;
local fGetPowerEffortRoll;
local fApplyDamageToChunk;
local fApplyDamageToTarget;
local fDecodeDamageText;

function onInit()
    fGetEffortRoll = ActionEffort.getRoll;
    fGetPowerEffortRoll = ActionEffort.getPowerRoll;
    fApplyDamageToChunk = ActionEffort.applyDamageToChunk;
    fApplyDamageToTarget = ActionEffort.applyDamageToTarget;
    fDecodeDamageText = ActionEffort.decodeDamageText;
    ActionEffort.getRoll = getRoll;
    ActionEffort.getPowerRoll = getPowerRoll;
    ActionEffort.performNPCRoll = performNPCRoll;
    ActionEffort.applyDamageToChunk = applyDamageToChunk;
    ActionEffort.applyDamageToTarget = applyDamageOrStun;
    ActionEffort.decodeDamageText = decodeDamageText;
end

-------------------------------------
-- GETTING ROLLS
-------------------------------------

function getRoll(rActor, sStat, sDie, nTargetDC, bSecretRoll)
    local rRoll = fGetEffortRoll(rActor, sStat, sDie, nTargetDC, bSecretRoll);
    VigilanteCity.encodeEffortAndStun(rRoll);
    return rRoll;
end

function getPowerRoll(rActor, rAction, bHeal) 
    rRoll.sDesc = rRoll.sDesc .. " [" .. dmgtype:upper() .. "]";
	local rRoll = fGetPowerEffortRoll(rActor, rAction, bHeal);
    local dmgtype = "STUN"
    if rAction.sEffortTarget == "hp" then
        dmgtype = "HP";
    end
    VigilanteCity.encodeEffortAndStun(rRoll);
    return rRoll;
end

function performNPCRoll(draginfo, rActor, rRoll)
	if Session.IsHost and CombatManager.isCTHidden(ActorManager.getCTNode(rActor)) then
		rRoll.bSecret = true;
	end
    VigilanteCity.encodeEffortAndStun(rRoll);
    ActionEffort.encodeDamageTypes(rRoll, true);

	ActionsManager.performAction(draginfo, rActor, rRoll);
end

--------------------------------
--- APPLYING DAMAGE
--------------------------------

function applyDamageToChunk(rSource, rTarget, bSecret, rDamageOutput)
    local bChunkDmgOption = OptionsManager.getOption("DTFC");
    local bStun = rDamageOutput.bStun;
    local bHP = rDamageOutput.bHP;
    
    if bChunkDmgOption == "both" and (bStun or bHP) then
        fApplyDamageToChunk(rSource, rTarget, bSecret, rDamageOutput);
    elseif bChunkDmgOption == "hp" and bHP then
        fApplyDamageToChunk(rSource, rTarget, bSecret, rDamageOutput);
    elseif bChunkDmgOption == "sp" and bStun then
        fApplyDamageToChunk(rSource, rTarget, bSecret, rDamageOutput);
    else
	    ActionEffort.messageDamage(rSource, rTarget, bSecret, false, "0", "");        
    end
end

-- Replaces applyDamageToTarget()
function applyDamageOrStun(rSource, rTarget, bSecret, rDamageOutput)
    local bStun = rDamageOutput.bStun;
    local bHP = rDamageOutput.bHP;
    local bHeal = rDamageOutput.sType == "heal";

    local nodeTarget = ActorManager.getCreatureNode(rTarget);
    local nTotalStun = DB.getValue(nodeTarget, "health.stun", 0);
    
    -- if stun is explicitly set, or HP is NOT explicitly set
    if bStun or (not bHP) then
        applyStunToTarget(rSource, rTarget, bSecret, rDamageOutput);
    end
    -- If HP is present, also deduct that. This is so that you deduct from both resources on the same roll. Mostly used by NPCs.
    if bHP then
        fApplyDamageToTarget(rSource, rTarget, bSecret, rDamageOutput);
        -- If option is set, apply 1 STUN with HP damage
        -- But don't do this is the target's max stun is 0.
        local bApplyStunOnHP = OptionsManager.getOption("HPDS") == "on";
        -- Only apply this drain if:
            -- Setting is set
            -- NOT already doing damage to stun
            -- The character's max STUN is more than 0
            -- This is not a heal
        if bApplyStunOnHP and (not bStun) and (nTotalStun > 0) and (not bHeal) then
            rDamageOutput.bDrain = true;
            applyStunToTarget(rSource, rTarget, bSecret, rDamageOutput);
        end
    end
end

-- Copy of applyDamageToTarget()
function applyStunToTarget(rSource, rTarget, bSecret, rDamageOutput)
    local nodeTarget = ActorManager.getCreatureNode(rTarget);
	local bHeal = rDamageOutput.sType == "heal";
    local bDrain = rDamageOutput.bDrain;
    local bImpervious = false;

    local nTotal = rDamageOutput.nVal;
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
    elseif bDrain then
        table.insert(aNotifications, "[DRAIN]");
        nTotal = 1;
        nStunDmg = math.max(nStunDmg + nTotal, 0);
	else
        nTotal, nStunDmg, nRemainder = ActionEffort.calculateDamage(rTarget, rSource, rDamageOutput, nTotalStun, nStunDmg, aNotifications);

        -- Handle misses always dealing 1 damage
        local bDamageState = DamageState.getDamageState(rSource, rTarget);

        -- only do this if damage would otherwise be 0, or the previous attack missed
        local bApplyMinStun = OptionsManager.getOption("MINS") == "on";
        if bApplyMinStun and (bImpervious == false) and (bDamageState == false or nTotal == 0) then
            nTotal = 1;
            table.insert(aNotifications, "[DRAIN]");
        end
	end

    -- always notify that this was applied to stun 
    table.insert(aNotifications, "[STUN]");

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

------------------------------
-- DECODING
------------------------------
function decodeDamageText(nDamage, sDamageDesc)
    local rDamageOutput = fDecodeDamageText(nDamage, sDamageDesc);
    rDamageOutput.bDrain = string.match(sDamageDesc, "%[DRAIN%]");
    rDamageOutput.bHP = string.match(sDamageDesc, "%[HP%]");
    rDamageOutput.bStun = string.match(sDamageDesc, "%[STUN%]");
    return rDamageOutput;
end