--[[
   Red Alert: Ukraine - proving ground for the 1.3.0 features.

   North-west: your base (airfields with Lyutyi drones, tech center, radar,
   barracks). East: rows of enemy buildings for the Lyutyi. South-east: groups
   of enemy tanks and infantry. West: UAV operators duelling a Tesla Tank with
   the same range. South: enemy defences for the Storm Shadow. Middle: suggested
   landing zone for the Mi-8 air assault. Both airfield powers start charged
   and then recharge normally (5 minutes).

   Enemy targets heal 20 seconds after they are hit and come back 15 seconds
   after they are destroyed, so every test can be repeated.
   Runs together with ukraine-heliassault.lua (same script context), so it
   chains that script's WorldLoaded and Tick.
]]

local AssaultWorldLoaded, AssaultTick = WorldLoaded, Tick

local RespawnDelay = DateTime.Seconds(15)
local HealDelay = DateTime.Seconds(20)
local LandingZone = CPos.New(56, 64)

local me, creeps

local PlayerBase =
{
	{ "powr", 36, 31 }, { "powr", 38, 31 }, { "powr", 40, 31 },
	{ "barr.ukraine", 43, 31 }, { "dome", 46, 31 }, { "stek.ukraine", 49, 31 },
	{ "afld.ukraine", 36, 35 }, { "afld.ukraine", 40, 35 }, { "afld.ukraine", 44, 35 },
	{ "lyutyi", 37, 36 }, { "lyutyi", 41, 36 }, { "lyutyi", 45, 36 },
	{ "uavop", 37, 46 }, { "uavop", 39, 46 }, { "uavop", 41, 46 }, { "uavop", 43, 46 },
	-- Bohdana with the raised barrel next to a Vilkha for comparison
	{ "bohdana", 50, 41 }, { "vilkha", 53, 41 },
	-- F-16 interceptors (Defend stance: they take off by themselves)
	{ "f16", 54, 36 }, { "f16", 57, 36 }
}

-- enemy targets: type, x, y, stance (nil for buildings without weapons)
local Targets =
{
	-- Lyutyi vs buildings (row 1 and row 2)
	{ "fact", 66, 32 }, { "powr", 72, 32 }, { "barr", 77, 32 }, { "dome", 82, 32 }, { "tsla", 88, 32, "HoldFire" },
	{ "weap", 66, 40 }, { "stek", 72, 40 }, { "apwr", 78, 40 }, { "proc", 84, 40 },

	-- Lyutyi vs a group of tanks and infantry
	{ "3tnk", 72, 60, "HoldFire" }, { "2tnk", 71, 61, "HoldFire" }, { "1tnk", 73, 61, "HoldFire" },
	{ "e1", 71, 59, "HoldFire" }, { "e1", 73, 59, "HoldFire" }, { "e1", 70, 60, "HoldFire" }, { "e1", 74, 60, "HoldFire" },
	{ "e3", 72, 62, "HoldFire" }, { "e3", 72, 58, "HoldFire" },

	-- Lyutyi vs a Mammoth Tank with escort
	{ "4tnk", 84, 70, "HoldFire" }, { "v2rl", 83, 71, "HoldFire" },
	{ "e1", 85, 69, "HoldFire" }, { "e1", 85, 71, "HoldFire" }, { "e1", 83, 69, "HoldFire" },

	-- UAV operators (range 7) vs a Tesla Tank with the same range, plus riflemen
	{ "ttnk", 40, 52, "Defend" }, { "e1", 37, 52, "HoldFire" }, { "e1", 43, 52, "HoldFire" },

	-- Storm Shadow (one precise missile): a line of defences 4 cells apart ...
	{ "sam", 46, 82, "HoldFire" }, { "agun", 51, 82, "HoldFire" }, { "tsla", 55, 82, "HoldFire" },
	{ "pbox", 59, 82, "HoldFire" }, { "gun", 63, 82, "HoldFire" }, { "ftur", 67, 82, "HoldFire" },
	-- ... and a tight group of three: only the one that is hit goes down
	{ "pbox", 49, 74, "HoldFire" }, { "hbox", 48, 75, "HoldFire" }, { "gun", 50, 75, "HoldFire" },

	-- F-16: enemy aircraft patrolling between two points (type, x, y, stance, patrol to)
	{ "hind", 62, 36, "HoldFire", { 80, 36 } }, { "yak", 64, 48, "HoldFire", { 86, 48 } }
}

local function SpawnTarget(slot)
	local actor = Actor.Create(slot[1], true, { Owner = creeps, Location = CPos.New(slot[2], slot[3]) })
	if slot[4] ~= nil then
		actor.Stance = slot[4]
	end

	if slot[5] ~= nil then
		actor.Patrol({ CPos.New(slot[2], slot[3]), CPos.New(slot[5][1], slot[5][2]) }, true, 0)
	end

	local healing = false
	Trigger.OnDamaged(actor, function(self)
		if healing then
			return
		end

		healing = true
		Trigger.AfterDelay(HealDelay, function()
			healing = false
			if not self.IsDead then
				self.Health = self.MaxHealth
			end
		end)
	end)

	Trigger.OnKilled(actor, function()
		Trigger.AfterDelay(RespawnDelay, function() SpawnTarget(slot) end)
	end)
end

local Hints =
{
	"Полігон Red Alert: Ukraine 1.3.0. Туман вимкнено, гроші — 100000.",
	"ЛЮТИЙ: виділіть дрон на аеродромі (північний захід) і накажіть атакувати будівлю на сході або групу танків на південному сході. Будівельний центр отримає 75% урону.",
	"Нові «Люті» будуються на аеродромі за 6 секунд (вкладка авіації). Пряме влучання знищує наземну техніку. «Мамонт» із повним здоров’ям зберігає 25%.",
	"МІ-8: кнопка «Mi-8 Air Assault» на панелі суперзброї праворуч, готова з початку. Клацніть по позначеній зоні в центрі мапи (або будь-де на суші). Перезарядка — 5 хвилин, як у «Десанту».",
	"STORM SHADOW: кнопка на тій самій панелі, готова з початку. Одна точна ракета знищує одну ціль — будівлю, оборону чи техніку (будівельний центр лишається з 20%). У трійці дотів на півдні загине лише той, у який влучили.",
	"ОПЕРАТОРИ БПЛА (захід) б'ють на 7 клітинок — так само далеко, як Тесла-танк навпроти них.",
	"F-16 (біля бази) — винищувачі ППО: самі злітають і збивають ворожі Мі-24 та Як, що патрулюють на півночі. По наземних цілях не б'ють.",
	"Мішені лікуються через 20 с після влучання і з'являються знову через 15 с після знищення."
}

WorldLoaded = function()
	AssaultWorldLoaded()

	me = Player.GetPlayer("Multi0")
	creeps = Player.GetPlayer("Creeps")
	me.Cash = 100000

	for _, b in ipairs(PlayerBase) do
		Actor.Create(b[1], true, { Owner = me, Location = CPos.New(b[2], b[3]) })
	end

	for _, slot in ipairs(Targets) do
		SpawnTarget(slot)
	end

	Beacon.New(me, Map.CenterOfCell(LandingZone), DateTime.Minutes(120), false)
	Camera.Position = Map.CenterOfCell(CPos.New(52, 44))
	UserInterface.SetMissionText("Полігон 1.3.0: «Лютий» · десант Мі-8 · оператори БПЛА")

	for i, text in ipairs(Hints) do
		Trigger.AfterDelay(DateTime.Seconds(1 + (i - 1) * 4), function()
			Media.DisplayMessage(text, "Полігон")
		end)
	end
end

Tick = function()
	AssaultTick()
end
