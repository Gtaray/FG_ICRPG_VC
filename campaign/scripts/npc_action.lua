-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

local bParsed = false;
local aComponents = {};

local bClicked = false;
local bDragging = false;
local nDragIndex = nil;

function parseComponents()
	aComponents = {};
	
	-- Get all words
	local aWords, aWordStats = StringManager.split(getValue(), " \n\r", true);
	local rActor = ActorManager.resolveActor(window.getDatabaseNode());

	for i = 1, #aWords do
		local bMatch = false;
		local sWordLower = aWords[i]:gsub('[%c%s]', ''):lower()
		local sType;
		local sDice;
		local sMultiplier = "1";
		local sEffortTarget;
		if sWordLower == "str" then
			bMatch = true;
			sDice = "d20";
			sType = "attempt";
		elseif sWordLower == "dex" then
			bMatch = true;
			sDice = "d20";
			sType = "attempt";
		elseif sWordLower == "con" then
			bMatch = true;
			sDice = "d20";
			sType = "attempt";
		elseif sWordLower == "int" then
			bMatch = true;
			sDice = "d20";
			sType = "attempt";
		elseif sWordLower == "wis" then
			bMatch = true;
			sDice = "d20";
			sType = "attempt";
		elseif sWordLower == "cha" then
			bMatch = true;
			sDice = "d20";
			sType = "attempt";
		elseif StringManager.isDiceString(sWordLower) then
			-- check if this is a legit dice string
			bMatch = true;
			sDice = sWordLower;
			sType = "dice";
			sMultiplier = "";
		else	
			-- last thing to do is check if this is an effort type
			for vEffortDie,vEffort in pairs(DataCommon.effort_dice) do
				if sWordLower == vEffort:lower() then
					bMatch = true;
					sDice = vEffortDie;
					sType = "effort";
					sEffortTarget = "stun";
					break;
				end
			end
		end

		if bMatch then
			-- Check if the previous word is EASY or HARD
			local startpos = aWordStats[i].startpos;
			local endpos = aWordStats[i].endpos;
			local bEasy = false;
			local bHard = false;

			if aWords[i-1] then
				local sLower = aWords[i-1]:gsub('[%p%c%s]', ''):lower();
				if sLower == "easy" then
					bEasy = true;
					startpos = aWordStats[i-1].startpos;
					endpos = aWordStats[i].endpos;
				elseif sLower == "hard" then
					bHard = true;
					startpos = aWordStats[i-1].startpos;
					endpos = aWordStats[i].endpos;
				elseif sLower == "double" then
					sMultiplier = "2";
					startpos = aWordStats[i-1].startpos;
					endpos = aWordStats[i].endpos;
				elseif sLower == "triple" then
					sMultiplier = "3";
					startpos = aWordStats[i-1].startpos;
					endpos = aWordStats[i].endpos;
				elseif sLower == "quadruple" then
					sMultiplier = "4";
					startpos = aWordStats[i-1].startpos;
					endpos = aWordStats[i].endpos;
				end
			end

			if aWords[i+1] then
				local sLower = aWords[i+1]:gsub('[%p%c%s]', ''):lower();
				if sLower == "rounds" then
					sType = "timer";
					startpos = aWordStats[i].startpos;
					endpos = aWordStats[i+1].endpos;
				end

				-- if the match is an effort type, then check for STUN or HP 
					if sLower == "stun" or sLower == "sp" or sLower == "hp" or sLower == "hit points" then
						startpos = aWordStats[i].startpos;
						endpos = aWordStats[i+1].endpos;
						sType = "effort";
						sEffortTarget = "stun";

						if sLower == "hp" or sLower == "hit points" then
							sEffortTarget = "hp";
						end
					end
			end

			sDice = sMultiplier	.. sDice;	
			local aDice, nMod = StringManager.convertStringToDice(sDice)	
			table.insert(aComponents, {nStart = startpos, nEnd = endpos, sLabel = sWordLower, sType = sType, aDice = aDice, nMod = nMod, bEasy = bEasy, bHard = bHard, sEffortTarget = sEffortTarget;});
		end
	end
	
	bParsed = true;
end

function getActionNode()	
	local nodeAction = window.getDatabaseNode();
	if not nodeAction then
		nodeAction = window.windowlist.window.getDatabaseNode();
	end
	return nodeAction;
end

function getActorNode()
	local nodeAction = getActionNode();
	return nodeAction.getChild("...");
end

function getActor()
	local nodeCreature = getActorNode();
	return ActorManager.resolveActor(nodeCreature);
end

function onValueChanged()
	bParsed = false;
end

-- Reset selection when the cursor leaves the control
function onHover(bOnControl)
	if bOnControl then
		return;
	end

	if not bDragging then
		onDragEnd();
	end
end

-- Hilight keyword hovered on
function onHoverUpdate(x, y)
	if bDragging or bClicked then
		return;
	end

	if not bParsed then
		parseComponents();
	end
	local nMouseIndex = getIndexAt(x, y);

	for i = 1, #aComponents, 1 do
		if aComponents[i].nStart <= nMouseIndex and aComponents[i].nEnd > nMouseIndex then
			setCursorPosition(aComponents[i].nStart);
			setSelectionPosition(aComponents[i].nEnd);

			nDragIndex = i;
			setHoverCursor("hand");
			return;
		else
			setSelectionPosition(0);
		end
	end
	
	nDragIndex = nil;
	setHoverCursor("arrow");
end

function action(draginfo)
	if nDragIndex then
		local comp = aComponents[nDragIndex];
		local actorNode = getActorNode();
		local rActor = getActor();
		local rRoll = { sType = comp.sType, aDice = comp.aDice, nMod = comp.nMod };
		rRoll.sDesc = "[" .. comp.sLabel:upper() .. " " .. comp.sType:upper() .. "]";

		if comp.bEasy then
			rRoll.sDesc = rRoll.sDesc .. " [EASY]";
		end
		if comp.bHard then
			rRoll.sDesc = rRoll.sDesc .. " [HARD]";
		end

		-- Add modifier and roll
		local bMultStat = OptionsManager.getOption("MESD") == "on";
		if comp.sType == "attempt" then
			rRoll.nMod = DB.getValue(actorNode, "stats." .. DataCommon.stats_stol[comp.sLabel:upper()], 0)
			ActionAttempt.performNPCRoll(draginfo, rActor, rRoll);
		elseif comp.sType == "effort" then
			local mod = DB.getValue(actorNode, "effort." .. comp.sLabel:lower(), 0)
			if bMultStat then
				mod = mod * #(rRoll.aDice);
			end
			if rRoll.nMod then
				mod = mod + rRoll.nMod;
			end

			if comp.sEffortTarget then
				rRoll.sDesc = rRoll.sDesc .. " [" .. comp.sEffortTarget:upper() .. "]";
			end
			
			rRoll.nMod = mod;
			ActionEffort.performNPCRoll(draginfo, rActor, rRoll);
		elseif comp.sType == "timer" then
			ActionEffort.performNPCRoll(draginfo, rActor, rRoll);
		elseif comp.sType == "dice" then
			rRoll.sDesc = getDatabaseNode().getChild("..").getChild("name").getValue();
			ActionsManager.performAction(draginfo, rActor, rRoll);
		end
	end
end

function onDoubleClick(x, y)
	action();
	return true;
end

function onDragStart(button, x, y, draginfo)
	action(draginfo);

	bClicked = false;
	bDragging = true;
	
	return true;
end

function onDragEnd(draginfo)
	bClicked = false;
	bDragging = false;
	nDragIndex = nil;
	setHoverCursor("arrow");
	setCursorPosition(0);
	setSelectionPosition(0);
end

-- Suppress default processing to support dragging
function onClickDown(button, x, y)
	bClicked = true;
	return true;
end

-- On mouse click, set focus, set cursor position and clear selection
function onClickRelease(button, x, y)
	bClicked = false;
	setFocus();
	
	local n = getIndexAt(x, y);
	setSelectionPosition(n);
	setCursorPosition(n);
	
	return true;
end
