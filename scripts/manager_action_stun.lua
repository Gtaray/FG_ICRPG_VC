local fGetEffortRoll;
local fGetPowerEffortRoll;
local fApplyDamageToChunk;
local fApplyDamageToTarget;
local fDecodeDamageText;

function onInit()
    fGetPowerEffortRoll = ActionEffort.getPowerRoll;
    ActionEffort.getPowerRoll = getPowerRoll;
    
    fApplyDamageToChunk = ActionEffort.applyDamageToChunk;
    ActionEffort.applyDamageToChunk = applyDamageToChunk;

    fApplyDamageToTarget = ActionEffort.applyDamageToTarget;
    ActionEffort.applyDamageToTarget = applyDamageToTarget;
    
    fDecodeDamageText = ActionEffort.decodeDamageText;
    ActionEffort.decodeDamageText = decodeDamageText;
end

-------------------------------------
-- GETTING ROLLS
-------------------------------------

-- Adds health resource tag
function getPowerRoll(rActor, rAction, bHeal) 
    local sRes = "stun"
    if rAction.sEffortTarget == "hp" then
        sRes = "hp";
    end
    rRoll.aHealthResource = { sRes };
    local rRoll = fGetPowerEffortRoll(rActor, rAction, bHeal);
    return rRoll;
end
--------------------------------
--- APPLYING DAMAGE
--------------------------------

-- this is overridden since we need to check if we're allowed to do
-- the damage chunks with the specified health resource
function applyDamageToChunk(rSource, rTarget, bSecret, rDamageOutput)
    local bChunkDmgOption = OptionsManager.getOption("DTFC");
    local bStun = StringManager.contains(rDamageOutput.aHealthResources, "stun");
    local bHP = StringManager.contains(rDamageOutput.aHealthResources, "hp");
    
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

-- We inject this function here specifically to track DRAIN
function applyDamageToTarget(rSource, rTarget, bSecret, rDamageOutput)
    local bStun = StringManager.contains(rDamageOutput.aHealthResources, "stun");
    local bHP = StringManager.contains(rDamageOutput.aHealthResources, "hp");
    local bHeal = rDamageOutput.sType == "heal";

    local nCurStun, nMaxStun = ActorManagerICRPG.getHealthResource(rTarget, "stun");

    fApplyDamageToTarget(rSource, rTarget, bSecret, rDamageOutput);

    -- if this was HP damage and NOT stun damage, and NOT a heal
    -- then check to see if we should apply drain
    if bHP and (not bStun) and (not bHeal) then
        -- If option is set, apply 1 STUN with HP damage
        -- But don't do this is the target's max stun is 0.
        if OptionsManager.getOption("HPDS") == "on" then
            if nMaxStun > 0 then
                applyDrain(rSource, rTarghet, bSecret)
            end
        end
    end
end

-- Custom ApplyDmg function for STUN health resource.
-- Handles making sure at least 1 STUN damage is done when taking damage.
-- Also handles DRAIN dmg
function handleMinimumStunDmg(rSource, rTarget, nDmg, nCurDmg, nMax, nRemainder, aNotifications, rDamageOutput)
    -- Handle misses always dealing 1 damage
    local bDamageState = ActionAttempt.getAttackState(rSource, rTarget);
    local bApplyMinStun = OptionsManager.getOption("MINS") == "on";

    -- if this damage is a result of DRAIN or because the damage min is hit
    -- then set to 1 and add the drain tag
    if rDamageOutput.bDrain or (bApplyMinStun and (bDamageState == false or nDmg == 0)) then
        -- check target is not impervious to all damage
        if nMax >= 0 then
            nDmg = 1;
            nCurDmg = nCurDmg + 1;
            if nCurDmg > nMax then
                nRemainder = nCurDmg - nMax;
            end
            table.insert(aNotifications, "[DRAIN]");
        end
    end

    return nDmg, nCurDmg, nRemainder;
end

-- Simply applies 1 damage with the DRAIN tag
function applyDrain(rSource, rTarget, bSecret)
    if not rSource or not rTarget then
        return;
    end

    rDamageOutput = ActionEffort.decodeDamageText(1, "[DRAIN]");

    fApplyDamageToTarget(rSource, rTarget, bSecret, rDamageOutput)
end

-- Updates STUN conditions for when STUN dmg is dealt.
function updateStunConditions(rActor, nCur, nMax, nRemainder)
    if nCur < nMax then
        if EffectManagerICRPG.hasCondition(rActor, "Stunned") then
            EffectManager.removeEffect(ActorManager.getCTNode(rActor), "Stunned");
        end
        if EffectManagerICRPG.hasCondition(rActor, "Fatigued") then
            EffectManager.removeEffect(ActorManager.getCTNode(rActor), "Fatigued");
        end
    elseif nCur == nMax then
        if EffectManagerICRPG.hasCondition(rActor, "Stunned") then
            EffectManager.removeEffect(ActorManager.getCTNode(rActor), "Stunned");
        end
        if not EffectManagerICRPG.hasCondition(rActor, "Fatigued") then
            EffectManager.addEffect("", "", ActorManager.getCTNode(rActor), { sName = "Fatigued", nDuration = 0 }, true);
        end
    elseif nCur > nMax then
        if EffectManagerICRPG.hasCondition(rActor, "Fatigued") then
            EffectManager.removeEffect(ActorManager.getCTNode(rActor), "Fatigued");
        end
        if not EffectManagerICRPG.hasCondition(rActor, "Stunned") then
            EffectManager.addEffect("", "", ActorManager.getCTNode(rActor), { sName = "Stunned", nDuration = 0 }, true);
        end
    end
end

------------------------------
-- DECODING
------------------------------
-- Adds decoding for the DRAIN tag
function decodeDamageText(nDamage, sDamageDesc)
    local rDamageOutput = fDecodeDamageText(nDamage, sDamageDesc);
    rDamageOutput.bDrain = string.match(sDamageDesc, "%[DRAIN%]");
    return rDamageOutput;
end