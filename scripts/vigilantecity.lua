-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--
local fOnAttempt;
local fGetPCPowerAction;
local fGetPowerRoll;
local fEncodeEffort;

function onInit()
    -- Set up a new HP Resource
    DataCommon.addHealthResource(
        "stun", 
        "health.stundmg", 
        "health.stun", 
        ActionStun.updateStunConditions,
        getStunPercent,
        ActionStun.handleMinimumStunDmg);
    DataCommon.setDefaultHealthResource("stun");
    DataCommon.addHealthResourceAlias("stun", "sp");

    -- Initialize function pointers
    ActionsManager.registerResultHandler("attempt", handleDrainOnFailedAttempt);
    fOnAttempt = ActionAttempt.onAttempt;

    fGetPCPowerAction = PowerManager.getPCPowerAction;
    PowerManager.getPCPowerAction = getPCPowerAction;
    
    fEncodeEffort = ActionsManager2.encodeEffort;
    ActionsManager2.encodeEffort = encodeEffortAndStun;

    registerOptions();
end

function registerOptions() 
    -- Missed attacks always deal 1 STUN
    OptionsManager.registerOption2("MINS", false, "option_header_vc", "option_label_MINS", "option_entry_cycler", 
    {	labels = "option_val_yes", values = "on", baselabel = "option_val_no", baseval = "off", default = "on" });
    -- Dealing HP damage also does 1 STUN damage
	OptionsManager.registerOption2("HPDS", false, "option_header_vc", "option_label_HPDS", "option_entry_cycler", 
    {	labels = "option_val_yes", values = "on", baselabel = "option_val_no", baseval = "off", default = "on" });
    -- What damage type can harm chunks
	OptionsManager.registerOption2("DTFC", false, "option_header_vc", "option_label_DTFC", "option_entry_cycler", 
    {	labels = "option_val_hpdmg|option_val_hpspdmg", values = "hp|both", baselabel = "option_val_spdmg", baseval = "sp", default = "both" });
end

------------------------------------------
-- Handle Drain on failed attempt
------------------------------------------
function handleDrainOnFailedAttempt(rSource, rTarget, rRoll)
    fOnAttempt(rSource, rTarget, rRoll);

    local bDamageState = ActionAttempt.getAttackState(rSource, rTarget);
    local bApplyMinStun = OptionsManager.getOption("MINS") == "on";

    -- if the attack missed, then apply DRAIN
    if bApplyMinStun and bDamageState == false then
        ActionStun.applyDrain(rSource, rTarget, bSecret);
    end
end

-- Adds health resource to the action
function getPCPowerAction(nodeAction)
    local rAction, rActor = fGetPCPowerAction(nodeAction);

    if rAction.type == "attempt" then
        local cs = nodeAction.getChild("costsource");
        if cs then
            rAction.sCostHealthResource = cs.getValue();
        end
    end
    if rAction.type == "effort" then
        local nodeTarget = nodeAction.getChild("efforttarget");
        if nodeTarget then
            local sHealthRes = nodeTarget.getValue()
            if sHealthRes == "" then
                sHealthRes = "stun"
            end
            if sHealthRes then
                rAction.aHealthResource = { sHealthRes };
            end
        end
    end
    if rAction.type == "heal" then
        local nodeTarget = nodeAction.getChild("efforttarget");
        if nodeTarget then
            local sHealthRes = nodeTarget.getValue()
            if sHealthRes then
                rAction.aHealthResource = { sHealthRes };
            end
        end
    end

    return rAction, rActor;
end

-- This does base encoding. Both the modifier buttons, as well as making
-- sure that all effort has HP or STUN tags.
function encodeEffortAndStun(rRoll, bEffort)
    -- Add HP or STUN based on button
    local bHp = ModifierStack.getModifierKey("EFFORT");
    local bStun = ModifierStack.getModifierKey("STUN");

    -- Do base encoding
    -- if this is already an effort type roll, don't encode it.
    if rRoll.sType ~= "effort" then
        fEncodeEffort(rRoll, bHP or bStun);
    end
    local matchHP = rRoll.sDesc:match("%[HP%]");
    local matchStun = rRoll.sDesc:match("%[STUN%]");

    if bHp then
        -- Do base encoding
        if matchStun then
            if matchHP then
                -- get rid of stun tag
                rRoll.sDesc = rRoll.sDesc:gsub("%[STUN%]", "");
            else
                -- replace stun tag
                rRoll.sDesc = rRoll.sDesc:gsub("%[STUN%]", "[HP]");
            end
        elseif not matchHP then
            -- only add the HP tag if it's not already there
            rRoll.sDesc = rRoll.sDesc .. " [HP]";
        end
    end
    if bStun then
        -- Do base encoding
        if matchHP then
            if matchStun then
                rRoll.sDesc = rRoll.sDesc:gsub("%[HP%]", "")
            else    
                rRoll.sDesc = rRoll.sDesc:gsub("%[HP%]", "[STUN]")
            end
        elseif not matchStun then
            rRoll.sDesc = rRoll.sDesc .. " [STUN]";
        end
    end

    -- last case. Neither button is pressed, and neither HP/STUN is matched
    if not bHp and not bStun and not matchHP and not matchStun then
        -- just add stun. It's the default damage type.
        rRoll.sDesc = rRoll.sDesc .. " [STUN]";
    end
end

function getVP(nodeActor)
    if not nodeActor then return nil; end

    local vp = 0;
    local vpnode = nodeActor.getChild("vp");
    if vpnode then
        for _,v in pairs(vpnode.getChildren()) do
            if v then
                local checked = v.getValue() == 1;
                local value = tonumber(v.getName():match("vp(%d+)"));
                if checked then
                    if value > vp then
                        vp = value;
                    end
                end
            end
        end
    end
    -- Normalize VP to -4 to +4
    if vp ~= 0 then 
        vp = vp - 10; 
    end

    return vp;
end

function setVP(nodeActor, nVP)
    local vpnode = nodeActor.getChild("vp");

    for _,v in pairs(vpnode.getChildren()) do
        local nNum = tonumber(v.getName():match("vp(%d+)")) - 10;
        if nVP == 0 then
            v.setValue(0);
        elseif nVP > 0 and nNum < nVP then 
            if nNum > 0 then
                v.setValue(1);
            end
            if nNum > nVP then
                v.setValue(0);
            end
            if nNum < 0 then
                v.setValue(0);
            end
        elseif nVP > 0 and nNum > nVP then
            v.setValue(0);
        elseif nVP < 0 and nNum > nVP then
            if nNum < 0 then
                v.setValue(1);
            end
            if nNum < nVP then
                v.setValue(0);
            end
            if nNum > 0 then
                v.setValue(0);
            end
        elseif nVP < 0 and nNum < nVP then
            v.setValue(0);
        end
    end
end

-----
function getStunPercent(v, sHealthResource)
    local rActor = ActorManager.resolveActor(v);
    local bIsPC = ActorManager.isPC(rActor);

    if not sHealthResource then
        sHealthResource = "stun";
    end
    
    local nCur, nMax = ActorManagerICRPG.getHealthResource(rActor, sHealthResource);

    local nodeActor = ActorManager.getCreatureNode(rActor);
    if not nodeActor then
        return 0, "";
    end
    
    local nPercentWounded = 0;
    if nMax > 0 then
        nPercentWounded = nCur / nMax;
    end
    
    local sStatus;
    if not Session.IsHost and (not bIsPC) then
        sStatus = DB.getValue(nodeActor, "status", "");
    else
        if nPercentWounded > 1 then
            sStatus = "Stunned";
        elseif nPercentWounded == 1 then
            sStatus = "Fatigued";
        elseif OptionsManager.isOption("WNDC", "detailed") then
            if nPercentWounded >= .75 then
                sStatus = ActorHealthManager.STATUS_CRITICAL;
            elseif nPercentWounded >= .5 then
                sStatus = ActorHealthManager.STATUS_HEAVY;
            elseif nPercentWounded >= .25 then
                sStatus = ActorHealthManager.STATUS_MODERATE;
            elseif nPercentWounded > 0 then
                sStatus = ActorHealthManager.STATUS_LIGHT;
            else
                sStatus = ActorHealthManager.STATUS_HEALTHY;
            end
        else
            if nPercentWounded >= .5 then
                sStatus = ActorHealthManager.STATUS_SIMPLE_HEAVY;
            elseif nPercentWounded > 0 then
                sStatus = ActorHealthManager.STATUS_SIMPLE_WOUNDED;
            else
                sStatus = ActorHealthManager.STATUS_HEALTHY;
            end
        end
    end
    
    return nPercentWounded, sStatus;
end