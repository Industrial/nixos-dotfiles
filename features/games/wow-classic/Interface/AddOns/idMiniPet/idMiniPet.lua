-- Keeps a companion pet out: a random favorite, or any pet when you have no favorites.
local P=C_PetJournal
C_Timer.NewTicker(5,function()
  if P.GetSummonedPetGUID()or InCombatLockdown()or IsMounted()or UnitIsDeadOrGhost("player")or UnitOnTaxi("player")or IsStealthed()or UnitIsFeignDeath("player")then return end
  P.SummonRandomPet(true)
  C_Timer.After(1,function()if not P.GetSummonedPetGUID()then P.SummonRandomPet(false)end end)
end)
