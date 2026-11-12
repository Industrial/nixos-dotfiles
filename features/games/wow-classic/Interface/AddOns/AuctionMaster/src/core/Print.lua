local addonName, AM = ...

-- Prints to the chat frame with the addon name as prefix.
function AM.Print(...)
  print("|cff33ff99" .. addonName .. "|r:", ...)
end
