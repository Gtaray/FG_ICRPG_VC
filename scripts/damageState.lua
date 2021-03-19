OOB_MSGTYPE_APPLYDMGSTATE = "applydmgstate";

--
-- TRACK DAMAGE STATE (copied from 5e)
-- We do this since all attacks should do at least 1 STUN
--

local aDamageState = {};

function applyDamageState(rSource, rTarget, bSuccess)
	local msgOOB = {};
	msgOOB.type = OOB_MSGTYPE_APPLYDMGSTATE;
	
	msgOOB.sSourceNode = ActorManager.getCTNodeName(rSource);
	msgOOB.sTargetNode = ActorManager.getCTNodeName(rTarget);
	msgOOB.bSuccess = bSuccess;

	Comm.deliverOOBMessage(msgOOB, "");
end

function handleApplyDamageState(msgOOB)
	local rSource = ActorManager.resolveActor(msgOOB.sSourceNode);
	local rTarget = ActorManager.resolveActor(msgOOB.sTargetNode);
	
	if Session.IsHost then
		setDamageState(rSource, rTarget, msgOOB.bSuccess);
	end
end

function setDamageState(rSource, rTarget, bSuccess)
	if not Session.IsHost then
		applyDamageState(rSource, rTarget, bSuccess);
		return;
	end
	
	local sSourceCT = ActorManager.getCTNodeName(rSource);
	local sTargetCT = ActorManager.getCTNodeName(rTarget);
	if sSourceCT == "" or sTargetCT == "" then
		return;
	end
	
	if not aDamageState[sSourceCT] then
		aDamageState[sSourceCT] = {};
	end
	if not aDamageState[sSourceCT][sTargetCT] then
		aDamageState[sSourceCT][sTargetCT] = {};
	end
	aDamageState[sSourceCT][sTargetCT] = bSuccess;
end

function getDamageState(rSource, rTarget)
	local sSourceCT = ActorManager.getCTNodeName(rSource);
	local sTargetCT = ActorManager.getCTNodeName(rTarget);
	if sSourceCT == "" or sTargetCT == "" then
		return "";
	end
	
	if not aDamageState[sSourceCT] then
		return "";
	end
	if not aDamageState[sSourceCT][sTargetCT] == nil then
		return "";
	end
	
	local bSuccess = aDamageState[sSourceCT][sTargetCT];
	aDamageState[sSourceCT][sTargetCT] = nil;
	return bSuccess;
end