-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	super.onInit();
	onHealthChanged();
    onStunChanged();
end

function onFactionChanged()
	super.onInit();
	updateHealthDisplay();
end

function onHealthChanged()
	local rActor = ActorManager.resolveActor(getDatabaseNode())
	local sColor = HealthManager.getHealthColor(rActor, "hp");
	
	wounds.setColor(sColor);
end

function onStunChanged()
    local rActor = ActorManager.resolveActor(getDatabaseNode())
    local sColor = HealthManager.getHealthColor(rActor, "stun");

	status.setColor(sColor);
	stundmg.setColor(sColor);
end

function updateHealthDisplay()
	local sOption;
	if friendfoe.getStringValue() == "friend" then
		sOption = OptionsManager.getOption("SHPC");
	else
		sOption = OptionsManager.getOption("SHNPC");
	end
	
	if sOption == "detailed" then
		stundmg.setVisible(true);
		wounds.setVisible(true);

		status.setVisible(false);
	elseif sOption == "status" then
		stundmg.setVisible(false);
		wounds.setVisible(false);
        
		status.setVisible(true);
	else
		stundmg.setVisible(false);
		wounds.setVisible(false);

		status.setVisible(false);
	end
end
