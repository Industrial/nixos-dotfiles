QuestieTraceCore = QuestieTraceCore or {}

---@class QuestieTraceCore
local Core = QuestieTraceCore

---@type l10n
local l10n = Core.l10n

---------------------------------------------------------------------------
-- Data collection consent
---------------------------------------------------------------------------
-- `QuestieTrace.settings.dataCollectionConsent` is a tri-state value:
--   nil   = not asked yet (first login)
--   true  = user consented to local data collection
--   false = user declined; capture must not start, and we must not ask again
---------------------------------------------------------------------------

---@class ConsentFrame : QuestieTraceDialog

---@type ConsentFrame
local consentFrame

--- Bind the addon-owned frame created by Consent.xml, after localization loads.
---@param frame ConsentFrame
function Core.OnConsentFrameLoad(frame)
  consentFrame = frame
  frame.Text:SetText(l10n(
    "Help improve Questie by allowing QuestieTrace to collect anonymized gameplay data, such as quest progress, positions, and loot. Your data stays on your machine unless you choose to export and share it. Do you want to help out Questie?"
  ))
  frame.AcceptButton:SetText(YES or "Yes")
  frame.DeclineButton:SetText(NO or "No")

  frame.AcceptButton:SetScript("OnClick", function()
    frame:Hide()
    QuestieTrace.settings.dataCollectionConsent = true
    Core.PrintConsentReminder()
    if Core.GetCaptureState() == "idle" then
      Core.StartCapture()
    end
    Core.StartShareReminders()
  end)

  frame.DeclineButton:SetScript("OnClick", function()
    frame:Hide()
    QuestieTrace.settings.dataCollectionConsent = false
    -- Revoking consent discards any active capture, rather than saving it.
    Core.DiscardCapture()
    Core.Print(l10n("You declined data collection. If you change your mind, run \"/qlt consent\"."))
  end)
end

--- Ask for consent without entering Blizzard's shared StaticPopup lists.
--- Those lists can carry addon taint into Edit Mode when creating a layout.
function Core.ShowConsentPrompt()
  consentFrame:Show()
end

--- Print a friendly reminder to chat that gameplay data is being collected locally.
--- Only meaningful (and only ever called) when consent has been granted.
function Core.PrintConsentReminder()
  Core.Print(l10n("Thank you for helping improve Questie! Your gameplay data is being collected locally on this device."))
end

--- Handle consent logic on PLAYER_LOGIN.
--- Shows prompt if undecided, prints reminder and starts capture if consented.
function Core.HandleConsentOnLogin()
  local settings = QuestieTrace and QuestieTrace.settings
  local consent = settings and settings.dataCollectionConsent

  if consent == nil then
    -- First login: ask for permission before collecting anything.
    Core.ShowConsentPrompt()
  elseif consent == true then
    Core.PrintConsentReminder()

    -- Only start if no capture is running and no unsaved session exists
    -- (state is "idle" means neither running nor stopped_unsaved)
    if Core.GetCaptureState() == "idle" then
      Core.StartCapture()
    end

    Core.StartShareReminders()
  -- consent == false: declined; show reminder that data collection is disabled.
  elseif consent == false then
    Core.Print(l10n("Data collection is disabled (previously declined). Use \"/qlt consent\" to re-enable."))
  end
end
