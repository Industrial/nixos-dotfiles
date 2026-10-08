local addonName, addon = ...

---@class BetterBags: AceAddon
local addon = LibStub('AceAddon-3.0'):GetAddon('BetterBags')

---@class Localization: AceModule
local L = addon:GetModule('Localization')

L.data["CK Addon Name"] = {
	["deDE"] = "Crafting Knowledge",
	["esES"] = "Crafting Knowledge",
  	["esMX"] = "Crafting Knowledge",
  	["frFR"] = "Crafting Knowledge",
  	["itIT"] = "Crafting Knowledge",
  	["koKR"] = "Crafting Knowledge",
  	["ptBR"] = "Crafting Knowledge",
  	["ruRU"] = "Знания профессии",
  	["zhCN"] = "专业知识",
  	["zhTW"] = "Crafting Knowledge",
}

L.data["DF Crafting Knowledge"] = {
	["deDE"] = "Dragonflight Crafting Knowledge",
	["esES"] = "Dragonflight Crafting Knowledge",
  	["esMX"] = "Dragonflight Crafting Knowledge",
  	["frFR"] = "Dragonflight Crafting Knowledge",
  	["itIT"] = "Dragonflight Crafting Knowledge",
  	["koKR"] = "Dragonflight Crafting Knowledge",
  	["ptBR"] = "Dragonflight Crafting Knowledge",
  	["ruRU"] = "Знания профессии Dragonflight",
  	["zhCN"] = "专业知识 - 巨龙时代",
  	["zhTW"] = "Dragonflight Crafting Knowledge",
}

L.data["TWW Crafting Knowledge"] = {
	["deDE"] = "War Within Crafting Knowledge",
	["esES"] = "War Within Crafting Knowledge",
  	["esMX"] = "War Within Crafting Knowledge",
  	["frFR"] = "War Within Crafting Knowledge",
  	["itIT"] = "War Within Crafting Knowledge",
  	["koKR"] = "War Within Crafting Knowledge",
  	["ptBR"] = "War Within Crafting Knowledge",
  	["ruRU"] = "Знания профессии War Within",
  	["zhCN"] = "专业知识 - 地心之战",
  	["zhTW"] = "War Within Crafting Knowledge",
}

