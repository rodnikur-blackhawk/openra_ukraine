-- The construction sequence handles deployment. Lua tracks damage overlays.
local PreviousTick = Tick
local installations = {}
local trackedTag = "flamingo-installation-tracked"
local ticks = 0

local function SetCondition(building, state, key, condition, enabled)
	if enabled and not state[key] then
		state[key] = building.GrantCondition(condition)
	elseif not enabled and state[key] then
		building.RevokeCondition(state[key])
		state[key] = nil
	end
end

Tick = function()
	if PreviousTick then PreviousTick() end
	ticks = ticks + 1
	if ticks % 5 ~= 0 then return end

	for _, building in ipairs(Map.ActorsInWorld) do
		if building.Type == "flamingo" and building.IsInWorld and not building.IsDead and not building.HasTag(trackedTag) then
			building.AddTag(trackedTag)
			installations[#installations + 1] = { building = building }
		end
	end
	for i = #installations, 1, -1 do
		local state = installations[i]
		local building = state.building
		if not building.IsInWorld or building.IsDead then
			table.remove(installations, i)
		else
			SetCondition(building, state, "wreck", "flamingo-tractor-wrecked", building.Health * 2 <= building.MaxHealth)
			SetCondition(building, state, "scorch", "flamingo-scorched", building.Health * 5 <= building.MaxHealth)
		end
	end
end
