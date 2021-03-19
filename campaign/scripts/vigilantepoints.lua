local updating = false;
function onInit()
    local node = getDatabaseNode();
    DB.addHandler(DB.getPath(node, "vp.vp11"), "onUpdate", onVPChanged);
    DB.addHandler(DB.getPath(node, "vp.vp12"), "onUpdate", onVPChanged);
    DB.addHandler(DB.getPath(node, "vp.vp13"), "onUpdate", onVPChanged);
    DB.addHandler(DB.getPath(node, "vp.vp14"), "onUpdate", onVPChanged);

    DB.addHandler(DB.getPath(node, "vp.vp9"), "onUpdate", onVPChanged);
    DB.addHandler(DB.getPath(node, "vp.vp8"), "onUpdate", onVPChanged);
    DB.addHandler(DB.getPath(node, "vp.vp7"), "onUpdate", onVPChanged);
    DB.addHandler(DB.getPath(node, "vp.vp6"), "onUpdate", onVPChanged);
end

function onClose()
    local node = getDatabaseNode();
    DB.removeHandler(DB.getPath(node, "vp.vp11"), "onUpdate", onVPChanged);
    DB.removeHandler(DB.getPath(node, "vp.vp12"), "onUpdate", onVPChanged);
    DB.removeHandler(DB.getPath(node, "vp.vp13"), "onUpdate", onVPChanged);
    DB.removeHandler(DB.getPath(node, "vp.vp14"), "onUpdate", onVPChanged);

    DB.removeHandler(DB.getPath(node, "vp.vp9"), "onUpdate", onVPChanged);
    DB.removeHandler(DB.getPath(node, "vp.vp8"), "onUpdate", onVPChanged);
    DB.removeHandler(DB.getPath(node, "vp.vp7"), "onUpdate", onVPChanged);
    DB.removeHandler(DB.getPath(node, "vp.vp6"), "onUpdate", onVPChanged);
end

function onVPChanged(nodeChanged)
    if updating then return; end

    updating = true;
    local nodeActor = nodeChanged.getChild("...")
    local nVpNodeVal = tonumber(nodeChanged.getName():match("vp(%d+)")) - 10;
    local nNewVp = 0;
    
    -- if we're unchecking a checkbox, set new value to +/-1 the value checked
    if nodeChanged.getValue() == 0 then
        if nVpNodeVal > 0 then 
            nNewVp = nVpNodeVal - 1;
        elseif nVpNodeVal < 0 then
            nNewVp = nVpNodeVal + 1;
        end
    elseif nodeChanged.getValue() == 1 then
        -- if checking a value, set new value to the checked value
        nNewVp = nVpNodeVal;
    end
    VigilanteCity.setVP(nodeActor, nNewVp);

    updating = false;
end