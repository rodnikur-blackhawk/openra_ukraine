-- Cosmetic delivery for placed launchers. The building keeps its original footprint.
local PreviousWorldLoaded, PreviousTick = WorldLoaded, Tick
local installations = {}
local trackedTag = "flamingo-installation-tracked"
local ticks = 0
local minX, minY, maxX, maxY
local roadTerrain = { Clear = true, Rough = true, Road = true, Ore = true, Gems = true,
	Beach = true, Bridge = true, Scorch = true }
local offsets = { { 0, 1 }, { 1, 1 }, { -1, 0 }, { 2, 0 }, { 0, -1 }, { 1, -1 } }

local function DistanceSquared(a, b)
	return (a.X - b.X)^2 + (a.Y - b.Y)^2
end

local function FreeCell(x, y)
	if x < minX or y < minY or x > maxX or y > maxY then return nil end
	local cell = CPos.New(x, y)
	if not roadTerrain[Map.TerrainType(cell)] then return nil end
	local center = Map.CenterOfCell(cell)
	local actors = Map.ActorsInCircle(center, WDist.New(470), function(a)
		return a.IsInWorld
	end)
	if #actors == 0 then return cell end
	return nil
end

local function ClosestYard(building)
	local closest, distance
	for _, yard in ipairs(building.Owner.GetActorsByTypes({ "fact", "mcv" })) do
		local d = DistanceSquared(yard.Location, building.Location)
		if not distance or d < distance then
			closest, distance = yard, d
		end
	end
	return closest
end

local function RemoveVehicle(vehicle)
	if vehicle and vehicle.IsInWorld and not vehicle.IsDead then
		vehicle.Stop()
		vehicle.Destroy()
	end
end

local function SetCondition(building, state, key, condition, enabled)
	if enabled and not state[key] then
		state[key] = building.GrantCondition(condition)
	elseif not enabled and state[key] then
		building.RevokeCondition(state[key])
		state[key] = nil
	end
end

local function AdjacentCell(origin)
	for _, offset in ipairs(offsets) do
		local cell = FreeCell(origin.X + offset[1], origin.Y + offset[2])
		if cell then return cell end
	end
	return nil
end

local function Track(building)
	building.AddTag(trackedTag)
	local state = { building = building }
	installations[#installations + 1] = state
	return state
end

local function StartDelivery(building, state)
	local yard = ClosestYard(building)
	if not yard then return end
	local origin
	local exits = yard.Type == "fact" and { { 1, 3 }, { 0, 3 }, { 3, 1 }, { -1, 1 }, { 1, -1 } } or offsets
	for _, offset in ipairs(exits) do
		origin = FreeCell(yard.Location.X + offset[1], yard.Location.Y + offset[2])
		if origin then break end
	end
	local dest = AdjacentCell(building.Location)
	if not origin or not dest then return end

	state.owner = building.Owner
	state.delivery = building.GrantCondition("build-incomplete", DateTime.Seconds(35))
	local heading = Map.CenterOfCell(origin) - yard.CenterPosition
	state.vehicle = Actor.Create("flamingo.delivery", true, {
		Owner = state.owner, Location = origin, Facing = heading.Facing
	})
	state.vehicle.Move(dest)
	state.destination = dest
	state.deadline = ticks + DateTime.Seconds(32)
	state.checkAfter = ticks + 5
	state.phase = "delivery"
end

local function EndDelivery(building, state)
	RemoveVehicle(state.vehicle)
	state.vehicle = nil
	if state.delivery then
		building.RevokeCondition(state.delivery)
		state.delivery = nil
	end
	if state.parking then
		building.RevokeCondition(state.parking)
		state.parking = nil
	end
	state.phase = nil
end

local function UpdateDelivery(building, state)
	local vehicle = state.vehicle
	if state.owner ~= building.Owner or not vehicle.IsInWorld or vehicle.IsDead or ticks >= state.deadline then
		EndDelivery(building, state)
		return
	end
	if not vehicle.IsIdle then return end
	if state.phase == "parking" or DistanceSquared(vehicle.Location, state.destination) > 1 then
		EndDelivery(building, state)
		return
	end

	-- Reveal the trailer at its reserved footprint; drive the detached cab clear.
	local origin, facing = vehicle.Location, vehicle.Facing
	local parking = FreeCell(building.Location.X - 1, building.Location.Y + 1) or AdjacentCell(origin)
	if not parking then
		EndDelivery(building, state)
		return
	end
	state.parking = building.GrantCondition("flamingo-parking", DateTime.Seconds(6))
	building.RevokeCondition(state.delivery)
	state.delivery = nil
	RemoveVehicle(vehicle)
	state.phase = "detach"
	Trigger.AfterDelay(2, function()
		if not building.IsInWorld or building.IsDead then return end
		if building.Owner ~= state.owner then
			EndDelivery(building, state)
			return
		end
		state.vehicle = Actor.Create("flamingo.tractor", true, {
			Owner = state.owner, Location = origin, Facing = facing
		})
		state.vehicle.Move(parking)
		state.phase = "parking"
		state.deadline = ticks + DateTime.Seconds(4)
		state.checkAfter = ticks + 5
	end)
end

WorldLoaded = function()
	if PreviousWorldLoaded then PreviousWorldLoaded() end
	minX, minY = math.floor(Map.TopLeft.X / 1024), math.floor(Map.TopLeft.Y / 1024)
	maxX, maxY = math.floor(Map.BottomRight.X / 1024) - 1, math.floor(Map.BottomRight.Y / 1024) - 1
	for _, actor in ipairs(Map.ActorsInWorld) do
		if actor.Type == "flamingo" then
			Track(actor)
		elseif actor.Type == "flamingo.delivery" or actor.Type == "flamingo.tractor" then
			RemoveVehicle(actor)
		end
	end
end

Tick = function()
	if PreviousTick then PreviousTick() end
	ticks = ticks + 1
	if ticks % 5 ~= 0 then return end

	for _, building in ipairs(Map.ActorsInWorld) do
		if building.Type == "flamingo" and building.IsInWorld and not building.IsDead and not building.HasTag(trackedTag) then
			local state = Track(building)
			if not Map.IsNamedActor(building) then StartDelivery(building, state) end
		end
	end
	for i = #installations, 1, -1 do
		local state = installations[i]
		local building = state.building
		if not building.IsInWorld or building.IsDead then
			RemoveVehicle(state.vehicle)
			table.remove(installations, i)
		else
			SetCondition(building, state, "wreck", "flamingo-tractor-wrecked", building.Health * 2 <= building.MaxHealth)
			SetCondition(building, state, "scorch", "flamingo-scorched", building.Health * 5 <= building.MaxHealth)
			if state.phase and state.phase ~= "detach" and ticks >= state.checkAfter then
				UpdateDelivery(building, state)
			end
		end
	end
end
