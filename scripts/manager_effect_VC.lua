
function onInit()
    EffectManagerICRPG.applyOngoingDamageAdjustment = applyOngoingDamageAdjustment;
    EffectManager.setCustomOnEffectActorStartTurn(onEffectActorStartTurn);
end

function onEffectActorStartTurn(nodeActor, nodeEffect)
	local sEffName = DB.getValue(nodeEffect, "label", "");
	local aEffectComps = EffectManager.parseEffect(sEffName);
	for _,sEffectComp in ipairs(aEffectComps) do
		local rEffectComp = EffectManagerICRPG.parseEffectComp(sEffectComp);
		local sEffectType = rEffectComp.type:lower();
		if sEffectType == "degen" or sEffectType == "stundegen" or sEffectType == "regen" or sEffectType == "stunregen" then
			local nActive = DB.getValue(nodeEffect, "isactive", 0);
			if nActive == 2 then
				if sEffectType == "regen" and (ActorManagerICRPG.getWoundPercent(nodeActor) >= 1) then 
					break;
				end
				DB.setValue(nodeEffect, "isactive", "number", 1);
			else
				applyOngoingDamageAdjustment(nodeActor, nodeEffect, rEffectComp);
			end
		end
	end
end

function applyOngoingDamageAdjustment(nodeActor, nodeEffect, rEffectComp)
	if #(rEffectComp.dice) == 0 and rEffectComp.mod == 0 then
		return;
	end
	
	local rTarget = ActorManager.resolveActor(nodeActor);
    local sType = rEffectComp.type:lower();
	if sType == "regen" then
		local nPercentWounded = ActorManagerICRPG.getWoundPercent(rTarget);
		
		-- If not wounded, then return
		if nPercentWounded <= 0 then
			return;
		end
		-- Regeneration does not work once creature falls below 1 hit point (but only if no specific damage type needed to disable regeneration)
		if nPercentWounded >= 1 and (#(rEffectComp.remainder) == 0) then
			return;
		end

        local rRoll = { sType = "effort", sDesc = "Regeneration [HEAL] [HP]", aDice = rEffectComp.dice, nMod = rEffectComp.mod };
        if EffectManager.isGMEffect(nodeActor, nodeEffect) then
            rRoll.bSecret = true;
        end
        ActionsManager.actionDirect(nil, "effort", { rRoll }, { { rTarget } });
    elseif sType == "stunregen" then
        local nPercentStunned = VigilanteCity.getStunPercent(nodeActor);

        if nPercentStunned <= 0 then
            return;
        end
        if nPercentStunned >= 1 then
            return;
        end

        local rRoll = { sType = "effort", sDesc = "Regeneration [HEAL] [STUN]", aDice = rEffectComp.dice, nMod = rEffectComp.mod };
        if EffectManager.isGMEffect(nodeActor, nodeEffect) then
            rRoll.bSecret = true;
        end
        ActionsManager.actionDirect(nil, "effort", { rRoll }, { { rTarget } });
	elseif sType == "degen" then
		local rRoll = { sType = "effort", sDesc = "Ongoing damage [HP]", aDice = rEffectComp.dice, nMod = rEffectComp.mod };
		if EffectManager.isGMEffect(nodeActor, nodeEffect) then
			rRoll.bSecret = true;
		end
		ActionsManager.actionDirect(nil, "effort", { rRoll }, { { rTarget } });
    elseif sType == "stundegen" then
        local rRoll = { sType = "effort", sDesc = "Ongoing damage [STUN]", aDice = rEffectComp.dice, nMod = rEffectComp.mod };
		if EffectManager.isGMEffect(nodeActor, nodeEffect) then
			rRoll.bSecret = true;
		end
		ActionsManager.actionDirect(nil, "effort", { rRoll }, { { rTarget } });
	end
end    