--[[
   Red Alert: Ukraine - Mi-8 air assault (support power of the Ukrainian airfield).

   SpawnActorPower@heliassault on AFLD.Ukraine (rules/ukraine.yaml) drops an
   invisible "heliassault.marker" actor on the chosen cell. This script picks
   the marker up, removes it and sends two Mi-8 helicopters: they fly in from
   the map edge on the side of the player's base, land next to each other at
   the marker, unload 4 infantry each (8 in total), take off and fly back off
   the map the way they came.

   Loaded on every map through World > LuaScript (rules/ukraine.yaml). Maps
   that bring their own Lua (campaign missions, the shellmap) replace the
   script list; the Ukrainian faction is not playable there.
]]

HeliAssault =
{
	Marker = "heliassault.marker",
	Transport = "mi8",
	Cargo =
	{
		{ "e1", "e1", "e3", "uavop" },
		{ "e1", "e1", "e3", "uavop" }
	},
	-- cells between the two landing spots
	Spacing = 2,
	-- ticks between the two helicopters entering the map
	SecondDelay = 10,
	-- the landing zone stays revealed for this long after the troops get out
	CameraDuration = DateTime.Seconds(20),
	-- how often (in ticks) to look for new markers
	PollInterval = 3
}

local players = { }
local ticks = 0
local minX, minY, maxX, maxY

local function Clamp(value, low, high)
	if value < low then
		return low
	end

	if value > high then
		return high
	end

	return value
end

local function Round(value)
	return math.floor(value + 0.5)
end

local function ClampCell(x, y)
	return CPos.New(Clamp(Round(x), minX, maxX), Clamp(Round(y), minY, maxY))
end

-- Playable map area in cells (one cell inside the border).
local function ReadBounds()
	local topLeft = Map.TopLeft
	local bottomRight = Map.BottomRight
	minX = math.floor(topLeft.X / 1024) + 1
	minY = math.floor(topLeft.Y / 1024) + 1
	maxX = math.floor(bottomRight.X / 1024) - 2
	maxY = math.floor(bottomRight.Y / 1024) - 2
	if maxX < minX then
		maxX = minX
	end

	if maxY < minY then
		maxY = minY
	end
end

-- Map edge cell hit by the ray from (x, y) along (dx, dy).
local function EdgeAlong(x, y, dx, dy)
	local t = 100000
	if dx > 0 then
		t = math.min(t, (maxX - x) / dx)
	elseif dx < 0 then
		t = math.min(t, (minX - x) / dx)
	end

	if dy > 0 then
		t = math.min(t, (maxY - y) / dy)
	elseif dy < 0 then
		t = math.min(t, (minY - y) / dy)
	end

	if t < 0 then
		t = 0
	end

	return x + dx * t, y + dy * t
end

local function SendHelicopter(owner, cargo, entry, landing, onUnload)
	local result = Reinforcements.ReinforceWithTransport(owner, HeliAssault.Transport, cargo, { entry, landing }, { entry })
	local heli = result[1]
	if heli ~= nil and onUnload ~= nil then
		local unloaded = false
		Trigger.OnPassengerExited(heli, function()
			if not unloaded then
				unloaded = true
				onUnload(heli)
			end
		end)
	end
end

local function LaunchAssault(owner, target)
	-- bots: land next to the enemy base, away from its air defence and base
	-- defences, not in the middle of it (ukraine-ai.lua, when it is loaded)
	if UkraineAI and UkraineAI.AdjustAssaultTarget then
		target = UkraineAI.AdjustAssaultTarget(owner, target)
	end

	local tx, ty = target.X, target.Y

	-- come in from the side of the player's base (fall back to the nearest edge)
	local home = owner.HomeLocation
	local dx, dy = home.X - tx, home.Y - ty
	if dx * dx + dy * dy < 16 then
		local edge = Map.ClosestEdgeCell(target)
		dx, dy = edge.X - tx, edge.Y - ty
	end

	if dx == 0 and dy == 0 then
		dy = 1
	end

	local length = math.sqrt(dx * dx + dy * dy)
	dx, dy = dx / length, dy / length

	-- second helicopter flies parallel to the first one, Spacing cells to the side
	local px, py = -dy * HeliAssault.Spacing, dx * HeliAssault.Spacing

	local ex, ey = EdgeAlong(tx, ty, dx, dy)
	local entryA = ClampCell(ex, ey)
	local entryB = ClampCell(ex + px, ey + py)
	local landingA = ClampCell(tx, ty)
	local landingB = ClampCell(tx + px, ty + py)

	local announced = false
	local onUnload = function(heli)
		if announced then
			return
		end

		announced = true
		Media.PlaySpeechNotification(owner, "ReinforcementsArrived")
		local camera = Actor.Create("camera.paradrop", true, { Owner = owner, Location = landingA })
		Trigger.AfterDelay(HeliAssault.CameraDuration, function()
			if not camera.IsDead then
				camera.Destroy()
			end
		end)
	end

	SendHelicopter(owner, HeliAssault.Cargo[1], entryA, landingA, onUnload)
	Trigger.AfterDelay(HeliAssault.SecondDelay, function()
		SendHelicopter(owner, HeliAssault.Cargo[2], entryB, landingB, onUnload)
	end)
end

WorldLoaded = function()
	ReadBounds()
	players = Player.GetPlayers(function(p) return not p.IsNonCombatant end)
end

Tick = function()
	ticks = ticks + 1
	if ticks % HeliAssault.PollInterval ~= 0 then
		return
	end

	for _, player in ipairs(players) do
		local markers = player.GetActorsByType(HeliAssault.Marker)
		for _, marker in ipairs(markers) do
			-- Destroy() is queued, so the marker can still be listed by the next
			-- poll: the tag makes sure every marker launches only one assault
			if marker.AddTag("launched") then
				local location = marker.Location
				marker.Stop()
				marker.Destroy()
				LaunchAssault(player, location)
			end
		end
	end
end
