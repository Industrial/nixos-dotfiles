local function IsGear(itemID)
  local classType = select(6, C_Item.GetItemInfoInstant(itemID))
  return Auctionator.Utilities.IsEquipment(classType)
end

function Auctionator.Utilities.DBKeyFromItemKey(itemKey, callback)
  if itemKey.battlePetSpeciesID ~= 0 then
    callback({"p:" .. tostring(itemKey.battlePetSpeciesID)})
  elseif IsGear(itemKey.itemID) then
    local basicKey = tostring(itemKey.itemID)
    if Auctionator.Constants.IsForever then
      Auctionator.AH.GetItemKeyInfo(itemKey, function(info)
        local name = info.itemName
        Item:CreateFromItemID(itemKey.itemID):ContinueOnItemLoad(function()
          local baseName = C_Item.GetItemNameByID(itemKey.itemID)
          if name == baseName then
            callback({basicKey})
          else
            local suffix = name:sub(string.len(baseName.. " ") + 1)
            local english = Auctionator.Utilities.SuffixesToLabel[suffix]
            if english then
              callback({"gr:" .. itemKey.itemID .. ":" .. english, basicKey})
            else
              callback({basicKey})
            end
          end
        end)
      end)
    elseif  itemKey.itemLevel >= Auctionator.Constants.ITEM_LEVEL_THRESHOLD then
      callback({
        "g:" .. itemKey.itemID .. ":" .. itemKey.itemLevel,
        basicKey
      })
    else
      callback({tostring(itemKey.itemID)})
    end
  else
    callback({tostring(itemKey.itemID)})
  end
end

function Auctionator.Utilities.DBKeyFromBrowseResult(result)
  if result.itemKey.battlePetSpeciesID ~= 0 then
    return {"p:" .. tostring(result.itemKey.battlePetSpeciesID)}
  elseif IsGear(result.itemKey.itemID) and result.itemKey.itemLevel >= Auctionator.Constants.ITEM_LEVEL_THRESHOLD then
    return {
      "g:" .. result.itemKey.itemID .. ":" .. result.itemKey.itemLevel,
      tostring(result.itemKey.itemID)
    }
  else
    return {tostring(result.itemKey.itemID)}
  end
end
