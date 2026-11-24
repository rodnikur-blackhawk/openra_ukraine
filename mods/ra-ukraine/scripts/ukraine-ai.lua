--[[
   Red Alert: Ukraine - tactical layer for the skirmish bots.

   The stock bot modules (rules/ai.yaml, rules/ra-overrides.yaml,
   rules/ukraine.yaml, rules/ukraine-ai.yaml) decide what to build and run the
   attack squads. This script adds what those modules cannot do, for every bot:

   All factions
     * APCs (the Ukrainian BTR-4 too) ferry infantry from the barracks to the
       front line, unload it and drive back for the next load.
     * When no enemy can be reached by land, landing craft (LST) are built at
       the naval yard and carry troops across the water to a beach next to the
       enemy base that no base defence covers.
   Ukraine
     * Bayraktar TB2: scouting and strikes. Drones watch key points between the
       bases, strike targets that no air defence covers, keep out of air
       defence range, and fly over enemy stealth units, mines and submarines
       near friendly forces so that the bot or its allies can hit them.
     * Lyutyi: salvoes against enemy buildings, at the targets with the least
       air defence around them and on the way to them.
     * Ratel S: hunts enemy vehicles near the base and the troops, and sneaks
       around the base defences to blow up enemy buildings.
     * Sea Baby: attacks enemy ships and naval yards in groups.
     * HUR agents: slip around the base defences towards a refinery or silo,
       killing infantry on the way; they steal the cash there, and steal
       valuable vehicles they come across.
     * Bohdana and Vilkha stay behind the troops, never in the front line.
     * F-16: intercepts enemy aircraft near the base and the troops.
     * Mi-8 air assault: lands next to the enemy base instead of in the middle
       of it, away from its air defence and base defences
       (AdjustAssaultTarget, called by ukraine-heliassault.lua).

   The units driven here are left out of the bots' attack squads by the
   SquadManagerBotModule@*-lua variants (rules/ukraine-ai.yaml). Those only
   switch on through the "ukraine-lua-ai" player condition this script grants
   when it starts, so on maps whose own Lua replaces this script the bots keep
   the stock behaviour.

   Loaded on every map through World > LuaScript (rules/ukraine.yaml), after
   ukraine-heliassault.lua: WorldLoaded and Tick of that script are chained.

   Determinism: all players run this script in lockstep, so it only uses the
   synced random generator (Utils), never iterates tables keyed by actors and
   never compares actors (only their positions, types and tags).
]]

UkraineAI = UkraineAI or { }
local AI = UkraineAI

-- Internal names of non-bot players to drive as well (test maps only).
AI.TestPlayers = AI.TestPlayers or { }
-- Write what the bots decide to the "lua" log (test maps only).
AI.Verbose = AI.Verbose or false

local ChainedWorldLoaded, ChainedTick = WorldLoaded, Tick

-- ---------------------------------------------------------------------------
-- Settings

local Second = 25
local UpdateInterval = 25       -- each bot thinks once a second
local ScanInterval = 50         -- world snapshot every 2 seconds
local KeyPointInterval = 750    -- TB2 key points are recomputed every 30 seconds

local function Set(list)
	local s = { }
	for _, v in ipairs(list) do
		s[v] = true
	end
	return s
end

-- terrain the ground units, the landing craft and the other ships move on
local LandTerrain = Set { "Clear", "Rough", "Road", "Bridge", "Ore", "Gems", "Beach" }
local CraftTerrain = Set { "Water", "Beach" }
local DeepTerrain = Set { "Water" }

-- units driven by this script: type -> kind
local Kinds =
{
	apc = "apc", btr4 = "apc",
	lst = "lst",
	tb2 = "tb2", lyutyi = "lyutyi", f16 = "f16",
	ratel = "ratel", seababy = "seababy", gur = "gur",
	bohdana = "arty", vilkha = "arty"
}

local NavalYardTypes = Set { "spen", "syrd", "spen.ukraine" }
local BarracksTypes = Set { "barr", "tent", "barr.ukraine" }
local ConstructionYardTypes = Set { "fact" }
local CashTypes = Set { "proc", "silo" }
local WallTypes = Set { "sbag", "fenc", "brik", "cycl", "barb", "wood", "fenc.civ" }
local NavalTypes = Set { "ss", "msub", "dd", "ca", "lst", "pt", "seababy", "mazepa" }
local InfantryTypes = Set { "e1", "e2", "e3", "e4", "e6", "e7", "medi", "mech", "spy", "thf", "shok", "dog",
	"uavop", "gur", "einstein", "delphi", "chan", "c1", "c2", "c3", "c4", "c5", "c6", "c7", "c8", "c9", "c10" }

-- infantry that rides an APC to the front
local RiflemenTypes = Set { "e1", "e2", "e3", "e4", "e7", "shok", "uavop", "medi", "mech" }
-- own units never loaded into a landing craft
local NotCargoTypes = Set { "harv", "mcv", "mnly", "truk", "dog", "e6", "spy", "thf", "gur", "apc", "btr4",
	"lst", "ratel", "dtrk", "qtnk", "jeep" }
-- units that are not part of the fighting army for the front line estimate
local NotArmyTypes = Set { "harv", "mcv", "mnly", "truk", "dog", "e6", "spy", "thf", "gur", "apc", "btr4",
	"ratel", "dtrk", "bohdana", "vilkha", "arty", "v2rl", "medi", "mech" }

-- air defence: type -> reach against aircraft in cells (weapon range)
local AntiAir =
{
	sam = 7.5, agun = 10, ftrk = 8, gepard = 8.5, e3 = 7.5, dd = 7.5, msub = 8,
	["4tnk"] = 6.5, oplot = 6, mazepa = 8, f16 = 9, heli = 4
}

-- base defences: type -> reach against ground units in cells
local GroundDefence =
{
	pbox = 6, hbox = 6, gun = 6.5, ftur = 5, tsla = 8.5, dbnk = 5, stugna = 7.5
}

-- enemy units hidden from normal sight that a TB2 reveals (cloak, mines, submarines)
local StealthTypes = Set { "ss", "msub", "stnk", "thf", "gur", "minp", "minv" }

-- what a Lyutyi / Ratel strike is worth, on top of the building's cost
local StrikePriority =
{
	fact = 2.5, weap = 2.0, barr = 1.6, tent = 1.6, ["barr.ukraine"] = 1.6, afld = 1.8, ["afld.ukraine"] = 1.8,
	hpad = 1.8, spen = 1.5, syrd = 1.5, ["spen.ukraine"] = 1.5, powr = 1.7, apwr = 1.8, proc = 1.6,
	dome = 1.5, atek = 1.6, stek = 1.6, ["stek.ukraine"] = 1.6, fix = 1.3,
	mslo = 2.5, iron = 2.5, pdox = 2.5, gap = 1.6, flamingo = 2.2, pokrova = 2.2,
	sam = 1.2, agun = 1.2
}

-- what a TB2 strike is worth, on top of the unit's cost
local HuntPriority = { harv = 2.0, arty = 1.8, v2rl = 1.8, vilkha = 1.8, bohdana = 1.8, mnly = 1.2, mcv = 2.5 }

-- ---------------------------------------------------------------------------
-- Helpers

local tick = 0
local reportedErrors = 0

local function Log(text)
	if AI.Verbose and print then
		print("[ukraine-ai " .. tick .. "] " .. text)
	end
end

local function Try(f, ...)
	if pcall then
		local ok, err = pcall(f, ...)
		if not ok and reportedErrors < 5 then
			reportedErrors = reportedErrors + 1
			if print then
				print("[ukraine-ai] error: " .. tostring(err))
			end
			Media.Debug("ukraine-ai: " .. tostring(err))
		end

		return ok, err
	end

	f(...)
	return true
end

local function Dist2(ax, ay, bx, by)
	local dx, dy = ax - bx, ay - by
	return dx * dx + dy * dy
end

local function Alive(a)
	return a ~= nil and not a.IsDead and a.IsInWorld
end

local function Round(v)
	return math.floor(v + 0.5)
end

-- the point `dist` cells from (x, y) towards (tx, ty) (or past it)
local function StepToward(x, y, tx, ty, dist)
	local dx, dy = tx - x, ty - y
	local len = math.sqrt(dx * dx + dy * dy)
	if len < 0.001 then
		return x, y
	end

	return x + dx / len * dist, y + dy / len * dist
end

-- cloaked (submerged, stealth, under the Pokrova field): cannot be ordered as a
-- target; once a TB2 reveals it, the units around fire at it by themselves
local function Hidden(a)
	return a.HasProperty("IsCloaked") and a.IsCloaked
end

local function Pct(a)
	return a.Health * 100 / math.max(1, a.MaxHealth)
end

-- ---------------------------------------------------------------------------
-- Map analysis: land, landing craft and deep water regions, coast cells

local MinX, MinY, MaxX, MaxY, MapW, MapH
local Terrain = { }
local LandRegion, CraftRegion, DeepRegion = { }, { }, { }
local Coast = { }          -- ["land:craft"] = { pairs of { land index, craft index, beach } }
local CoarseLand = { }     -- [land region] = coarse grid passability (route planner)

local function CellIndex(x, y)
	return (y - MinY) * MapW + (x - MinX) + 1
end

local function InMap(x, y)
	return x >= MinX and x <= MaxX and y >= MinY and y <= MaxY
end

local function IndexXY(i)
	i = i - 1
	return MinX + i % MapW, MinY + math.floor(i / MapW)
end

local Around = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }

local function Label(passable)
	local region = { }
	local count = 0
	for y = MinY, MaxY do
		for x = MinX, MaxX do
			local i = CellIndex(x, y)
			if passable[Terrain[i]] and not region[i] then
				count = count + 1
				region[i] = count
				local stack, top = { i }, 1
				while top > 0 do
					local c = stack[top]
					stack[top] = nil
					top = top - 1
					local cx, cy = IndexXY(c)
					for k = 1, 8 do
						local nx, ny = cx + Around[k][1], cy + Around[k][2]
						if InMap(nx, ny) then
							local n = CellIndex(nx, ny)
							if not region[n] and passable[Terrain[n]] then
								region[n] = count
								top = top + 1
								stack[top] = n
							end
						end
					end
				end
			end
		end
	end

	return region
end

local function AnalyseMap()
	local topLeft, bottomRight = Map.TopLeft, Map.BottomRight
	MinX = math.floor(topLeft.X / 1024)
	MinY = math.floor(topLeft.Y / 1024)
	MaxX = math.floor(bottomRight.X / 1024) - 1
	MaxY = math.floor(bottomRight.Y / 1024) - 1
	MapW, MapH = MaxX - MinX + 1, MaxY - MinY + 1

	for y = MinY, MaxY do
		for x = MinX, MaxX do
			Terrain[CellIndex(x, y)] = Map.TerrainType(CPos.New(x, y))
		end
	end

	LandRegion = Label(LandTerrain)
	CraftRegion = Label(CraftTerrain)
	DeepRegion = Label(DeepTerrain)

	-- coast: land cells a landing craft can unload onto; a beach cell is one
	-- the craft drives onto, other land cells need a water cell next to them
	for y = MinY, MaxY do
		for x = MinX, MaxX do
			local i = CellIndex(x, y)
			local land = LandRegion[i]
			if land then
				if Terrain[i] == "Beach" and CraftRegion[i] then
					local key = land .. ":" .. CraftRegion[i]
					Coast[key] = Coast[key] or { }
					table.insert(Coast[key], { i, i, true })
				else
					for k = 1, 8 do
						local nx, ny = x + Around[k][1], y + Around[k][2]
						if InMap(nx, ny) then
							local n = CellIndex(nx, ny)
							if Terrain[n] == "Water" and CraftRegion[n] then
								local key = land .. ":" .. CraftRegion[n]
								Coast[key] = Coast[key] or { }
								table.insert(Coast[key], { i, n, false })
								break
							end
						end
					end
				end
			end
		end
	end
end

local function RegionAt(regions, x, y)
	x, y = Round(x), Round(y)
	if not InMap(x, y) then
		return nil
	end

	return regions[CellIndex(x, y)]
end

-- nearest cell of the given region around (x, y), searching `radius` cells
local function SnapTo(regions, region, x, y, radius)
	x, y = Round(x), Round(y)
	if RegionAt(regions, x, y) == region then
		return CPos.New(x, y)
	end

	for r = 1, radius do
		for dy = -r, r do
			for dx = -r, r do
				if math.abs(dx) == r or math.abs(dy) == r then
					if RegionAt(regions, x + dx, y + dy) == region then
						return CPos.New(x + dx, y + dy)
					end
				end
			end
		end
	end

	return nil
end

-- ---------------------------------------------------------------------------
-- World snapshot (shared by all bots, refreshed every ScanInterval)

local Players = { }       -- all combatant players
local World = { }         -- [internal name] = categorised actors of that player
local TypeInfo = { }

local function Info(a)
	local t = a.Type
	local info = TypeInfo[t]
	if info then
		return info
	end

	info = { type = t }
	local ok, cost = true, 0
	if pcall then
		ok, cost = pcall(Actor.Cost, t)
	else
		cost = Actor.Cost(t)
	end

	info.cost = (ok and type(cost) == "number") and cost or 0
	info.building = a.HasProperty("StartBuildingRepairs")
	info.aircraft = a.HasProperty("ReturnToBase")
	info.mobile = a.HasProperty("Scatter")
	info.armed = a.HasProperty("Attack")
	info.naval = NavalTypes[t] or false
	info.infantry = InfantryTypes[t] or false
	info.wall = WallTypes[t] or false
	info.aa = AntiAir[t]
	info.defence = GroundDefence[t]
	info.stealth = StealthTypes[t] or false
	info.ground = info.mobile and not info.naval and not info.aircraft
	TypeInfo[t] = info
	return info
end

-- coarse "seen" grid: 4x4 cell blocks a player's units and buildings see
local SeenBlock = 4

local function MarkSeen(seen, x, y, r)
	local bx0, by0 = math.floor((x - r - MinX) / SeenBlock), math.floor((y - r - MinY) / SeenBlock)
	local bx1, by1 = math.floor((x + r - MinX) / SeenBlock), math.floor((y + r - MinY) / SeenBlock)
	for by = by0, by1 do
		for bx = bx0, bx1 do
			seen[by * 1000 + bx] = true
		end
	end
end

local function ScanPlayer(p)
	local d =
	{
		player = p, name = p.InternalName, buildings = { }, defences = { }, aa = { }, ground = { },
		ships = { }, air = { }, stealth = { }, units = { }, seen = { }, points = { }
	}

	for _, a in ipairs(p.GetActors()) do
		local info = Info(a)
		if info.building or info.mobile or info.aircraft or info.stealth then
			local loc = a.Location
			local x, y = loc.X, loc.Y
			local e = { actor = a, x = x, y = y, info = info }
			if not info.building and not info.mobile and not info.aircraft then
				-- mines: only of interest to the TB2 spotters
				table.insert(d.stealth, e)
			elseif info.building then
				if not info.wall then
					table.insert(d.buildings, e)
					table.insert(d.points, e)
					MarkSeen(d.seen, x + 1, y + 1, 6)
				end

				if info.defence then
					table.insert(d.defences, { x = x, y = y, r = info.defence })
				end

				if info.aa then
					table.insert(d.aa, { x = x, y = y, r = info.aa })
				end
			elseif info.aircraft then
				local airborne = a.CenterPosition.Z > 256
				if airborne then
					table.insert(d.air, e)
					if info.aa then
						table.insert(d.aa, { x = x, y = y, r = info.aa })
					end
				end

				table.insert(d.units, e)
				MarkSeen(d.seen, x, y, info.type == "tb2" and 13 or 6)
			else
				table.insert(d.units, e)
				table.insert(d.points, e)
				MarkSeen(d.seen, x, y, 5)
				if info.naval then
					table.insert(d.ships, e)
				elseif info.ground then
					table.insert(d.ground, e)
				end

				if info.aa then
					table.insert(d.aa, { x = x, y = y, r = info.aa })
				end
			end

			if info.stealth and (info.building or info.mobile or info.aircraft) then
				table.insert(d.stealth, e)
			end
		end
	end

	return d
end

local function ScanWorld()
	World = { }
	for _, p in ipairs(Players) do
		World[p.InternalName] = ScanPlayer(p)
	end
end

-- the teams are fixed for the whole game: bot.enemies / bot.friends (internal
-- names) are worked out once, in NewBot
local function Each(names, field, f)
	for _, name in ipairs(names) do
		local d = World[name]
		if d then
			for _, e in ipairs(d[field]) do
				if f(e, d) then
					return
				end
			end
		end
	end
end

-- calls f(entry, playerData) for every entry of list `field` of the bot's
-- enemies; f returns true to stop
local function EachEnemy(bot, field, f)
	Each(bot.enemies, field, f)
end

-- the bot and its allies (they share vision)
local function EachFriend(bot, field, f)
	Each(bot.friends, field, f)
end

local function Seen(bot, x, y)
	local key = math.floor((y - MinY) / SeenBlock) * 1000 + math.floor((x - MinX) / SeenBlock)
	for _, name in ipairs(bot.friends) do
		local d = World[name]
		if d and d.seen[key] then
			return true
		end
	end

	return false
end

-- number of enemy air defences that reach (x, y), with `margin` cells to spare
local function AAThreat(bot, x, y, margin)
	local n = 0
	EachEnemy(bot, "aa", function(e)
		local r = e.r + margin
		if Dist2(x, y, e.x, e.y) <= r * r then
			n = n + 1
		end
	end)
	return n
end

local function DefenceThreat(bot, x, y, margin)
	local n = 0
	EachEnemy(bot, "defences", function(e)
		local r = e.r + margin
		if Dist2(x, y, e.x + 0.5, e.y + 0.5) <= r * r then
			n = n + 1
		end
	end)
	return n
end

-- air defence along the straight flight from (x0, y0) to (x1, y1)
local function AALine(bot, x0, y0, x1, y1, margin)
	local len = math.sqrt(Dist2(x0, y0, x1, y1))
	local steps = math.max(1, math.floor(len / 2))
	local worst = 0
	for k = 0, steps do
		local t = k / steps
		local n = AAThreat(bot, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, margin)
		if n > worst then
			worst = n
		end
	end

	return worst
end

-- step back from (x, y) towards (hx, hy) until no base defence reaches it
local function OutOfDefences(bot, x, y, hx, hy, margin)
	for _ = 1, 30 do
		if DefenceThreat(bot, x, y, margin) == 0 then
			break
		end

		x, y = StepToward(x, y, hx, hy, 1)
	end

	return x, y
end

local function OutOfAA(bot, x, y, hx, hy, margin)
	for _ = 1, 40 do
		if AAThreat(bot, x, y, margin) == 0 then
			break
		end

		x, y = StepToward(x, y, hx, hy, 1)
	end

	return x, y
end

-- ---------------------------------------------------------------------------
-- Route planner: A* on a 2x2-cell grid of one land region; base defences
-- make the cells they reach expensive, so routes go around them.

local Coarse = 2

local function CoarseGrid(region)
	local grid = CoarseLand[region]
	if grid then
		return grid
	end

	grid = { w = math.floor((MapW + Coarse - 1) / Coarse), h = math.floor((MapH + Coarse - 1) / Coarse) }
	for y = MinY, MaxY do
		for x = MinX, MaxX do
			if LandRegion[CellIndex(x, y)] == region then
				local n = math.floor((y - MinY) / Coarse) * grid.w + math.floor((x - MinX) / Coarse) + 1
				grid[n] = true
			end
		end
	end

	CoarseLand[region] = grid
	return grid
end

local function HeapPush(heap, node, f)
	local n = #heap + 1
	heap[n] = { node, f }
	while n > 1 do
		local parent = math.floor(n / 2)
		if heap[parent][2] <= heap[n][2] then
			break
		end

		heap[parent], heap[n] = heap[n], heap[parent]
		n = parent
	end
end

local function HeapPop(heap)
	local top = heap[1]
	local last = heap[#heap]
	heap[#heap] = nil
	if #heap > 0 then
		heap[1] = last
		local n = 1
		while true do
			local l, r = n * 2, n * 2 + 1
			local m = n
			if heap[l] and heap[l][2] < heap[m][2] then
				m = l
			end

			if heap[r] and heap[r][2] < heap[m][2] then
				m = r
			end

			if m == n then
				break
			end

			heap[m], heap[n] = heap[n], heap[m]
			n = m
		end
	end

	return top
end

-- waypoints (CPos, every ~6 cells) from `from` to `to` on land region `region`,
-- keeping `margin` cells away from the reach of enemy base defences where it can
local function PlanRoute(bot, from, to, region, margin)
	local grid = CoarseGrid(region)
	local w = grid.w
	local function Node(x, y)
		return math.floor((y - MinY) / Coarse) * w + math.floor((x - MinX) / Coarse) + 1
	end

	local function NodeXY(n)
		n = n - 1
		return MinX + (n % w) * Coarse + 0.5, MinY + math.floor(n / w) * Coarse + 0.5
	end

	-- extra cost of the nodes base defences reach
	local cost = { }
	EachEnemy(bot, "defences", function(e)
		local r = e.r + margin
		local rr = math.ceil(r / Coarse) + 1
		local cn = Node(e.x, e.y)
		local cx, cy = NodeXY(cn)
		for dy = -rr, rr do
			for dx = -rr, rr do
				local x, y = cx + dx * Coarse, cy + dy * Coarse
				if InMap(math.floor(x), math.floor(y)) and Dist2(x, y, e.x + 0.5, e.y + 0.5) <= r * r then
					local n = Node(x, y)
					cost[n] = (cost[n] or 0) + 25
				end
			end
		end
	end)

	local start, goal = Node(from.X, from.Y), Node(to.X, to.Y)
	local gx, gy = NodeXY(goal)
	local g, came, closed = { [start] = 0 }, { }, { }
	local heap = { }
	HeapPush(heap, start, 0)
	local expanded = 0
	while #heap > 0 and expanded < 5000 do
		local cur = HeapPop(heap)[1]
		if cur == goal then
			break
		end

		if not closed[cur] then
			closed[cur] = true
			expanded = expanded + 1
			local cx, cy = NodeXY(cur)
			for k = 1, 8 do
				local nx, ny = cx + Around[k][1] * Coarse, cy + Around[k][2] * Coarse
				if InMap(math.floor(nx), math.floor(ny)) then
					local n = Node(nx, ny)
					if (grid[n] or n == goal) and not closed[n] then
						local step = (k <= 4) and 1 or 1.414
						local ng = g[cur] + step * (1 + (cost[n] or 0))
						if not g[n] or ng < g[n] then
							g[n] = ng
							came[n] = cur
							local hx, hy = math.abs(nx - gx) / Coarse, math.abs(ny - gy) / Coarse
							HeapPush(heap, n, ng + math.max(hx, hy) + 0.414 * math.min(hx, hy))
						end
					end
				end
			end
		end
	end

	if not came[goal] and start ~= goal then
		return nil
	end

	local nodes = { }
	local n = goal
	while n do
		table.insert(nodes, 1, n)
		n = came[n]
	end

	local route = { }
	for k = 4, #nodes - 1, 3 do
		local x, y = NodeXY(nodes[k])
		local c = SnapTo(LandRegion, region, x, y, 2)
		if c then
			table.insert(route, c)
		end
	end

	table.insert(route, to)
	return route
end

-- ---------------------------------------------------------------------------
-- Bots

local Bots = { }

local function Base(bot)
	return bot.baseX or bot.home.X, bot.baseY or bot.home.Y
end

-- enemy buildings the bot knows about: seen by it or an ally, or standing
-- around an enemy start location (the start locations are public)
local function Known(bot, e, d)
	if Seen(bot, e.x, e.y) then
		return true
	end

	local h = d.player.HomeLocation
	return Dist2(e.x, e.y, h.X, h.Y) <= 14 * 14
end

local function Register(bot)
	local tag = "uaai:" .. bot.name
	local own = World[bot.name]
	if not own then
		return
	end

	for _, list in ipairs({ own.units, own.buildings }) do
		for _, e in ipairs(list) do
			local kind = Kinds[e.info.type]
			if kind and not e.actor.HasTag(tag) then
				e.actor.AddTag(tag)
				local r = { actor = e.actor, kind = kind, since = tick }
				table.insert(bot.units[kind], r)
				-- no chasing on their own: TB2s and artillery only fire at what
				-- is in range, a Lyutyi only dives on the target it is sent to
				local stance = (kind == "tb2" or kind == "arty" or kind == "ratel") and "Defend"
					or (kind == "lyutyi" and "HoldFire") or nil
				if stance and e.actor.Stance ~= nil then
					Try(function() e.actor.Stance = stance end)
				end

				Log(bot.name .. " takes over " .. e.info.type)
			end
		end
	end
end

local function Prune(bot)
	for _, list in pairs(bot.units) do
		for k = #list, 1, -1 do
			local a = list[k].actor
			if a.IsDead or a.Owner.InternalName ~= bot.name then
				table.remove(list, k)
			end
		end
	end
end

-- where the army attacks by land, the base, the staging point of the APCs,
-- the front line, and whether the enemy can only be reached over water
local function UpdateTargets(bot)
	local own = World[bot.name]
	local bx, by
	for _, e in ipairs(own.buildings) do
		if ConstructionYardTypes[e.info.type] then
			bx, by = e.x + 1, e.y + 1
			break
		end
	end

	if not bx and #own.buildings > 0 then
		bx, by = own.buildings[1].x, own.buildings[1].y
	end

	bot.baseX, bot.baseY = bx or bot.home.X, by or bot.home.Y
	bot.homeLand = RegionAt(LandRegion, bot.baseX, bot.baseY) or bot.homeLand
	bx, by = bot.baseX, bot.baseY

	-- land target: the nearest known enemy building on our land
	local best, bestD, anyEnemy = nil, nil, false
	local over, overD = nil, nil
	EachEnemy(bot, "buildings", function(e, d)
		anyEnemy = true
		local land = RegionAt(LandRegion, e.x, e.y)
		local dd = Dist2(e.x, e.y, bx, by)
		if land == bot.homeLand then
			if Known(bot, e, d) and (not bestD or dd < bestD) then
				best, bestD = e, dd
			end
		elseif land and (not overD or dd < overD) then
			over, overD = e, dd
		end
	end)

	if best then
		bot.target = { x = best.x, y = best.y }
		bot.island = false
	else
		bot.target = nil
		-- nothing reachable by land, though enemies have buildings elsewhere
		if over and anyEnemy then
			local reachable = false
			EachEnemy(bot, "ground", function(e)
				if RegionAt(LandRegion, e.x, e.y) == bot.homeLand then
					reachable = true
					return true
				end
			end)
			bot.island = true
			bot.overTarget = { x = over.x, y = over.y, land = RegionAt(LandRegion, over.x, over.y) }
			if reachable then
				Log(bot.name .. ": enemy units on our land, but no buildings")
			end
		else
			bot.island = false
		end
	end

	-- attack on the base: the enemy ground unit closest to the base centre that
	-- is within 18 cells of it or 8 cells of one of our buildings
	bot.threat = nil
	local threatD
	EachEnemy(bot, "ground", function(e)
		local d = Dist2(e.x, e.y, bx, by)
		if d > 45 * 45 or RegionAt(LandRegion, e.x, e.y) ~= bot.homeLand then
			return
		end

		local near = d <= 18 * 18
		if not near then
			for _, b in ipairs(own.buildings) do
				if Dist2(e.x, e.y, b.x + 1, b.y + 1) <= 8 * 8 then
					near = true
					break
				end
			end
		end

		if near and (not threatD or d < threatD) then
			bot.threat, threatD = { x = e.x, y = e.y }, d
		end
	end)

	-- staging point of the APCs: next to the barracks, towards the target
	local sx, sy
	for _, e in ipairs(own.buildings) do
		if BarracksTypes[e.info.type] then
			sx, sy = e.x + 1, e.y + 2
			break
		end
	end

	sx, sy = sx or bx, sy or by
	local t = bot.target
	if t then
		sx, sy = StepToward(sx, sy, t.x, t.y, 3)
	end

	bot.stage = SnapTo(LandRegion, bot.homeLand, sx, sy, 5)

	-- front line: the leading unit of the main body of the army out in the
	-- field (the biggest group, not a raid or an air assault deep inside the
	-- enemy base), if enough of the army is out
	bot.front = nil
	if t then
		local field = { }
		for _, e in ipairs(own.ground) do
			if not NotArmyTypes[e.info.type] and e.info.armed and Dist2(e.x, e.y, bx, by) > 14 * 14 then
				table.insert(field, e)
			end
		end

		if #field >= 3 then
			local seed, seedN = nil, -1
			for _, e in ipairs(field) do
				local n = 0
				for _, o in ipairs(field) do
					if Dist2(e.x, e.y, o.x, o.y) <= 8 * 8 then
						n = n + 1
					end
				end

				if n > seedN then
					seed, seedN = e, n
				end
			end

			local lead, leadD
			for _, e in ipairs(field) do
				if Dist2(e.x, e.y, seed.x, seed.y) <= 10 * 10 then
					local dd = Dist2(e.x, e.y, t.x, t.y)
					if not leadD or dd < leadD then
						lead, leadD = e, dd
					end
				end
			end

			if seedN >= 3 and leadD < Dist2(bx, by, t.x, t.y) then
				bot.front = { x = lead.x, y = lead.y }
			end
		end
	end

	-- naval yard and its water
	bot.yardCraft, bot.yardDeep = nil, nil
	for _, e in ipairs(own.buildings) do
		if NavalYardTypes[e.info.type] then
			for dy = 0, 3 do
				for dx = 0, 3 do
					bot.yardCraft = bot.yardCraft or RegionAt(CraftRegion, e.x + dx, e.y + dy)
					bot.yardDeep = bot.yardDeep or RegionAt(DeepRegion, e.x + dx, e.y + dy)
				end
			end

			bot.yardX, bot.yardY = e.x + 1, e.y + 1
			if bot.yardCraft then
				break
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- APC / BTR-4: armoured infantry carriers in the fight
--
--   home      at the barracks, the riflemen around get in; the carrier waits
--             there (loaded) until there is a fight to take them to
--   move      with the troops aboard towards the fight: an attack on the base
--             (bot.threat), the army in the field (bot.front), or, after a
--             landing craft brought it to another shore, the enemy base there
--   deployed  enemy troops within 7 cells or any enemy building within 9:
--             everybody out, the riflemen fight and the carrier stays right
--             behind them; when the fight is over and the next target is
--             close, the riflemen walk on
--   reload    the next target is far (or there is none): the carrier drives
--             up to its riflemen wherever they are, they get back in, and it
--             goes on to the next fight or back to the barracks
--   return    back to the barracks when there is nothing to do

-- the nearest enemy around (x, y): a ground unit within `radius` cells, or
-- any enemy building (base, outpost, defence - not walls) within
-- `buildingRadius` cells (default: radius + 2), measured to its centre
local function NearestEnemy(bot, x, y, radius, buildingRadius)
	local best, bestD
	local function Check(e, cx, cy, r)
		local d = Dist2(x, y, cx, cy)
		if d <= r * r and (not bestD or d < bestD) and Alive(e.actor) and not Hidden(e.actor) then
			best, bestD = e, d
		end
	end

	EachEnemy(bot, "ground", function(e)
		Check(e, e.x, e.y, radius)
	end)
	local br = buildingRadius or (radius + 2)
	EachEnemy(bot, "buildings", function(e)
		Check(e, e.x + 1, e.y + 1, br)
	end)
	return best
end

local function ReleaseBoarding(r)
	for _, e in ipairs(r.boarding or { }) do
		if not e.IsDead then
			e.RemoveTag("uaai-board")
		end
	end

	r.boarding = { }
end

-- order idle units around (x, y) into the transport
local function CallAboard(bot, r, x, y, radius, accept, capacity)
	local a = r.actor
	r.boarding = r.boarding or { }
	-- forget the ones that got in, died or were sent elsewhere
	for k = #r.boarding, 1, -1 do
		local e = r.boarding[k]
		if e.IsDead or not e.IsInWorld then
			table.remove(r.boarding, k)
		elseif e.IsIdle then
			e.RemoveTag("uaai-board")
			table.remove(r.boarding, k)
		end
	end

	local want = capacity - a.PassengerCount - #r.boarding
	if want <= 0 then
		return
	end

	local own = World[bot.name]
	for _, e in ipairs(own.ground) do
		if want <= 0 then
			break
		end

		local u = e.actor
		if accept(e) and Dist2(e.x, e.y, x, y) <= radius * radius and Alive(u) and u.IsIdle and not u.HasTag("uaai-board") then
			u.AddTag("uaai-board")
			u.EnterTransport(a)
			table.insert(r.boarding, u)
			want = want - 1
		end
	end
end

-- passengers that leave a transport attack-move to its goal; for an APC they
-- also become its squad (the riflemen it picks up again after the fight)
local function OnUnloaded(r)
	return function(transport, passenger)
		local goal = r.goal
		if r.squad then
			table.insert(r.squad, passenger)
		end

		-- the trigger fires before the passenger is back in the world: give the
		-- order a few ticks later
		Trigger.AfterDelay(5, function()
			Try(function()
				if passenger.IsDead then
					return
				end

				passenger.RemoveTag("uaai-board")
				if goal and passenger.IsInWorld and passenger.HasProperty("AttackMove") then
					passenger.AttackMove(goal, 2)
				end
			end)
		end)
	end
end

local function Rifleman(e)
	return RiflemenTypes[e.info.type]
end

-- the squad of an APC still out there: centre and size
local function Squad(r)
	local sx, sy, n = 0, 0, 0
	for k = #r.squad, 1, -1 do
		local u = r.squad[k]
		if u.IsDead or not u.IsInWorld then
			table.remove(r.squad, k)
		else
			local l = u.Location
			sx, sy, n = sx + l.X, sy + l.Y, n + 1
		end
	end

	if n == 0 then
		return nil, nil, 0
	end

	return sx / n, sy / n, n
end

-- where an APC at (x, y) is needed: defence of the base first, then the
-- enemy base of a foreign shore it was landed on, then the army in the field
local function APCTask(bot, x, y)
	local region = RegionAt(LandRegion, x, y)
	if region and region == bot.homeLand then
		if bot.threat then
			return bot.threat.x, bot.threat.y, "defend"
		end

		if bot.front then
			return bot.front.x, bot.front.y, "attack"
		end

		return nil
	end

	if region then
		local best, bestD
		EachEnemy(bot, "buildings", function(e)
			if RegionAt(LandRegion, e.x, e.y) == region then
				local d = Dist2(x, y, e.x, e.y)
				if not bestD or d < bestD then
					best, bestD = e, d
				end
			end
		end)

		if best then
			return best.x, best.y, "assault"
		end
	end

	return nil
end

-- contact distances: the troops get out when an enemy unit is this close, or
-- an enemy building (any: a base, an outpost, a lone power plant)
local ContactUnits, ContactBuildings = 7, 9
-- after a fight the riflemen walk to a next target closer than this; for a
-- target further away the carrier picks them up and drives them there
local WalkDistance = 12

local function HandleAPC(bot, r)
	local a = r.actor
	-- inside a landing craft or on the way into one: the landing craft leads
	if not a.IsInWorld or a.HasTag("uaai-board") then
		return
	end

	if not r.state then
		r.state, r.since, r.squad = "home", tick, { }
		Trigger.OnPassengerExited(a, OnUnloaded(r))
	end

	local loc = a.Location
	local region = RegionAt(LandRegion, loc.X, loc.Y)
	local count = a.PassengerCount
	local tx, ty, task = APCTask(bot, loc.X, loc.Y)

	local function Deploy(enemy)
		r.goal = CPos.New(enemy.x, enemy.y)
		r.state, r.since, r.calm = "deployed", tick, 0
		a.Stop()
		a.UnloadPassengers()
		Log(bot.name .. " " .. a.Type .. " unloads " .. count .. " at " .. loc.X .. "," .. loc.Y
			.. " (" .. enemy.info.type .. " at " .. enemy.x .. "," .. enemy.y .. ")")
	end

	local function EndPickup()
		for _, u in ipairs(r.squad) do
			if not u.IsDead then
				u.RemoveTag("uaai-board")
			end
		end

		ReleaseBoarding(r)
		r.squad = { }
		r.pickup = nil
	end

	if r.state == "home" then
		CallAboard(bot, r, loc.X, loc.Y, 12, Rifleman, 5)
		local enough = task == "defend" and 1 or 3
		if task and count >= enough then
			ReleaseBoarding(r)
			r.state, r.since, r.dest = "move", tick, nil
			Log(bot.name .. " " .. a.Type .. " takes " .. count .. " infantry to " .. task .. " at " .. tx .. "," .. ty)
		elseif region == bot.homeLand and bot.stage and a.IsIdle
			and Dist2(loc.X, loc.Y, bot.stage.X, bot.stage.Y) > 16 then
			a.Move(bot.stage, 2)
		end
	end

	if r.state == "move" then
		if not task or count == 0 then
			r.state, r.since = "return", tick
		else
			-- contact with enemy troops, or arrival at enemy buildings: everybody out
			local enemy = NearestEnemy(bot, loc.X, loc.Y, ContactUnits, ContactBuildings)
			if enemy then
				Deploy(enemy)
			else
				-- follow the task; stop a little short of it (behind the army)
				local dx, dy = StepToward(tx, ty, loc.X, loc.Y, task == "attack" and 2 or 3)
				local dest = SnapTo(LandRegion, region, dx, dy, 4)
				if dest and (not r.dest or Dist2(r.dest.X, r.dest.Y, dest.X, dest.Y) > 9
					or (a.IsIdle and Dist2(loc.X, loc.Y, dest.X, dest.Y) > 9)) then
					r.dest = dest
					a.Move(dest, 1)
				end
			end
		end
	elseif r.state == "deployed" then
		if count > 0 and a.IsIdle and tick - r.since > 3 * Second then
			a.UnloadPassengers()
		end

		local cx, cy, n = Squad(r)
		local px, py = cx or loc.X, cy or loc.Y
		local enemy = NearestEnemy(bot, px, py, 9, ContactBuildings + 2)
		if enemy then
			r.calm = 0
			r.goal = CPos.New(enemy.x, enemy.y)
			-- riflemen that are done with their target press on
			for _, u in ipairs(r.squad) do
				if u.IsIdle then
					u.AttackMove(r.goal, 2)
				end
			end
		else
			r.calm = r.calm + 1
		end

		-- the carrier keeps close behind its squad
		if cx and a.IsIdle and Dist2(loc.X, loc.Y, cx, cy) > 25 then
			local bx, by = Base(bot)
			local fx, fy = StepToward(cx, cy, bx, by, 2)
			local dest = SnapTo(LandRegion, region, fx, fy, 3)
			if dest then
				a.Move(dest, 1)
			end
		end

		if n == 0 and count == 0 then
			r.state, r.since = "return", tick
		elseif r.calm >= 3 and count == 0 then
			-- the fight is over: walk to a next target close by, ride further
			if task and cx and Dist2(cx, cy, tx, ty) <= WalkDistance * WalkDistance then
				r.goal = CPos.New(tx, ty)
				for _, u in ipairs(r.squad) do
					if u.IsIdle then
						u.AttackMove(r.goal, 2)
					end
				end
			else
				r.state, r.since, r.pickup = "reload", tick, nil
				Log(bot.name .. " " .. a.Type .. " picks up its squad (" .. n .. ")"
					.. (task and (" for " .. task .. " at " .. tx .. "," .. ty) or ", back to base"))
			end
		end
	elseif r.state == "reload" then
		local cx, cy, n = Squad(r)
		local enemy = NearestEnemy(bot, cx or loc.X, cy or loc.Y, ContactUnits, ContactBuildings)
		if enemy then
			-- attacked while picking up: out again
			EndPickup()
			if a.PassengerCount > 0 then
				Deploy(enemy)
			else
				r.state, r.since, r.calm = "deployed", tick, 0
			end

			return
		end

		if cx then
			-- the riflemen are far from the carrier: it drives up to them
			if Dist2(loc.X, loc.Y, cx, cy) > 16 then
				local spot = SnapTo(LandRegion, region, cx, cy, 3)
				if spot and (not r.pickup or Dist2(r.pickup.X, r.pickup.Y, spot.X, spot.Y) > 9 or a.IsIdle) then
					r.pickup = spot
					a.Move(spot, 1)
				end
			end

			-- the squad gets in once the carrier is close (again every 5
			-- seconds, for the ones another order took away)
			local again = (tick - r.since) % (5 * Second) < UpdateInterval
			for _, u in ipairs(r.squad) do
				local l = u.Location
				if Dist2(l.X, l.Y, loc.X, loc.Y) <= 10 * 10 and (not u.HasTag("uaai-board") or again) then
					u.AddTag("uaai-board")
					u.EnterTransport(a)
				end
			end
		end

		-- a few more riflemen standing around
		if a.PassengerCount + n < 5 then
			CallAboard(bot, r, loc.X, loc.Y, 6, Rifleman, 5 - n)
		end

		if (n == 0 and tick - r.since > 2 * Second) or a.PassengerCount >= 5 or tick - r.since > 40 * Second then
			EndPickup()
			r.state, r.since, r.dest = (task and a.PassengerCount > 0) and "move" or "return", tick, nil
		end
	elseif r.state == "return" then
		if region ~= bot.homeLand or not bot.stage then
			-- on a foreign shore: hold here and wait for the next fight
			r.state, r.since = "home", tick
		elseif task and count >= 1 then
			r.state, r.since, r.dest = "move", tick, nil
		else
			if a.IsIdle and Dist2(loc.X, loc.Y, bot.stage.X, bot.stage.Y) > 16 then
				a.Move(bot.stage, 2)
			end

			if Dist2(loc.X, loc.Y, bot.stage.X, bot.stage.Y) <= 16 or (a.IsIdle and tick - r.since > 10 * Second) then
				r.state, r.since = "home", tick
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Landing craft: troops across the water when the enemy cannot be reached by land

local function CoastList(land, craft)
	return Coast[land .. ":" .. craft]
end

-- embarkation point on our shore: the coast cell nearest to the base, a beach if possible
local function Embarkation(bot)
	local list = bot.homeLand and bot.yardCraft and CoastList(bot.homeLand, bot.yardCraft)
	if not list then
		return nil
	end

	local bx, by = Base(bot)
	local best, bestScore
	for _, c in ipairs(list) do
		local x, y = IndexXY(c[1])
		local score = math.sqrt(Dist2(x, y, bx, by)) + (c[3] and 0 or 4)
		if not bestScore or score < bestScore then
			best, bestScore = c, score
		end
	end

	return best
end

-- landing beach: ~10 cells from the target, out of reach of the base
-- defences; `avoid` (a CPos) is a spot where the landing failed
local function Landing(bot, craft, avoid)
	local t = bot.overTarget
	local list = t and t.land and CoastList(t.land, craft)
	if not list then
		return nil
	end

	local best, bestScore
	local step = math.max(1, math.floor(#list / 400))
	for k = 1, #list, step do
		local c = list[k]
		local x, y = IndexXY(c[1])
		local d = math.sqrt(Dist2(x, y, t.x, t.y))
		local score = math.abs(d - 10) + 8 * DefenceThreat(bot, x, y, 3) + (c[3] and 0 or 3)
		if avoid and Dist2(x, y, avoid.X, avoid.Y) <= 9 then
			score = score + 30
		end
		if not bestScore or score < bestScore then
			best, bestScore = c, score
		end
	end

	return best
end

local APCTypes = Set { "apc", "btr4" }

-- what a landing craft takes across: fighting ground units, and APCs waiting
-- loaded at the base (they land with their infantry aboard)
local function CargoUnit(e)
	local t = e.info.type
	if APCTypes[t] then
		return e.actor.IsIdle and e.actor.PassengerCount >= 3
	end

	return e.info.ground and e.info.armed and not NotCargoTypes[t] and not Kinds[t]
end

local function HandleLST(bot, r)
	local a = r.actor
	if not a.IsInWorld then
		return
	end

	if not r.state then
		r.state, r.since = "dock", tick
		Trigger.OnPassengerExited(a, OnUnloaded(r))
	end

	local loc = a.Location
	if r.state == "dock" then
		if not bot.island then
			return
		end

		local emb = Embarkation(bot)
		if not emb then
			return
		end

		local ex, ey = IndexXY(emb[2])
		if Dist2(loc.X, loc.Y, ex, ey) > 4 then
			if a.IsIdle then
				a.Move(CPos.New(ex, ey), 1)
			end

			r.since = tick
			return
		end

		local lx, ly = IndexXY(emb[1])
		CallAboard(bot, r, lx, ly, 26, CargoUnit, 5)
		local count, waited = a.PassengerCount, tick - r.since
		if count >= 5 or (count >= 3 and waited > 40 * Second) or (count >= 1 and waited > 90 * Second) then
			local land = Landing(bot, RegionAt(CraftRegion, loc.X, loc.Y) or bot.yardCraft)
			if land then
				local x, y = IndexXY(land[2])
				ReleaseBoarding(r)
				r.drop = CPos.New(x, y)
				r.goal = CPos.New(bot.overTarget.x, bot.overTarget.y)
				r.state, r.since, r.tries, r.landings = "sail", tick, 0, 0
				a.Stop()
				a.Move(r.drop)
				Log(bot.name .. " landing craft sails with " .. count .. " units to " .. x .. "," .. y)
			end
		end
	elseif r.state == "sail" then
		-- the troops can only get out onto land next to the craft: it has to be
		-- on the beach cell, or on the water cell right next to the land
		local d2 = Dist2(loc.X, loc.Y, r.drop.X, r.drop.Y)
		if d2 <= 1 or (a.IsIdle and d2 <= 2) or Pct(a) < 35 then
			a.Stop()
			a.UnloadPassengers()
			r.state, r.since = "unload", tick
		elseif a.IsIdle and tick - r.since > 5 * Second then
			r.tries = r.tries + 1
			r.since = tick
			if r.tries > 3 then
				-- cannot get there: try another beach
				local land = Landing(bot, RegionAt(CraftRegion, loc.X, loc.Y) or bot.yardCraft, r.drop)
				if land then
					local x, y = IndexXY(land[2])
					r.drop = CPos.New(x, y)
				end

				r.tries = 0
			end

			a.Move(r.drop)
		end
	elseif r.state == "unload" then
		if a.PassengerCount == 0 then
			r.state, r.since = "dock", tick
			a.Stop()
		elseif a.IsIdle and tick - r.since > 8 * Second then
			-- nobody could get out here (no free land next to the craft): try
			-- another beach close by, a few times, before sailing home
			r.landings = (r.landings or 0) + 1
			local land = r.landings <= 3 and Landing(bot, RegionAt(CraftRegion, loc.X, loc.Y) or bot.yardCraft, r.drop)
			if land then
				local x, y = IndexXY(land[2])
				r.drop = CPos.New(x, y)
				r.state, r.since, r.tries = "sail", tick, 0
				a.Stop()
				a.Move(r.drop)
			else
				r.state, r.since = "dock", tick
				a.Stop()
			end
		elseif a.IsIdle and tick - r.since > 4 * Second then
			a.UnloadPassengers()
		end
	end
end

local function BuildLandingCraft(bot)
	if not bot.island or not bot.yardCraft or not Embarkation(bot) then
		return
	end

	if #bot.units.lst >= 2 or tick - (bot.lstOrdered or -10000) < 20 * Second then
		return
	end

	if bot.player.Build({ "lst" }) then
		bot.lstOrdered = tick
		Log(bot.name .. " builds a landing craft")
	end
end

-- ---------------------------------------------------------------------------
-- Drones for Ukrainian bots: the engine lets a bot build an aircraft only
-- while it has a free airfield for it, so with one airfield the first TB2 or
-- F-16 blocked every further drone. The script keeps a minimum of TB2s (all
-- bots, the rush bot only two) and Lyutyi drones (not the rush bot) by
-- ordering them itself; a Lyutyi is spent in its strike and gets replaced.

local DroneMinimum =
{
	rush = { tb2 = 2 },
	normal = { tb2 = 3, lyutyi = 2 },
	turtle = { tb2 = 3, lyutyi = 2 },
	naval = { tb2 = 4, lyutyi = 2 }
}

-- the bot type, from the bot.* prerequisites of the player (rules/ukraine-ai.yaml)
local function BotType(bot)
	for _, t in ipairs({ "rush", "normal", "turtle", "naval" }) do
		if bot.player.HasPrerequisites({ "bot." .. t }) then
			return t
		end
	end

	return "normal"
end

local function OwnBuildings(bot, kind)
	local n = 0
	for _, e in ipairs(World[bot.name].buildings) do
		if e.info.type == kind then
			n = n + 1
		end
	end

	return n
end

local function BuildDrones(bot)
	if not bot.ukraine or OwnBuildings(bot, "afld.ukraine") == 0 then
		return
	end

	if tick - (bot.droneOrdered or -10000) < 15 * Second then
		return
	end

	local want = DroneMinimum[BotType(bot)]
	local order
	if #bot.units.tb2 < want.tb2 then
		order = "tb2"
	elseif want.lyutyi and #bot.units.lyutyi < want.lyutyi and OwnBuildings(bot, "stek.ukraine") > 0 then
		order = "lyutyi"
	end

	if order and bot.player.Cash + bot.player.Resources >= Actor.Cost(order) and bot.player.Build({ order }) then
		bot.droneOrdered = tick
		Log(bot.name .. " orders a " .. order)
	end
end

-- one line per bot and minute in the "lua" log, to see what the bots have
local function Status(bot)
	if not print then
		return
	end

	local u = bot.units
	print(string.format("[ukraine-ai] %s %s (%s): afld %d, tb2 %d, lyutyi %d, f16 %d, apc %d, lst %d, island %s, target %s, front %s",
		bot.name, bot.player.Faction, BotType(bot), OwnBuildings(bot, "afld.ukraine") + OwnBuildings(bot, "afld"),
		#u.tb2, #u.lyutyi, #u.f16, #u.apc, #u.lst, tostring(bot.island),
		bot.target and (bot.target.x .. "," .. bot.target.y) or "-", bot.front and (bot.front.x .. "," .. bot.front.y) or "-"))
end

-- ---------------------------------------------------------------------------
-- Bayraktar TB2: key points, strikes out of air defence reach, spotting

local function KeyPoints(bot)
	local bx, by = Base(bot)
	local points = { }
	local function Add(x, y)
		x, y = OutOfAA(bot, x, y, bx, by, 2)
		for _, p in ipairs(points) do
			if Dist2(p.x, p.y, x, y) < 36 then
				return
			end
		end

		table.insert(points, { x = x, y = y })
	end

	for _, name in ipairs(bot.enemies) do
		do
			local d = World[name]
			if d and #d.buildings > 0 then
				local ex, ey = d.buildings[1].x, d.buildings[1].y
				for _, e in ipairs(d.buildings) do
					if ConstructionYardTypes[e.info.type] then
						ex, ey = e.x, e.y
						break
					end
				end

				Add(bx + (ex - bx) * 0.45, by + (ey - by) * 0.45)
				Add(bx + (ex - bx) * 0.7, by + (ey - by) * 0.7)
			end
		end
	end

	Add((MinX + MaxX) / 2, (MinY + MaxY) / 2)
	return points
end

-- an enemy stealth unit, mine or submarine next to friendly forces, that a
-- TB2 can reveal without flying into air defence
local function StealthTarget(bot)
	local found
	EachEnemy(bot, "stealth", function(e)
		if e.info.type == "msub" then
			return false  -- carries anti-air missiles
		end

		local near = false
		EachFriend(bot, "points", function(f)
			if Dist2(f.x, f.y, e.x, e.y) <= 12 * 12 then
				near = true
				return true
			end
		end)
		if near and AAThreat(bot, e.x, e.y, 1) == 0 then
			found = e
			return true
		end
	end)
	return found
end

local function HuntTarget(bot, a)
	local loc = a.Location
	local best, bestScore
	local function Consider(e)
		if not e.info.aircraft and Seen(bot, e.x, e.y) and Alive(e.actor) and not Hidden(e.actor) then
			local value = math.max(300, e.info.cost) * (HuntPriority[e.info.type] or 1)
			local d = math.sqrt(Dist2(loc.X, loc.Y, e.x, e.y))
			local score = value / (1 + d / 20)
			if (not bestScore or score > bestScore) and AAThreat(bot, e.x, e.y, 1.5) == 0
				and AALine(bot, loc.X, loc.Y, e.x, e.y, 1) == 0 and a.CanTarget(e.actor) then
				best, bestScore = e, score
			end
		end
	end

	EachEnemy(bot, "ground", function(e)
		if not e.info.infantry then
			Consider(e)
		end
	end)
	EachEnemy(bot, "ships", Consider)
	EachEnemy(bot, "buildings", function(e)
		if e.info.defence then
			Consider(e)
		end
	end)
	return best
end

local function FlyTo(r, x, y)
	local a = r.actor
	x, y = math.max(MinX, math.min(MaxX, Round(x))), math.max(MinY, math.min(MaxY, Round(y)))
	if r.flyX ~= x or r.flyY ~= y or a.IsIdle then
		r.flyX, r.flyY = x, y
		a.Stop()
		a.Move(CPos.New(x, y))
	end
end

local function HandleTB2s(bot)
	local list = bot.units.tb2
	if #list == 0 then
		return
	end

	local bx, by = Base(bot)
	if not bot.keyPoints or tick >= (bot.keyPointsAt or 0) then
		bot.keyPoints = KeyPoints(bot)
		bot.keyPointsAt = tick + KeyPointInterval
	end

	local ready = { }
	for _, r in ipairs(list) do
		local a = r.actor
		if a.IsInWorld then
			local ammo = a.AmmoCount()
			if r.role == "rearm" then
				if ammo >= a.MaximumAmmoCount() and a.IsIdle then
					r.role = nil
				end
			elseif ammo == 0 then
				r.role, r.target = "rearm", nil
				a.Stop()
				a.ReturnToBase()
			end

			if r.role ~= "rearm" then
				local loc = a.Location
				-- never loiter inside air defence reach
				if a.CenterPosition.Z > 256 and AAThreat(bot, loc.X, loc.Y, 0.5) > 0 then
					local x, y = OutOfAA(bot, loc.X, loc.Y, bx, by, 2)
					x, y = StepToward(x, y, bx, by, 2)
					r.target = nil
					r.avoid = tick + 8 * Second
					FlyTo(r, x, y)
				elseif not r.avoid or tick > r.avoid then
					table.insert(ready, r)
				end
			end
		end
	end

	-- 1. one drone over enemy stealth units / submarines / mines near friendly forces
	local spot = StealthTarget(bot)
	if spot then
		local pick, pickD
		for k, r in ipairs(ready) do
			local loc = r.actor.Location
			local d = Dist2(loc.X, loc.Y, spot.x, spot.y) - (r.role == "spot" and 400 or 0)
			if not pickD or d < pickD then
				pick, pickD = k, d
			end
		end

		if pick then
			local r = table.remove(ready, pick)
			if r.role ~= "spot" then
				Log(bot.name .. " TB2 spots " .. spot.info.type .. " at " .. spot.x .. "," .. spot.y)
			end

			r.role, r.target = "spot", nil
			if not r.flyX or Dist2(r.flyX, r.flyY, spot.x, spot.y) > 4 then
				FlyTo(r, spot.x, spot.y)
			end
		end
	end

	-- 2. half of the rest watch key points, the others hunt
	local watchers = math.max(1, math.ceil(#ready / 2))
	for k, r in ipairs(ready) do
		local a = r.actor
		local hunting = false
		if k > watchers then
			if r.role == "hunt" and r.target and not r.target.IsDead then
				hunting = true
				if a.IsIdle then
					a.Attack(r.target)
				end
			else
				local e = HuntTarget(bot, a)
				if e then
					r.role, r.target = "hunt", e.actor
					a.Stop()
					a.Attack(e.actor)
					hunting = true
					Log(bot.name .. " TB2 strikes " .. e.info.type .. " at " .. e.x .. "," .. e.y)
				end
			end
		end

		if not hunting and #bot.keyPoints > 0 then
			local kp = bot.keyPoints[(k - 1) % #bot.keyPoints + 1]
			-- circle between two points across the line between the bases
			local dx, dy = kp.x - bx, kp.y - by
			local len = math.max(1, math.sqrt(dx * dx + dy * dy))
			local px, py = -dy / len * 3, dx / len * 3
			if r.role ~= "watch" or r.kp ~= kp then
				r.role, r.kp, r.side, r.target = "watch", kp, 1, nil
				FlyTo(r, kp.x + px, kp.y + py)
			else
				local loc = a.Location
				if Dist2(loc.X, loc.Y, r.flyX, r.flyY) <= 6 then
					r.side = -r.side
					FlyTo(r, kp.x + px * r.side, kp.y + py * r.side)
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Lyutyi: salvoes against buildings, the least air defence first

local function HandleLyutyi(bot)
	local list = bot.units.lyutyi
	if #list == 0 then
		return
	end

	local ready, assigned = { }, { }
	for _, r in ipairs(list) do
		local a = r.actor
		if r.state == "strike" then
			if r.target.IsDead or (a.IsIdle and tick - r.since > 3 * Second) then
				r.state = nil
			else
				local key = r.tx .. "," .. r.ty
				assigned[key] = (assigned[key] or 0) + 1
			end
		end

		-- on the airfield, or circling after its target was destroyed by others
		if not r.state and a.IsInWorld then
			table.insert(ready, r)
		end
	end

	if #ready == 0 then
		bot.lyutyiWait = nil
		return
	end

	-- salvoes of at least two (air defence cannot stop them all), or one that
	-- has waited half a minute
	bot.lyutyiWait = bot.lyutyiWait or tick
	if #ready < 2 and tick - bot.lyutyiWait < 30 * Second then
		return
	end

	local candidates = { }
	EachEnemy(bot, "buildings", function(e, d)
		if Known(bot, e, d) and Alive(e.actor) then
			table.insert(candidates, e)
		end
	end)
	if #candidates == 0 then
		return
	end

	bot.lyutyiWait = nil
	for _, r in ipairs(ready) do
		local a = r.actor
		local loc = a.Location
		local best, bestScore
		for _, e in ipairs(candidates) do
			local key = e.x .. "," .. e.y
			local needed = math.max(1, math.ceil(e.actor.Health / 100000))
			if (assigned[key] or 0) < needed then
				local value = math.max(200, e.info.cost) * (StrikePriority[e.info.type] or 1)
				local aa = AAThreat(bot, e.x, e.y, 1) + AALine(bot, loc.X, loc.Y, e.x, e.y, 0)
				local score = value / (1 + 1.5 * aa)
				if not bestScore or score > bestScore then
					best, bestScore = e, score
				end
			end
		end

		if best then
			local key = best.x .. "," .. best.y
			assigned[key] = (assigned[key] or 0) + 1
			r.state, r.target, r.tx, r.ty, r.since = "strike", best.actor, best.x, best.y, tick
			a.Attack(best.actor)
			Log(bot.name .. " Lyutyi strikes " .. best.info.type .. " at " .. key)
		end
	end
end

-- ---------------------------------------------------------------------------
-- Ratel S: vehicle hunting around the base and the army, raids around defences

local function NearestEnemyBuilding(bot, a, radius)
	local p = bot.player
	local found = Map.ActorsInCircle(a.CenterPosition, WDist.FromCells(radius), function(x)
		return not x.IsDead and x.HasProperty("StartBuildingRepairs") and not x.Owner.IsNonCombatant
			and not x.Owner.IsAlliedWith(p) and not WallTypes[x.Type]
	end)
	return found[1]
end

-- send the unit along `route` (CPos list) and then run `finish`
local function FollowRoute(a, route, attackMove, finish)
	a.Stop()
	for _, c in ipairs(route) do
		if attackMove then
			a.AttackMove(c, 1)
		else
			a.Move(c, 1)
		end
	end

	a.CallFunc(function()
		Try(finish)
	end)
end

-- the best enemy building on our land for a raid: worth(e, d) gives its value
-- (nil: not a target); defended and far away targets count for less
local function RaidTarget(bot, from, worth)
	local best, bestScore
	EachEnemy(bot, "buildings", function(e, d)
		local value = worth(e, d)
		if value and Known(bot, e, d) and RegionAt(LandRegion, e.x, e.y) == bot.homeLand and Alive(e.actor) then
			local score = value / (1 + 2 * DefenceThreat(bot, e.x, e.y, 0)) / (1 + math.sqrt(Dist2(from.X, from.Y, e.x, e.y)) / 40)
			if not bestScore or score > bestScore then
				best, bestScore = e, score
			end
		end
	end)
	return best
end

local function HandleRatels(bot)
	local list = bot.units.ratel
	if #list == 0 then
		return
	end

	local bx, by = Base(bot)
	local own = World[bot.name]
	local idle = { }
	for _, r in ipairs(list) do
		local a = r.actor
		if r.state and a.IsInWorld and (a.IsIdle and tick - r.since > 5 * Second or (r.target and r.target.IsDead)) then
			r.state, r.target = nil, nil
		end

		if not r.state and a.IsInWorld then
			table.insert(idle, r)
		end
	end

	-- 1. enemy vehicles near the base or our troops
	EachEnemy(bot, "ground", function(e)
		if #idle == 0 then
			return true
		end

		if e.info.infantry or e.info.aircraft or not Alive(e.actor) or Hidden(e.actor) then
			return false
		end

		local near = Dist2(e.x, e.y, bx, by) <= 14 * 14
		if not near then
			for _, o in ipairs(own.ground) do
				if Dist2(o.x, o.y, e.x, e.y) <= 8 * 8 then
					near = true
					break
				end
			end
		end

		if near then
			local pick, pickD
			for k, r in ipairs(idle) do
				local loc = r.actor.Location
				local d = Dist2(loc.X, loc.Y, e.x, e.y)
				if d <= 20 * 20 and (not pickD or d < pickD) and r.actor.CanTarget(e.actor) then
					pick, pickD = k, d
				end
			end

			if pick then
				local r = table.remove(idle, pick)
				r.state, r.target, r.since = "intercept", e.actor, tick
				r.actor.Attack(e.actor)
				Log(bot.name .. " Ratel intercepts " .. e.info.type)
			end
		end
	end)

	-- 2. raids on buildings around the defences: two together, one stays home
	local keep = #list >= 3 and 1 or 0
	if #idle - keep < 2 and not (#idle - keep >= 1 and tick - (bot.ratelWait or tick) > 60 * Second) then
		bot.ratelWait = bot.ratelWait or tick
		return
	end

	bot.ratelWait = nil
	local from = idle[1].actor.Location
	-- anything but defences and silos: production, power, refineries, tech
	local target = RaidTarget(bot, from, function(e)
		if e.info.defence or e.info.type == "silo" then
			return nil
		end

		return math.max(200, e.info.cost) * (StrikePriority[e.info.type] or 1)
	end)
	if not target then
		return
	end

	local route = PlanRoute(bot, from, CPos.New(target.x, target.y), bot.homeLand, 3)
	if not route then
		return
	end

	for k = 1, #idle - keep do
		local r = idle[k]
		local a = r.actor
		local goal = target.actor
		r.state, r.target, r.since = "raid", nil, tick
		FollowRoute(a, route, false, function()
			if a.IsDead then
				return
			end

			local t = goal
			if t.IsDead then
				t = NearestEnemyBuilding(bot, a, 8)
			end

			if t then
				a.Attack(t)
			end
		end)
	end

	Log(bot.name .. " Ratel raid on " .. target.info.type .. " at " .. target.x .. "," .. target.y .. " (" .. #route .. " waypoints)")
end

-- ---------------------------------------------------------------------------
-- Sea Baby: groups against ships and naval yards

local function HandleSeaBabies(bot)
	local list = bot.units.seababy
	if #list == 0 then
		return
	end

	local idle, assigned = { }, { }
	for _, r in ipairs(list) do
		local a = r.actor
		if r.state == "approach" and not r.target.IsDead and a.IsInWorld and Seen(bot, r.tx, r.ty) then
			-- an attack order only works on a target in sight: sail closer first
			r.state, r.since = "attack", tick
			a.Attack(r.target)
		end

		if r.state == "attack" or r.state == "approach" then
			local stuck = a.IsIdle and tick - r.since > (r.state == "attack" and 3 or 10) * Second
			if r.target.IsDead or stuck then
				r.state = nil
			else
				assigned[r.key] = (assigned[r.key] or 0) + 1
			end
		end

		if not r.state and a.IsInWorld then
			table.insert(idle, r)
		end
	end

	if #idle == 0 then
		return
	end

	local own = World[bot.name]
	local targets, urgent = { }, false
	local function Add(e)
		if not Alive(e.actor) or Hidden(e.actor) then
			return
		end

		local water = nil
		for dy = 0, 2 do
			for dx = 0, 2 do
				water = water or RegionAt(DeepRegion, e.x + dx, e.y + dy)
			end
		end

		if water then
			e.water = water
			table.insert(targets, e)
			-- enemy ships close to our naval yard or our ships: no waiting for a group
			if e.info.naval then
				if bot.yardX and Dist2(e.x, e.y, bot.yardX, bot.yardY) <= 14 * 14 then
					urgent = true
				end

				for _, o in ipairs(own.ships) do
					if Dist2(o.x, o.y, e.x, e.y) <= 8 * 8 then
						urgent = true
						break
					end
				end
			end
		end
	end

	EachEnemy(bot, "ships", Add)
	EachEnemy(bot, "buildings", function(e)
		if NavalYardTypes[e.info.type] then
			Add(e)
		end
	end)

	if #targets == 0 or (#idle < 3 and not urgent) then
		return
	end

	for _, r in ipairs(idle) do
		local a = r.actor
		local loc = a.Location
		local water = RegionAt(DeepRegion, loc.X, loc.Y)
		local best, bestScore
		for _, e in ipairs(targets) do
			local key = e.x .. "," .. e.y
			-- charge: 32000 at the centre; ~28000 counted per boat
			local needed = math.max(1, math.ceil(e.actor.Health / 28000))
			if e.water == water and (assigned[key] or 0) < needed then
				local d = math.sqrt(Dist2(loc.X, loc.Y, e.x, e.y))
				local score = math.max(300, e.info.cost) / (1 + d / 25)
				if not bestScore or score > bestScore then
					best, bestScore = e, score
				end
			end
		end

		if best then
			local key = best.x .. "," .. best.y
			assigned[key] = (assigned[key] or 0) + 1
			r.target, r.key, r.tx, r.ty, r.since = best.actor, key, best.x, best.y, tick
			if Seen(bot, best.x, best.y) then
				r.state = "attack"
				a.Attack(best.actor)
			else
				r.state = "approach"
				a.Move(CPos.New(best.x, best.y), 4)
			end

			Log(bot.name .. " Sea Baby " .. r.state .. " " .. best.info.type .. " at " .. key)
		end
	end
end

-- ---------------------------------------------------------------------------
-- HUR agents: around the defences to a refinery or silo, infantry killed on
-- the way, vehicles stolen on the way

local function HandleGUR(bot)
	local list = bot.units.gur
	if #list == 0 then
		return
	end

	local idle = { }
	for _, r in ipairs(list) do
		local a = r.actor
		if a.IsInWorld then
			if r.state and a.IsIdle and tick - r.since > 5 * Second then
				r.state = nil
			end

			-- a valuable vehicle within reach, not covered by defences: steal it
			if r.state ~= "steal" then
				local loc = a.Location
				local prize, prizeValue
				EachEnemy(bot, "ground", function(e)
					if not e.info.infantry and e.info.cost >= 700 and Dist2(loc.X, loc.Y, e.x, e.y) <= 6 * 6
						and Alive(e.actor) and not Hidden(e.actor) and DefenceThreat(bot, e.x, e.y, 0) == 0
						and a.CanCapture(e.actor) then
						local value = e.info.cost * (e.info.type == "harv" and 1.5 or 1)
						if not prizeValue or value > prizeValue then
							prize, prizeValue = e, value
						end
					end
				end)

				if prize then
					r.state, r.since = "steal", tick
					a.Stop()
					a.Capture(prize.actor)
					Log(bot.name .. " HUR agent steals " .. prize.info.type)
				end
			end

			if not r.state then
				table.insert(idle, r)
			end
		end
	end

	if #idle == 0 then
		bot.gurWait = nil
		return
	end

	bot.gurWait = bot.gurWait or tick
	if #idle < 2 and tick - bot.gurWait < 45 * Second then
		return
	end

	-- the refinery or silo of the richest enemy, the least defended one first
	local from = idle[1].actor.Location
	local target = RaidTarget(bot, from, function(e, d)
		if not CashTypes[e.info.type] then
			return nil
		end

		local cash = d.player.Cash + d.player.Resources
		if cash <= 0 then
			return nil
		end

		return cash
	end)
	if not target then
		return
	end

	local route = PlanRoute(bot, from, CPos.New(target.x, target.y), bot.homeLand, 3)
	if not route then
		return
	end

	bot.gurWait = nil
	for _, r in ipairs(idle) do
		local a = r.actor
		local goal = target.actor
		r.state, r.since = "raid", tick
		FollowRoute(a, route, true, function()
			if a.IsDead or not a.IsInWorld then
				return
			end

			local t = goal
			if t.IsDead then
				local p = bot.player
				t = Map.ActorsInCircle(a.CenterPosition, WDist.FromCells(10), function(x)
					return not x.IsDead and CashTypes[x.Type] and not x.Owner.IsAlliedWith(p)
				end)[1]
			end

			if t then
				a.Infiltrate(t)
			end
		end)
	end

	Log(bot.name .. " HUR raid on " .. target.info.type .. " at " .. target.x .. "," .. target.y)
end

-- ---------------------------------------------------------------------------
-- Bohdana / Vilkha: behind the troops, never in the front line

local Standoff = { bohdana = 8, vilkha = 7 }

local function HandleArtillery(bot)
	local list = bot.units.arty
	if #list == 0 then
		return
	end

	local bx, by = Base(bot)
	local t = bot.target
	for _, r in ipairs(list) do
		local a = r.actor
		if a.IsInWorld then
			local loc = a.Location
			-- enemies inside the minimum range: fall back
			local danger = false
			EachEnemy(bot, "ground", function(e)
				if Dist2(e.x, e.y, loc.X, loc.Y) <= 5 * 5 then
					danger = true
					return true
				end
			end)

			local x, y
			if danger then
				x, y = StepToward(loc.X, loc.Y, bx, by, 6)
			elseif bot.front then
				x, y = StepToward(bot.front.x, bot.front.y, bx, by, Standoff[a.Type] or 7)
				x, y = OutOfDefences(bot, x, y, bx, by, 1)
			elseif t then
				x, y = StepToward(bx, by, t.x, t.y, 6)
			else
				x, y = bx, by
			end

			local dest = SnapTo(LandRegion, bot.homeLand, x, y, 4)
			if dest then
				local moved = not r.dest or Dist2(r.dest.X, r.dest.Y, dest.X, dest.Y) > 9
				local away = Dist2(loc.X, loc.Y, dest.X, dest.Y) > 16
				if (moved and away) or (danger and tick - (r.since or 0) > 2 * Second) or (a.IsIdle and away) then
					r.dest, r.since = dest, tick
					a.Stop()
					a.Move(dest, 2)
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- F-16: interceptors

local function HandleFighters(bot)
	local list = bot.units.f16
	if #list == 0 then
		return
	end

	local bx, by = Base(bot)
	local own = World[bot.name]
	local threats = { }
	EachEnemy(bot, "air", function(e)
		-- a shot-down aircraft falls as a husk: nothing to intercept
		if not Alive(e.actor) or e.info.type:find("husk", 1, true) then
			return false
		end

		local near = Dist2(e.x, e.y, bx, by) <= 20 * 20
		if not near then
			for _, o in ipairs(own.points) do
				if Dist2(o.x, o.y, e.x, e.y) <= 10 * 10 then
					near = true
					break
				end
			end
		end

		-- not deep inside enemy air defence, unless it is over our base
		if near and (Dist2(e.x, e.y, bx, by) <= 15 * 15 or AAThreat(bot, e.x, e.y, 0) <= 1) then
			table.insert(threats, e)
		end
	end)

	local assigned = { }
	for _, r in ipairs(list) do
		if r.target and (r.target.IsDead or r.target.CenterPosition.Z <= 256) then
			r.target = nil
		end

		if r.target then
			assigned[r.key] = (assigned[r.key] or 0) + 1
		end
	end

	for _, r in ipairs(list) do
		local a = r.actor
		if not r.target and a.IsInWorld and a.AmmoCount() > 0 then
			local loc = a.Location
			local best, bestD
			for _, e in ipairs(threats) do
				local key = e.x .. "," .. e.y
				local d = Dist2(loc.X, loc.Y, e.x, e.y)
				if (assigned[key] or 0) < 2 and (not bestD or d < bestD) then
					best, bestD = e, d
				end
			end

			if best then
				local key = best.x .. "," .. best.y
				assigned[key] = (assigned[key] or 0) + 1
				r.target, r.key = best.actor, key
				a.Attack(best.actor)
				Log(bot.name .. " F-16 intercepts " .. best.info.type)
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Mi-8 air assault (called by ukraine-heliassault.lua): land next to the
-- enemy base, away from its air defence and base defences

local function FindBot(player)
	for _, bot in ipairs(Bots) do
		if bot.name == player.InternalName then
			return bot
		end
	end
end

AI.AdjustAssaultTarget = function(owner, target)
	local bot = FindBot(owner)
	if not bot or not MinX then
		return target
	end

	local result = target
	Try(function()
		local hx, hy = Base(bot)
		local occupied = { }
		local buildings = { }
		for _, p in ipairs(Players) do
			local d = World[p.InternalName]
			if d then
				for _, e in ipairs(d.buildings) do
					for dy = -1, 3 do
						for dx = -1, 3 do
							occupied[(e.y + dy) * 10000 + e.x + dx] = true
						end
					end
				end
			end
		end

		EachEnemy(bot, "buildings", function(e)
			table.insert(buildings, e)
		end)

		local best, bestScore
		for dy = -14, 14 do
			for dx = -14, 14 do
				local x, y = target.X + dx, target.Y + dy
				local r2 = dx * dx + dy * dy
				if r2 >= 25 and r2 <= 196 and InMap(x, y) and LandRegion[CellIndex(x, y)]
					and not occupied[y * 10000 + x] and Terrain[CellIndex(x, y)] ~= "Beach" then
					local near
					for _, e in ipairs(buildings) do
						local d = Dist2(x, y, e.x + 1, e.y + 1)
						if not near or d < near then
							near = d
						end
					end

					near = math.sqrt(near or 0)
					-- the helicopters come in from the side of the base: prefer
					-- that side and no air defence on the last stretch of the way
					local ax, ay = StepToward(x, y, hx, hy, 10)
					local score = 100 * AAThreat(bot, x, y, 2) + 50 * DefenceThreat(bot, x, y, 2)
						+ 2 * math.abs(near - 7)
						+ 0.3 * (math.sqrt(Dist2(x, y, hx, hy)) - math.sqrt(Dist2(target.X, target.Y, hx, hy)))
						+ 20 * AALine(bot, x, y, ax, ay, 1)
					if not bestScore or score < bestScore then
						best, bestScore = CPos.New(x, y), score
					end
				end
			end
		end

		if best then
			Log(bot.name .. " Mi-8 landing moved from " .. target.X .. "," .. target.Y .. " to " .. best.X .. "," .. best.Y)
			result = best
		end
	end)

	return result
end

-- ---------------------------------------------------------------------------
-- Main loop

local function NewBot(p)
	local home = p.HomeLocation
	local bot =
	{
		player = p, name = p.InternalName, ukraine = p.Faction == "ukraine",
		home = home, homeLand = RegionAt(LandRegion, home.X, home.Y),
		units = { apc = { }, lst = { }, tb2 = { }, lyutyi = { }, f16 = { }, ratel = { }, seababy = { }, gur = { }, arty = { } },
		offset = #Bots * 5, enemies = { }, friends = { }
	}

	for _, other in ipairs(Players) do
		if other.InternalName == bot.name or other.IsAlliedWith(p) then
			table.insert(bot.friends, other.InternalName)
		else
			table.insert(bot.enemies, other.InternalName)
		end
	end

	-- switch the bot's squads to the variant that leaves our units alone
	if p.AcceptsCondition("ukraine-lua-ai") then
		p.GrantCondition("ukraine-lua-ai")
	end

	return bot
end

local function UpdateBot(bot, scanned)
	if scanned then
		Prune(bot)
		Register(bot)
		UpdateTargets(bot)
	end

	if not World[bot.name] then
		return
	end

	for _, r in ipairs(bot.units.apc) do
		Try(HandleAPC, bot, r)
	end

	for _, r in ipairs(bot.units.lst) do
		Try(HandleLST, bot, r)
	end

	if tick % (5 * Second) < UpdateInterval then
		Try(BuildLandingCraft, bot)
		Try(BuildDrones, bot)
	end

	if scanned and tick % (60 * Second) < ScanInterval then
		Try(Status, bot)
	end

	Try(HandleTB2s, bot)
	Try(HandleLyutyi, bot)
	Try(HandleRatels, bot)
	Try(HandleSeaBabies, bot)
	Try(HandleGUR, bot)
	Try(HandleArtillery, bot)
	Try(HandleFighters, bot)
end

local lastScan = -ScanInterval

WorldLoaded = function()
	if ChainedWorldLoaded then
		ChainedWorldLoaded()
	end

	Try(function()
		AnalyseMap()
		Players = Player.GetPlayers(function(p) return not p.IsNonCombatant end)
		local test = Set(AI.TestPlayers)
		for _, p in ipairs(Players) do
			if p.IsBot or test[p.InternalName] then
				table.insert(Bots, NewBot(p))
				Log("driving " .. p.InternalName .. " (" .. p.Faction .. ")")
			end
		end
	end)
end

Tick = function()
	if ChainedTick then
		ChainedTick()
	end

	tick = tick + 1
	if #Bots == 0 or not MinX then
		return
	end

	local scanned = false
	if tick - lastScan >= ScanInterval then
		lastScan = tick
		Try(ScanWorld)
		scanned = true
	end

	for _, bot in ipairs(Bots) do
		if scanned or (tick + bot.offset) % UpdateInterval == 0 then
			Try(UpdateBot, bot, scanned)
		end
	end
end
