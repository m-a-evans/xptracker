local frame = CreateFrame("FRAME");
--frame:RegisterEvent("ADDON_LOADED");
--frame:RegisterEvent("PLAYER_LOGOUT");
frame:RegisterEvent("PLAYER_ENTERING_WORLD");
frame:RegisterEvent("PLAYER_LOGIN");
frame:RegisterEvent("PLAYER_LEVEL_UP");
--frame:RegisterEvent("PLAYER_MONEY");
--frame:RegisterEvent("PLAYER_XP_UPDATE");
--frame:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN");
local g_xpAtSessionStart = 0;
local g_repGainedThisSession = 0;
local g_cashAtSessionStart = 0;
local g_faction = "";
local g_timeAtSessionStart = nil;
local g_xpTilNextLevel = 0;
local g_xpGainedThisSession = 0;
local g_levelsGained = 0;
local g_isDebugMode = false;
local g_currentXp = 0;
local g_isOn = true;
local g_MAX_LEVEL = 70;

frame:SetScript("OnEvent", function(self, event, ...)
	--dbug("event = " .. event);
	if event == "PLAYER_ENTERING_WORLD" then
		if time() - g_timeAtSessionStart > 5 then
			PrettyPrint();
		end
	elseif event == "PLAYER_LOGIN" then
		InitVariables();
	elseif event == "PLAYER_LEVEL_UP" then
		dbug("level up detected!");
		g_levelsGained = g_levelsGained + 1;
		dbug("unit xp max is detected as " .. tostring(UnitXPMax("player")));
		dbug("xpGained is " .. tostring(g_xpGainedThisSession));
		if g_levelsGained == 1 then 
			dbug("1 level gained ... setting xpGained = " .. tostring(UnitXPMax("player") - g_xpAtSessionStart));
			g_xpGainedThisSession = UnitXPMax("player") - g_xpAtSessionStart;
		else
			dbug("many levels gained ... setting xpGained = " .. tostring(UnitXPMax("player") + g_xpGainedThisSession));
			g_xpGainedThisSession = UnitXPMax("player") + g_xpGainedThisSession;
		end
	end
end)

function dbug(...)
	if g_isDebugMode then 
		local msg;
		local argsPassed = {...};
		for i = 1, select('#', unpack(argsPassed)) do
			msg = select(i, ...);
			DEFAULT_CHAT_FRAME:AddMessage("DEBUG XPT - " .. tostring(msg));
		end
	end
end

function DisplayToDefaultChat(msg, r, g, b)
	if (g_isOn) then
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
		DEFAULT_CHAT_FRAME:AddMessage(msg, red,green,blue);
	end
end

function FormatTime(inTimeInSeconds) 
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

function ElapsedTimeInSeconds(startTime)
	dbug("finding elapsed time... input: " .. startTime);
	local ret;
	if g_timeAtSessionStart ~= nil then
		ret = (time() - startTime);
	else 
		ret = 0;
	end
	return ret;
end

function XpTilNextLevelETA(xpGained, timeElapsedInSeconds)
	dbug("determining xp til next level ... input: " .. xpGained .. ", " .. timeElapsedInSeconds);
	local ret;
	if timeElapsedInSeconds > 0 and xpGained > 0 then
		local timeInHours = timeElapsedInSeconds / 60 / 60;
		dbug("time calculated in hours", timeInHours);
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

function InitVariables()
	--init variables
	dbug("initing variables...");
	-- reset vars
	g_timeAtSessionStart = time();
	g_xpAtSessionStart = UnitXP("player");
	dbug("setting xp at start to " , g_xpAtSessionStart);
	--g_repGainedThisSession = 0;
	g_cashAtSessionStart = GetMoney();
	dbug("setting money to " , GetCoinText(g_cashAtSessionStart), " ");
	--g_faction = "";
	g_xpTilNextLevel = XpTilNextLevel();
	g_xpGainedThisSession = 0;
	g_levelsGained = 0;
end

function GoldRate(copperGained, timeElapsedInSeconds)
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
			if (copperPerSecond < 0) then
				dbug(math.floor((math.abs(copperPerSecond))));
				ret = "-" .. GetCoinText(math.floor((math.abs(copperPerSecond)  * timeIncrement)), " ") .. " per " .. timeUnit;
			else 
				ret = GetCoinText(math.floor((copperPerSecond  * timeIncrement)), " ") .. " per " .. timeUnit;
			end
		end;
	else
		ret = "time hasn't elapsed!";
	end
	return ret;
end

function GetAppropriateTimeSegment(timeElapsedInSeconds)
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

function PrettyPrint()
	local timeInSeconds = ElapsedTimeInSeconds(g_timeAtSessionStart);
	PrettyPrintXp(timeInSeconds);
	--PrettyPrintRep();
	PrettyPrintCash(timeInSeconds);
end

function PrettyPrintRep(inElapsedTime)
	--not implemented yet
	local elapsedTime = inElapsedTime;
	if (elapsedTime == nil) then
		elapsedTime = ElapsedTimeInSeconds(g_timeAtSessionStart);
	end
	--print("Reputation gained for g_faction: " .. g_faction .. ": " .. g_repGainedThisSession);
end

function PrettyPrintXp(inElapsedTime)
	if (UnitLevel("player") ~= g_MAX_LEVEL) then 
		local xpGained;
		local rate = 0;
		local timeScale = 0; 
		local timeScaleWord = "sec";
		if g_levelsGained > 0 then
			-- Get running level xp, plus whatever the player has right now (new level xp starts at 0)
			xpGained = g_xpGainedThisSession + UnitXP("player");
		else 
			--otherwise, we can just display the current xp minus the xp from the start
			xpGained = UnitXP("player") - g_xpAtSessionStart;
		end;
		
		local elapsedTime = inElapsedTime;
		if (elapsedTime == nil) then
			elapsedTime = ElapsedTimeInSeconds(g_timeAtSessionStart);
		end
		
		--dbug("elapsed time");
		--dbug(elapsedTime);
		
		local timeIncrement, timeUnit = GetAppropriateTimeSegment(elapsedTime);
		
		dbug(timeIncrement);
		rate = math.floor(xpGained / (elapsedTime / timeIncrement));
		
		DisplayToDefaultChat("Time Elapsed: " .. FormatTime(elapsedTime));
		DisplayToDefaultChat("Experience gained during session so far: " .. xpGained);
		DisplayToDefaultChat("Xp Rate: " .. rate .. " /" .. timeUnit);
		DisplayToDefaultChat("Levels gained during session so far: " .. g_levelsGained);		
		DisplayToDefaultChat("ETA til next level: " .. XpTilNextLevelETA(xpGained, elapsedTime));
	end 
end

function PrettyPrintCash(inElapsedTime)
	local elapsedTime = inElapsedTime;
	if (elapsedTime == nil) then
		elapsedTime = ElapsedTimeInSeconds(g_timeAtSessionStart);
	end
	
	local netCash = GetMoney() - g_cashAtSessionStart;
	local cashMessageBase = "Cash gained during session so far: ";
	local cashMessage = cashMessageBase .. "... Nothing!! Your cash hasn't changed!";
	if netCash > 0 then 
		cashMessage = cashMessageBase .. GetCoinText(netCash, " ");
	elseif netCash < 0 then
		cashMessage = cashMessageBase .. " -" .. GetCoinText(math.abs(netCash), " ");
	end
	DisplayToDefaultChat(cashMessage);
	DisplayToDefaultChat("Cash Rate: " .. GoldRate(netCash, elapsedTime));
end

function XpTilNextLevel()
	return (UnitXPMax("player") - UnitXP("player"));
end

function ToggleDebug()
	g_isDebugMode = not g_isDebugMode;
end

SLASH_XPT1 = "/xpt";
SlashCmdList["XPT"] = function(msg, editbox) 
	dbug(msg);
	if msg == nil or msg == "" then
		PrettyPrint();
	elseif msg == "reset" then
		DisplayToDefaultChat("Resetting XPT data... Session will start as of your current state now.");
		InitVariables();
	elseif msg == "debug" then
		ToggleDebug();
		if g_isDebugMode then 
			DisplayToDefaultChat("Debug Mode is on.", 1,0,0);
		else 
			DisplayToDefaultChat("Debug Mode is off.");
		end
	elseif msg == "help" then
		DisplayToDefaultChat("Type '/xpt' to get a printout of the session. Type '/xpt reset' to reset the current session. Type '/xpt mute' to toggle the mute.", 0, 1, 0);
		--DisplayToDefaultChat("Type '/xpt' to get a printout of the session. Type '/xpt reset' to reset the current session. Type '/xpt debug' to toggle debug mode.", 0, 1, 0);
	elseif msg == "mute" then
		if (g_isOn) then
			DisplayToDefaultChat("Muting XPT...", 0, 1, 0);
			g_isOn = false;
		else 
			g_isOn = true;
			DisplayToDefaultChat("Unmuting XPT...");
		end
	end
end

--]]