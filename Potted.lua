-----------------------------------------------------------------------------------------------
-- Potted
-- An addon to remind you if you are missing consumables during raid combat by Caleb - calebzor@gmail.com
-- /potted
-----------------------------------------------------------------------------------------------

--[[
	TODO:
		move everything to GeminiGUI
		food buffs probably need to be tracked by name not by Id -- need to look into this
		TEST STUFF!
		populate bufftype tables

		bunch of group related code
		only start timer in group and disable it outside of group
]]--


local sVersion = "9.0.0.3"

require "GameLib"
require "GroupLib"
require "CColor"

-----------------------------------------------------------------------------------------------
-- Upvalues
-----------------------------------------------------------------------------------------------
local CColor = CColor
local GameLib = GameLib
local GroupLib = GroupLib
local Apollo = Apollo
local unpack = unpack
local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber
local tostring = tostring
local Print = Print
local type = type
local math = math

-----------------------------------------------------------------------------------------------
-- Package loading
-----------------------------------------------------------------------------------------------
local addon = Apollo.GetPackage("Gemini:Addon-1.1").tPackage:NewAddon("Potted", false, {}, "Gemini:Timer-1.0" )
local GeminiColor = Apollo.GetPackage("GeminiColor").tPackage
local GeminiGUI = Apollo.GetPackage("Gemini:GUI-1.0").tPackage
local GeminiConfig = Apollo.GetPackage("Gemini:Config-1.0").tPackage
local GeminiColor = Apollo.GetPackage("GeminiColor").tPackage
--local GeminiCmd = Apollo.GetPackage("Gemini:ConfigCmd-1.0").tPackage
local L = Apollo.GetPackage("Gemini:Locale-1.0").tPackage:GetLocale("Potted", true)

-----------------------------------------------------------------------------------------------
-- Locals and defaults
-----------------------------------------------------------------------------------------------
local defaults = {
	profile = {
		tPos = {232,235,352,264},
		bShowAnchor = true,
		nContainerCount = 3,
		nContainerSize = 80,
		nPadding = 0,
		nTresholdToShow = 4,
		nPartyMembersInCombatForcombatCheck = 1,
		nOpacity = 1,
		progressColor = {1,0,0,0.7},
		titleFont = "CRB_Interface9_BO",
		timerFont = "CRB_Interface9_BO",
		stackFont = "CRB_Interface9_BO",
		c1 = "tBoostIds",
		c2 = "tFieldTechtIds",
		c3 = "tFoodIds",
	},
}

local uPlayer

-----------------------------------------------------------------------------------------------
-- Options tables
-----------------------------------------------------------------------------------------------

local tMyFontTable = {}
for nIndex,font in ipairs(Apollo.GetGameFonts()) do
	-- use this format in case we decide to go back to using nIndex then won't have to change so much again
	tMyFontTable[font.name] = font.name
end

local tLocalizedNameOfTrackType = {
	tBoostIds = "Boosts",
	tFieldTechtIds = "Field Tech",
	tFoodIds = "Food",
}

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function addon:OnInitialize()
	self.tBoostIds = {
		--[32821] = true, -- bolster
		[37091] = true, -- Reactive Moxie Boost
	}
	self.tFieldTechtIds = {
		--[32821] = true, -- bolster
		[35147] = true, -- Life Drain
	}
	self.tFoodIds = {
		--[32821] = true, -- bolster
		[48443] = true, -- Exile Empanadas -- Stuffed!
	}
	self.tTrackTypes = {
		"tBoostIds",
		"tFieldTechtIds",
		"tFoodIds",
	}

	self.db = Apollo.GetPackage("Gemini:DB-1.0").tPackage:New(self, defaults, true)

	self.tContainers = {}
	self.tContainerBuffTypeAssoc = {}
end


function addon:OnEnable()
	self.myOptionsTable = {
		type = "group",
		get = function(info) return self.db.profile[info[#info]] end,
		set = function(info, v) self.db.profile[info[#info]] = v end,
		args = {
			bShowAnchor = {
				order = 1,
				name = "Show/Hide anchor",
				type = "toggle",
				width = "full",
				set = function(info, v) self.db.profile[info[#info]] = v; self.wAnchor:Show(v) end,
			},
			healHeader = {
				order = 2,
				name = "READ ME!",
				type = "header",
			},
			healp = {
				order = 3,
				name = [[If you feel like a buff is not being tracked or not being correctly associated to the correct buff type then it is most likely because the buff's spellId is missing from the addon. Even tho I'm a technologist myself and I spent some time looking up the spellIds for the most common raid buffs it is very possible I missed some. So if you found something missing do the following to help improve the addon:
 
    1) Make sure you have the buff on you.
    2) Mouse over the buff on your buff bar and write the buffs name into the input box just below this text (or at least part of the buff's name).
    3) Once you wrote in the buff's name press the button ("Click me!") next to the input box ( you must still have the buff on you ).
    4) You'll get a debug print in your chat. Write this down and post it on curse as a comment for the addon. ( or e-mail me at: calebzor@gmail.com )
 
				]],
				type = "description",
			},
			helpInput = {
				order = 4,
				name = "Buff's name",
				type = "input",
				usage = "Something most be written here",
				pattern = "%w+",
			},
			helpExecute = {
				order = 5,
				name = "Click me!",
				desc = "Click this once you wrote in the buff's name in the input box",
				type = "execute",
				func = function() self:GetSpellIdForBuffByName(self.db.profile.helpInput) end,
			},
			optionsHeader = {
				order = 8,
				name = "Options",
				type = "header",
			},
			containerHelp = {
				order = 9,
				name = "You might need to change the container count depending on how many things you want to track.",
				type = "description",
			},
			nContainerCount = {
				order = 10,
				name = "Container count",
				type = "range",
				min = 1,
				max = 3,
				step = 1,
				width = "full",
				set = function(info, v) self.db.profile[info[#info]] = v; GeminiConfig:RegisterOptionsTable("Potted", self.myOptionsTable) self:ReCreateContainers() end,
			},
			nContainerSize = {
				order = 20,
				name = "Container size",
				type = "range",
				min = 40,
				max = 400,
				step = 1,
				width = "full",
				set = function(info, v) self.db.profile[info[#info]] = v; self:ReCreateContainers() end,
			},
			paddingHelp = {
				order = 29,
				name = "Padding between containers, in other words distance between them.",
				type = "description",
			},
			nPadding = {
				order = 30,
				name = "Padding",
				type = "range",
				min = 0,
				max = 400,
				step = 1,
				width = "full",
				set = function(info, v) self.db.profile[info[#info]] = v; self:ReCreateContainers() end,
			},
			tresholdHelp = {
				order = 49,
				name = "If a buff type has less than this value time remaining (in seconds), then it'll show the icon. Of course it'll be also shown if you don't have it on. It is recommended to have this be longer than the duration of the 2nd buff you get from like reactive boost ( 10 sec ).",
				type = "description",
			},
			nTresholdToShow = {
				order = 50,
				name = "Time treshold",
				type = "range",
				min = 1,
				max = 59,
				step = 1,
				width = "full",
			},
			partyCombatcounterHelp = {
				order = 59,
				name = "Changing this is the best way to disable the addon for 5 man content. Basically this sets the amount of group members (inluding yourself) required to be in combat for the displays to even show up.",
				type = "description",
			},
			nPartyMembersInCombatForcombatCheck = {
				order = 60,
				name = "In combat party member count for icon show",
				type = "range",
				min = 1,
				max = 40,
				step = 1,
				width = "full",
			},
			customizationHeader = {
				order = 69,
				name = "Visual customization",
				type = "header",
			},
			nOpacity = {
				order = 70,
				name = "Opacity",
				type = "range",
				min = 0,
				max = 1,
				step = 0.05,
				width = "full",
				set = function(info, v) self.db.profile[info[#info]] = v; self:ReCreateContainers() end,
			},
			progressColor = {
				order = 80,
				name = "Progress overlay color",
				type = "color",
				hasAlpha = true,
				get = function(info) return unpack(self.db.profile[info[#info]]) end,
				set = function(info, r,g,b,a) self.db.profile[info[#info]] = {r,g,b,a}; self:ReCreateContainers() end,
			},
			titleFont = {
				order = 90,
				name = "Title font",
				type = "select",
				values = tMyFontTable,
				width = "full",
				set = function(info, v) self.db.profile[info[#info]] = v; self:ReCreateContainers() end,
			},
			timerFont = {
				order = 100,
				name = "Timer font",
				type = "select",
				values = tMyFontTable,
				width = "full",
				set = function(info, v) self.db.profile[info[#info]] = v; self:ReCreateContainers() end,
			},
			stackFont = {
				order = 100,
				name = "Stack font",
				type = "select",
				values = tMyFontTable,
				width = "full",
				set = function(info, v) self.db.profile[info[#info]] = v; self:ReCreateContainers() end,
			},
			containerHeader = {
				order = 999,
				name = "Container options",
				type = "header",
			},

			-- container options are here

			GeminiConfigScrollingFrameBottomWidgetFix = {
				order = 99999,
				name = "",
				type = "description",
			},
		},
	}

	-- well this was planned to be dynamic but now it is not, maybe at some point
	self:GenerateContainerOptions()
	GeminiConfig:RegisterOptionsTable("Potted", self.myOptionsTable)


	Apollo.RegisterSlashCommand("potted", "OpenMenu", self)
	Apollo.RegisterSlashCommand("Potted", "OpenMenu", self)


	self.wAnchor = Apollo.LoadForm("Potted.xml", "Anchor", nil, self)
	self.wAnchor:Show(true)
	self.wAnchor:SetAnchorOffsets(unpack(self.db.profile.tPos))
	self.wAnchor:Show(self.db.profile.bShowAnchor)


	self:ReCreateContainers()


	-- only start timer when in group
	self.updateTimer = self:ScheduleRepeatingTimer("OnUpdate", 0.1)

	-- Apollo.GetPackage("Gemini:ConfigDialog-1.0").tPackage:Open("Potted")
end

function addon:GenerateContainerOptions()
	for i=1, self.myOptionsTable.args.nContainerCount.max do
		local nOrder = 1000
		self.myOptionsTable.args["container"..i.."Header"] = {
			order = nOrder*i,
			name = "Container" .. i,
			type = "header",
		}
		nOrder = nOrder +1
		self.myOptionsTable.args["c"..i] = {
			order = nOrder*i+100,
			name = "Buff type",
			type = "select",
			width = "full",
			values = tLocalizedNameOfTrackType,
			set = function(info, v) self.db.profile[info[#info]] = v; self:OnContainerBuffTypeChange() self:ReCreateContainers() end,
		}
		nOrder = nOrder +1
	end
	
end

-----------------------------------------------------------------------------------------------
-- Constructors and other GUI
-----------------------------------------------------------------------------------------------

function addon:ReCreateContainers()
	if self.updateTimer then self:CancelTimer(self.updateTimer) self.updateTimer = nil end -- stop the updated

	self:OnContainerBuffTypeChange() -- generate container-bufftype assoc table

	-- destroy stuff
	if self.tContainers then
		for k,v in ipairs(self.tContainers) do
			v:Destroy()
		end
	end
	self.tContainers = {}

	-- create stuff
	for i=1, self.db.profile.nContainerCount do -- create containers
		
		self.tContainers[i] = Apollo.LoadForm("Potted.xml", "ItemContainer", nil, self)
		self.tContainers[i]:FindChild("Icon"):SetOpacity(self.db.profile.nOpacity)
		self.tContainers[i]:FindChild("Progress"):SetBGColor(CColor.new(unpack(self.db.profile.progressColor)))
		self.tContainers[i]:FindChild("Title"):SetText(tLocalizedNameOfTrackType[self.tContainerBuffTypeAssoc[i]])

		self.tContainers[i]:FindChild("Title"):SetFont(self.db.profile.titleFont)
		self.tContainers[i]:FindChild("Timer"):SetFont(self.db.profile.timerFont)
		self.tContainers[i]:FindChild("Stack"):SetFont(self.db.profile.stackFont)


		self.tContainers[i]:FindChild("Title"):SetTextColor(CColor.new(1,1,1,self.db.profile.nOpacity))
		self.tContainers[i]:FindChild("Timer"):SetTextColor(CColor.new(1,1,1,self.db.profile.nOpacity))
		self.tContainers[i]:FindChild("Stack"):SetTextColor(CColor.new(1,1,1,self.db.profile.nOpacity))

		self.tContainers[i]:Show(false)
	end

	self:RepositionContainers()

	if not self.updateTimer then self.updateTimer = self:ScheduleRepeatingTimer("OnUpdate", 0.1) end -- start the updated
end

function addon:OpenMenu()
	Apollo.GetPackage("Gemini:ConfigDialog-1.0").tPackage:Open("Potted")
end

function addon:RepositionContainers()
	local l,t,r,b = self.wAnchor:GetAnchorOffsets()
	for i=1, self.db.profile.nContainerCount do
		self.tContainers[i]:SetAnchorOffsets(l+(i-1)*self.db.profile.nContainerSize+(i-1)*self.db.profile.nPadding, b, l+i*self.db.profile.nContainerSize+(i-1)*self.db.profile.nPadding, b+self.db.profile.nContainerSize)
	end
end

function addon:OnAnchorMove()
	self:RepositionContainers()
	local l,t,r,b = self.wAnchor:GetAnchorOffsets()
	self.db.profile.tPos = {l,t,r,b}
end

function addon:OnAnchorLockButton()
	self.wAnchor:Show(false)
	self.db.profile.bShowAnchor = false
end

-----------------------------------------------------------------------------------------------
-- Helpers
-----------------------------------------------------------------------------------------------

function addon:OnContainerBuffTypeChange()
	self.tContainerBuffTypeAssoc = {}
	for k, v in pairs(self.db.profile) do
		if tostring(k):match("c%d+") then
			self.tContainerBuffTypeAssoc[tonumber(tostring(k):match("%d+"))] = v
		end
	end
end

function addon:GetSpellIdForBuffByName(sSpellName)
	if not sSpellName then Print("That was an empty string :(") return end
	uPlayer = GameLib.GetPlayerUnit()
	if not uPlayer then return end
	local tBuffs = uPlayer:GetBuffs().arBeneficial
	if not tBuffs then return end
	local bFound = false
	for k, v in ipairs(tBuffs) do
		if v.splEffect:GetName():lower():match(sSpellName:lower()) then
			Print(("'%s' has: %d -id with time remaining: %d"):format(v.splEffect:GetName(), v.splEffect:GetId(), v.fTimeRemaining))
			bFound = true
		end
	end
	if not bFound then
		Print(("No buff found by the name: '%s'"):format(sSpellName))
	end
end

local function formatTime(nTimeLeft)
	if type(nTimeLeft) ~= "number" then return nTimeLeft end
	local nDays, nHours, nMinutes, nSeconds = math.floor(nTimeLeft / 86400), math.floor((nTimeLeft % 86400) / 3600), math.floor((nTimeLeft % 3600) / 60), nTimeLeft % 60;

	if nDays ~= 0 then
		return ("%dd %dh %dm %ds"):format(nDays, nHours, nMinutes, nSeconds)
	elseif nHours ~= 0 then
		return ("%dh %dm %ds"):format(nHours, nMinutes, nSeconds)
	elseif nMinutes ~= 0 then
		return ("%dm %ds"):format(nMinutes, nSeconds)
	else
		if nSeconds > 10 then
			return ("%ds"):format(nSeconds)
		else
			return ("%.1f"):format(nTimeLeft)
		end
	end
end

function addon:GetContainerIdForTrackType(sTrackType)
	for k,v in ipairs(self.tContainerBuffTypeAssoc) do
		if v == sTrackType then
			return k
		end
	end
	return false
end


function addon:PartyCombatCheck()
	local nRaidMembersInCombat = 0
	for i=1, GroupLib.GetMemberCount() do
		local unit = GroupLib.GetUnitForGroupMember(i)
		if unit then
			if unit:IsInCombat() then
				nRaidMembersInCombat = nRaidMembersInCombat + 1
			end
		end
	end
	return self.db.profile.nPartyMembersInCombatForcombatCheck <= nRaidMembersInCombat
end

-----------------------------------------------------------------------------------------------
-- Updater
-----------------------------------------------------------------------------------------------

function addon:OnUpdate()
	uPlayer = GameLib.GetPlayerUnit()
	if not uPlayer then return end

	local tBuffs = uPlayer:GetBuffs().arBeneficial
	if not tBuffs then return end

	for i=1, self.db.profile.nContainerCount do
		self.tContainers[i]:Show(false) -- hide all containers
	end
	
	for k, v in ipairs(tBuffs) do
		for _, sTrackType in ipairs(self.tTrackTypes) do
			local nContainerIdForTrackType = self:GetContainerIdForTrackType(sTrackType)
			if self[sTrackType] and self[sTrackType][v.splEffect:GetId()] and nContainerIdForTrackType and v.fTimeRemaining < self.db.profile.nTresholdToShow then
				local wContainer = self.tContainers[nContainerIdForTrackType]
				if wContainer then
				local wProgress = wContainer:FindChild("Progress")
					wProgress:SetMax(self.db.profile.nTresholdToShow)
					wProgress:SetProgress(self.db.profile.nTresholdToShow-v.fTimeRemaining)
					wContainer:FindChild("Icon"):SetSprite(v.splEffect:GetIcon())
					wContainer:FindChild("Timer"):SetText(formatTime(v.fTimeRemaining).."s")
					wContainer:FindChild("Stack"):SetText(v.nCount > 1 and v.nCount or "") -- only show number for more than 1 stacks
					wContainer:Show(true)
				end
			end
		end
	end

	if uPlayer:IsInYourGroup() then -- is the player in a group
		local bPartyInCombat = self:PartyCombatCheck()
		for _, sTrackType in ipairs(self.tTrackTypes) do
			local nContainerIdForTrackType = self:GetContainerIdForTrackType(sTrackType)
			if nContainerIdForTrackType then
				local wContainer = self.tContainers[nContainerIdForTrackType]
				if wContainer and not wContainer:IsShown() then
					wContainer:Show(true)
					local wProgress = wContainer:FindChild("Progress")
					wProgress:SetMax(self.db.profile.nTresholdToShow)
					wProgress:SetProgress(self.db.profile.nTresholdToShow)
					wContainer:FindChild("Timer"):SetText("")
					wContainer:FindChild("Stack"):SetText("")
				end
			end
		end
	end


	if not uPlayer:IsInCombat() then
		-- or well maybe not all, aka show food!
		for i=1, self.db.profile.nContainerCount do
			self.tContainers[i]:Show(false) -- hide all containers
		end
	end
end