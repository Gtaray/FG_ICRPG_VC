function (v)
    local rActor = ActorManager.resolveActor(v);
    local bIsPC = ActorManager.isPC(rActor);

    local nHP = 0;
    local nWounds = 0;

    local nodeActor = ActorManager.getCreatureNode(rActor);
    if not nodeActor then
        return 0, "";
    end
    
    nHP = math.max(DB.getValue(nodeActor, "health.stun", 0), 0);
    nWounds = math.max(DB.getValue(nodeActor, "health.stundmg", 0), 0);
    
    local nPercentWounded = 0;
    if nHP > 0 then
        nPercentWounded = nWounds / nHP;
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