-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--
bMasteryLoaded = false;
local fGetPCPowerAction;
local fEncodeEffort;

function onInit()
    -- Initialize function pointers
    fGetPCPowerAction = PowerManager.getPCPowerAction;
    fEncodeEffort = ActionsManager2.encodeEffort;

    -- Look for mastery extension, and update function pointers
    for _,e in pairs(Extension.getExtensions()) do
        if e == "ICRPG_Mastery" then
            bMasteryLoaded = true;
            fGetPCPowerAction = Mastery.getPCPowerActionWithMastery;
        end
    end

    PowerManager.getPCPowerAction = getPCPowerAction;
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
end

function getPCPowerAction(nodeAction)
    local rAction, rActor = fGetPCPowerAction(nodeAction);

    if rAction.type == "attempt" then
        local cs = nodeAction.getChild("costsource");
        if cs then
            rAction.sCostSource = cs.getValue();
        end
    end
    if rAction.type == "effort" then
        local nodeTarget = nodeAction.getChild("efforttarget");
        if nodeTarget then
            rAction.sEffortTarget = nodeTarget.getValue()
        end
    end

    return rAction, rActor;
end

function encodeEffortAndStun(rRoll, bEffort)

    -- Add HP or STUN based on button
    local bHp = ModifierStack.getModifierKey("EFFORT");
    local bStun = ModifierStack.getModifierKey("STUN");

    -- Do base encoding
    fEncodeEffort(rRoll, bHP or bStun);

    if bHp then
        -- Do base encoding
        rRoll.sDesc = rRoll.sDesc .. " [HP]";
    elseif bStun then
        -- Do base encoding
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