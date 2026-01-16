-- frame - this is the hook into wow
local frame = CreateFrame("FRAME");
frame:RegisterEvent("PLAYER_ENTERING_WORLD");
frame:RegisterEvent("PLAYER_LEVEL_UP");
frame:RegisterEvent("ADDON_LOADED"); -- Fired when saved variables are loaded
frame:RegisterEvent("PLAYER_LOGOUT"); -- Fired when about to log out

-- constants
local MAX_LEVEL = 70;
local CHAT_NAME = "XPT_MSG";

-- locals
local xpAtSessionStart = 0;
local repGainedThisSession = 0;
local cashAtSessionStart = 0;
local faction = "";
local timeAtSessionStart = nil;
local xpTilNextLevel = 0;
local xpGainedThisSession = 0;
local levelsGained = 0;
local isDebugMode = false;
local currentXp = 0;
local isOn = true;
local reputationData = nil;
local trackedRep;
local initialized = false;

-- Chat Setup
ChatTypeInfo[CHAT_NAME] = {
	r = 1.0,
	g = 1.0,
	b = 0.5,
	sticky = 0
};
ChatTypeGroup[CHAT_NAME] = { CHAT_NAME };


-- This function prints strings into custom chat windows.
local function DisplayToCustomChat(msg, r, g, b)
    if (not isOn) then
        return;
    end

    -- Determine final RGB values
    local red   = r or 1;
    local green = g or 1;
    local blue  = b or 0.5;

    -- Convert to WoW color code if custom RGB was provided
    local coloredMsg
    if r and g and b then
        coloredMsg = ("|cff%02x%02x%02x%s|r"):format(red * 255, green * 255, blue * 255, msg);
    else
        coloredMsg = msg;
    end

    -- ChatTypeInfo entry for your category
    local info = ChatTypeInfo[CHAT_NAME];

	for i = 1, NUM_CHAT_WINDOWS do
		local cframe = _G["ChatFrame"..i];

		-- Fire the message through the chat system
		cframe:AddMessage(
			msg, r, g, b
		);
	end
end

-- This function prints strings into the default chat window, with an optional corresponding
-- color for the text.
local function DisplayToDefaultChat(msg, r, g, b)
	if (not isOn) then
		return;
	end
	local red, green, blue;
	if r ~= nil and g ~= nil and b ~= nil then
		red = r;
		green = g;
		blue = b;
	else 
		red = 1;
		green = 1;
		blue = 0.5;
	end
	DEFAULT_CHAT_FRAME:AddMessage(msg, red, green, blue);
end

-- Displays text to chat with optional specified color
local function DisplayToChat(msg, r, g, b)
	DisplayToCustomChat(msg, r, g, b);
end

-- This function writes a debug message to chat window.
local function dbug(...)
	if isDebugMode then 
		local msg;
		local argsPassed = {...};
		for i = 1, select('#', unpack(argsPassed)) do
			msg = select(i, ...);
			-- DEFAULT_CHAT_FRAME:AddMessage("DEBUG XPT - " .. tostring(msg));
			DisplayToChat("DEBUG XPT - " .. tostring(msg));
		end
	end
end

-- This function finds the difference between next level xp, and current xp.
local function XpTilNextLevel()
	return (UnitXPMax("player") - UnitXP("player"));
end

-- This function toggles debug messages.
local function ToggleDebug()
	isDebugMode = not isDebugMode;
end

-- This function checks if a string starts with a string prefix.
local function startsWith(str, prefix)
	return string.sub(str, 1, #prefix) == prefix;
end

-- This function splits a string by a delimiter and returns the pieces in a table.
local function split(str, delimiter)
local result = {}
    for match in (str .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match)
    end
    return result
end

-- This function rounds to the nearest 2 decimal places.
local function round2(n)
    return math.floor(n * 100 + 0.5) / 100
end

-- This function converts a seconds value to the nearest segment (minutes, hours) along 
-- with the seconds value converted to the appropriate segment.
local function GetAppropriateTimeSegment(timeElapsedInSeconds)
	local timeIncrement = 60;
	local timeUnit = " minute"
	if (timeElapsedInSeconds > 3600) then
		-- hour+
		timeIncrement = 60 * 60;
		timeUnit = " hour"
	elseif (timeElapsedInSeconds > 600) then
		-- 1/2 hour+
		timeIncrement = 60 * 30;
		timeUnit = " 30 minutes"
	end
	return timeIncrement, timeUnit;
end

-- This function searches through all the reputations and compiles them into g_reputationData.
local function GetReputations()
	local reputationDataLocal = reputationData or {};
	dbug("getting all reputation data...");
	dbug("Numfactions = ".. GetNumFactions());
	for i = 1, GetNumFactions() do
		local name, _, _, bottomValue, topValue, earnedValue,
			  _, _, isHeader, _, hasRep, _,
			  _, factionID = GetFactionInfo(i);

		dbug("examining " .. name .. " - isHeader = " .. tostring(isHeader) .. " and hasRep = " .. tostring(hasRep));
		if (not isHeader) then
			if (not reputationDataLocal[factionID]) then 
				dbug("adding new faction to data - " .. name .. " (" .. earnedValue .. ", " .. bottomValue .. "-" .. topValue .. ")");
				reputationDataLocal[factionID] = {
					name = name,
					start = earnedValue,
					current = earnedValue,
					minValue = bottomValue,
					maxValue = topValue
				};
			else 
				local entry = reputationDataLocal[factionID];
				dbug("updating faction data - " .. entry.name .. " (" .. entry.current .. " -> " .. earnedValue .. ", " .. bottomValue .. "-" .. topValue .. ")");
				entry.current = earnedValue;
				entry.minValue = bottomValue;
				entry.maxValue = topValue;
			end 
		end
	end	
	reputationData = reputationDataLocal;
end

-- This function initializes the global variables.
local function InitVariables()
	--init variables
	dbug("initing variables...");
	-- reset vars
	timeAtSessionStart = time();
	xpAtSessionStart = UnitXP("player");
	dbug("setting xp at start to " , xpAtSessionStart);
	--repGainedThisSession = 0;
	cashAtSessionStart = GetMoney();
	dbug("setting money to " , GetCoinText(cashAtSessionStart), " ");
	--faction = "";
	xpTilNextLevel = XpTilNextLevel();
	xpGainedThisSession = 0;
	levelsGained = 0;
	trackedRep = XptDb.trackedRep;
	GetReputations();
	initialized = true;
end

-- This function converts a seconds value to its nearest whole unit (minutes, hours).
local function FormatTime(inTimeInSeconds) 
	dbug("formatting time... input: " , inTimeInSeconds);
	local ret = "0 Hours 0 Minutes 0 Seconds";
	local seconds = tonumber(inTimeInSeconds);
	dbug("seconds = " .. tostring(seconds));
	if seconds ~= nil then 
		local hours = math.floor(seconds / (60 * 60));
		seconds = seconds - (hours * 60 * 60);
		local minutes = math.floor(seconds / 60);
		seconds = seconds - (minutes * 60);
		ret = tostring(hours) .. " hours " .. tostring(minutes) .. " minutes " .. tostring(seconds) .. " seconds";
	end
	return ret;
end

-- This function finds the time elapsed in seconds since we started tracking time.
local function ElapsedTimeInSeconds(startTime)
	dbug("finding elapsed time... input: " .. startTime);
	local ret;
	if timeAtSessionStart ~= nil then
		ret = (time() - startTime);
	else 
		ret = 0;
	end
	return ret;
end

-- This function estimates the time it will take to obtain the next level, based on the 
-- experience rate so far. The longer the play session, the more accurate.
local function XpTilNextLevelETA(xpGained, timeElapsedInSeconds)
	dbug("determining xp til next level ... input: " .. xpGained .. ", " .. timeElapsedInSeconds);
	local ret;
	if timeElapsedInSeconds > 0 and xpGained > 0 then
		dbug("xp remaining ", UnitXPMax("player") - UnitXP("player"));
		-- xp remaining / rate at which xp was gained in hours = eta on next level in hours
		dbug("without math floor " .. ((UnitXPMax("player") - UnitXP("player")) / (xpGained / timeElapsedInSeconds)));
		dbug("with " .. math.floor((UnitXPMax("player") - UnitXP("player")) / (xpGained / timeElapsedInSeconds)));
		ret = FormatTime(math.floor((UnitXPMax("player") - UnitXP("player")) / (xpGained / timeElapsedInSeconds)));
	elseif xpGained == 0 then
		ret = "you haven't gained any xp!";
	else
		ret = "time hasn't elapsed!";
	end;
	return ret;
end

-- This function estimates the time required to obtain the next rank of reputation. 
-- The longer the play session, the more accurate (per rep).
local function RepTilNextLevelETA(repGained, repMin, repMax, timeElapsedInSeconds)
	dbug("determining rep til next faction level ... input: " .. repGained .. ", " .. timeElapsedInSeconds);
	local ret;
	if timeElapsedInSeconds > 0 and repGained > 0 then
		dbug("rep remaining ", repGoal - repGained);
		-- rep remaining / rate at which rep was gained in hours = eta on next rep level in hours
		dbug("with " .. math.floor(repMax - repMin, repGained - repStart) / (repGained / timeElapsedInSeconds));
		ret = FormatTime(math.floor(repMax - repGained - repStart) / (repGained / timeElapsedInSeconds));
	elseif repGained == 0 then
		ret = "you haven't gained any xp!";
	else
		ret = "time hasn't elapsed!";
	end;
	return ret;
end

-- This function prints reputation data for a particular faction.
local function PrintReputationForFaction(timeElapsedInSeconds, factionID, showEta)
	dbug("printing rep for faction " .. factionID);
	local ret = "FactionID not in data! " .. factionID;
	GetReputations();
	local entry = reputationData[tonumber(factionID)];
	dbug("entry " .. factionID .. " in reputationData is " .. tostring(entry));
	dbug(reputationData);
	if (entry) then 
		local sessionGained = entry.current - entry.start;
		if (sessionGained > 0) then		
			local timeIncrement, timeUnit = GetAppropriateTimeSegment(timeElapsedInSeconds);
			DisplayToChat(entry.name .. ": " .. sessionGained .. " reputation gained. (" .. (round2(sessionGained / (timeElapsedInSeconds / timeIncrement))) .. " rep /" .. timeUnit .. ")", 0, 1, 0);
			if (showEta) then 
				-- this doesnt work, need a way to feed it the amount gained since the last rep rank
				-- DisplayToChat("Estimated time til next faction level: " .. RepTilNextLevelETA(entry.current, entry.start, entry.maxValue, timeElapsedInSeconds), 1, 1, 0);
			end
		end
	end
	return ret;
end

-- This function prints reputation data for ALL factions.
local function PrintAllReputations(timeElapsedInSeconds)
	GetReputations();
	for i = 1, GetNumFactions() do
		local _, _, _, _, _, _,
			  _, _, isHeader, _, hasRep, _,
			  _, factionID = GetFactionInfo(i);

		if (not isHeader) then
			if (reputationData[factionID]) then 
				PrintReputationForFaction(timeElapsedInSeconds, factionID, false);
			end
		end
	end
end

-- This function lists all factions and their corresponding IDs.
local function ListReps()
	for i = 1, GetNumFactions() do
		local name, _, _, _, _, _,
			  _, _, isHeader, _, _, _,
			  _, factionID = GetFactionInfo(i);
		if (not isHeader) then 
			DisplayToChat(name .. " {" .. factionID .. "}", 1, 1, 0);
		end
	end
end

-- This function finds the gold rate for the current tracked session. Both positive and negative.
local function GoldRate(copperGained, timeElapsedInSeconds)
	dbug("calculating gold per session...");
	dbug(copperGained .. "    " .. timeElapsedInSeconds);
	local ret = "";
	--dbug(timeElapsedInSeconds);
	if (timeElapsedInSeconds > 0) then
		if (copperGained == 0 ) then
			ret = "0 copper per anything. Nothin's been earned, ya ding bat!"
		else 
			local copperPerSecond = (copperGained / timeElapsedInSeconds);
			dbug("copper per second " .. copperPerSecond);
			
			copperPerSecond = math.floor(copperPerSecond);
			local timeIncrement, timeUnit = GetAppropriateTimeSegment(timeElapsedInSeconds);
			dbug(timeIncrement, timeUnit);
			dbug(math.floor((math.abs(copperPerSecond))));
			ret = GetCoinText(math.floor((math.abs(copperPerSecond)  * timeIncrement)), " ") .. " per " .. timeUnit;
			if (copperPerSecond < 0) then
				ret = "-" .. ret;
			end
		end;
	else
		ret = "time hasn't elapsed!";
	end
	return ret;
end

-- This function prints the currently tracked faction's reputation data.
local function PrettyPrintRep(timeElapsedInSeconds)
	dbug("trackedRep is " .. tostring(trackedRep))
	 if (trackedRep) then 		
		PrintReputationForFaction(timeElapsedInSeconds, trackedRep, true);
	end
end

-- This function prints the tracked and derived xp information.
local function PrettyPrintXp(inElapsedTime)
	if (UnitLevel("player") ~= MAX_LEVEL) then 
		local xpGained;
		local rate = 0;
		local timeScale = 0; 
		local timeScaleWord = "sec";
		if levelsGained > 0 then
			-- Get running level xp, plus whatever the player has right now (new level xp starts at 0)
			xpGained = xpGainedThisSession + UnitXP("player");
		else 
			--otherwise, we can just display the current xp minus the xp from the start
			xpGained = UnitXP("player") - xpAtSessionStart;
		end;
        
		local elapsedTime = inElapsedTime;
		if (elapsedTime == nil) then
			elapsedTime = ElapsedTimeInSeconds(timeAtSessionStart);
		end
        
		--dbug("elapsed time");
		--dbug(elapsedTime);
        
		local timeIncrement, timeUnit = GetAppropriateTimeSegment(elapsedTime);
        
		dbug(timeIncrement);
		rate = math.floor(xpGained / (elapsedTime / timeIncrement));
        
		DisplayToChat("Time Elapsed: " .. FormatTime(elapsedTime));
		DisplayToChat("Experience gained during session so far: " .. xpGained,0,1,1);
		DisplayToChat("Xp Rate: " .. rate .. " /" .. timeUnit, 0,1,1);
		DisplayToChat("Levels gained during session so far: " .. levelsGained, 0,1,1);        
		DisplayToChat("ETA til next level: " .. XpTilNextLevelETA(xpGained, elapsedTime), 0,1,1);
	end 
end

-- This function prints the tracked and derived money information.
local function PrettyPrintCash(inElapsedTime)
	local elapsedTime = inElapsedTime;
	if (elapsedTime == nil) then
		elapsedTime = ElapsedTimeInSeconds(timeAtSessionStart);
	end
	
	local netCash = GetMoney() - cashAtSessionStart;
	local cashMessageBase = "Cash gained during session so far: ";
	local cashMessage = cashMessageBase .. "... Nothing!! Your cash hasn't changed!";
	if netCash > 0 then 
		cashMessage = cashMessageBase .. GetCoinText(netCash, " ");
	elseif netCash < 0 then
		cashMessage = cashMessageBase .. " -" .. GetCoinText(math.abs(netCash), " ");
	end
	DisplayToChat(cashMessage);
	DisplayToChat("Cash Rate: " .. GoldRate(netCash, elapsedTime));
end

-- This function runs through each pretty print for each category.
local function PrettyPrint(timeInSeconds)
	PrettyPrintXp(timeInSeconds);
	PrettyPrintRep(timeInSeconds);
	PrettyPrintCash(timeInSeconds);
end

-- This is the input command section
SLASH_XPT1 = "/xpt";
SlashCmdList["XPT"] = function(msg, editbox) 
	dbug(msg);
	if (not initialized) then
		return;
	end
	local timeInSeconds = ElapsedTimeInSeconds(timeAtSessionStart);
	if (msg == nil or msg == "") then
		PrettyPrint(timeInSeconds);
	elseif (msg == "reset") then
		DisplayToChat("Resetting XPT data... Session will start as of your current state now.");
		InitVariables();
	elseif (msg == "debug") then
		ToggleDebug();
		if isDebugMode then 
			DisplayToChat("Debug Mode is on.", 1,0,0);
		else 
			DisplayToChat("Debug Mode is off.");
		end
	elseif (msg == "help") then
		DisplayToChat("Type '/xpt' to get a printout of the session. Type '/xpt reset' to reset the current session. Type '/xpt mute' to toggle the mute.", 1, 1, 0);
		DisplayToChat("Type '/xpt rep' to get a printout of all session's rep gains. Type '/xpt listrep' to list known reps. Type '/xpt setrep' to start tracking a rep.", 1, 1, 0);
	elseif (msg == "mute") then
		if (isOn) then
			DisplayToChat("Muting XPT...", 0, 1, 0);
			isOn = false;
		else 
			isOn = true;
			DisplayToChat("Unmuting XPT...");
		end
	elseif (msg == "rep") then 
		PrintAllReputations(timeInSeconds)
	elseif (msg == "listrep") then 
		ListReps();
	elseif (startsWith(msg, "setrep")) then 
		local splitValues = split(msg, " ");
		dbug(splitValues);
		dbug(#splitValues);
		if (#splitValues > 1) then
			trackedRep = splitValues[2];
			DisplayToChat("Set tracked reputation to " .. reputationData[tonumber(trackedRep)].name,0,1,0);
		else
			trackedRep = nil;
			DisplayToChat("Unset tracked reputation.", 0,1,0);
		end
		
	end
end

-- This is the event hooks that occur.
function frame:OnEvent(event, arg1)
	dbug("event = " .. event);
	if (event == "PLAYER_ENTERING_WORLD") then
		if (timeAtSessionStart) then 
			if (time() - timeAtSessionStart > 5) then
				PrettyPrint();
			end
		end
	elseif (event == "ADDON_LOADED" and arg1 == "xptracker") then
		if XptDb == nil then 
			XptDb = {
				trackedRep = nil
			}
		end
		InitVariables();
	elseif (event == "PLAYER_LOGOUT") then 
		XptDb.trackedRep = trackedRep;
	elseif (event == "UPDATE_FACTION") then 
		dbug("faction updated");
		if (arg1 ~= nil) then 
			dbug("arg1 is " .. arg1);
		end
	elseif (event == "PLAYER_LEVEL_UP") then
		dbug("level up detected!");
		levelsGained = levelsGained + 1;
		dbug("unit xp max is detected as " .. tostring(UnitXPMax("player")));
		dbug("xpGained is " .. tostring(xpGainedThisSession));
		if levelsGained == 1 then 
			dbug("1 level gained ... setting xpGained = " .. tostring(UnitXPMax("player") - xpAtSessionStart));
			xpGainedThisSession = UnitXPMax("player") - xpAtSessionStart;		
		else
			dbug("many levels gained ... setting xpGained = " .. tostring(UnitXPMax("player") + xpGainedThisSession));
			xpGainedThisSession = UnitXPMax("player") + xpGainedThisSession;
		end
	end
end

frame:SetScript("OnEvent", frame.OnEvent);