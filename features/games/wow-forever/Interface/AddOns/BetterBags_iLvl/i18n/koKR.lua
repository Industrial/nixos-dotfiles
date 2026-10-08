if(GetLocale() ~= 'koKR') then
    return
end

local _, ns = ...
local L = ns.L

L["CATEGORY_NAME"] = "낮은 iLvl";
L["OPTIONS_DESC"] = "이 카테고리에 대한 iLvl 기준값을 선택하세요 (이 값보다 iLvl이 낮은 모든 아이템이 이 카테고리에 배치됩니다). 값을 변경한 후에는 UI 리로드가 필요할 수 있습니다.";
L["OPTIONS_INCLUDE_JUNK"] = "품질이 낮은 아이템을 이 카테고리에 포함";
L["OPTIONS_REFRESH"] = "UI 다시 불러오기";
L["OPTIONS_RESET_DEFAULT"] = "기본값으로 재설정";
L["OPTIONS_THRESHOLD"] = "iLvl 기준값 (기본값: _default_)";
L["OPTIONS_THRESHOLD_ERROR"] = "iLvl 기준값으로 유효한 숫자를 입력하세요.";
L["OPTIONS_DYNAMIC_TOGGLE"] = "평균 착용 iLvl을 기준으로 한 동적 기준값 사용";
L["OPTIONS_DYNAMIC_TOGGLE_ACTIVE"] = "평균 착용 iLvl을 기준으로 한 동적 기준값 사용 (현재: _value_)";
L["OPTIONS_DYNAMIC_TOGGLE_DESC"] = "활성화하면 iLvl 기준값이 평균 착용 아이템 레벨을 기준으로 자동 계산됩니다. 이 설정을 변경할 때마다, 그리고 로그인하거나 UI를 다시 불러올 때마다 다시 계산되며, 플레이 중에는 자동으로 변경되지 않습니다.";
L["OPTIONS_DYNAMIC_OFFSET"] = "평균값보다 낮은 iLvl 차이 (기본값: _default_)";
L["OPTIONS_DYNAMIC_OFFSET_DESC"] = "평균 착용 아이템 레벨보다 이 값 이상 낮은 iLvl을 가진 아이템이 이 카테고리에 배치됩니다.";
L["OPTIONS_USE_MAX_ILVL"] = "아이템의 현재 iLvl 대신 (업그레이드 가능한 경우) 도달 가능한 최대 iLvl 사용";
L["OPTIONS_USE_MAX_ILVL_DESC"] = "활성화하면 아직 업그레이드할 수 있는 아이템은 현재 iLvl이 아니라 최대로 업그레이드했을 때 도달할 수 있는 iLvl을 기준으로 비교됩니다. 업그레이드할 수 없는 아이템은 영향을 받지 않습니다.";
