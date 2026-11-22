-- Pre-rendered boss portraits.
-- Every creature portrait the journal shows was photographed once in-game
-- (black + white backgrounds, so the round edge keeps its exact alpha) and is
-- bundled here as Media\\Portraits\\<displayID>.tga. Bundled portraits appear
-- instantly instead of being rendered from the 3D model on first open.
-- Any display ID not in the list still goes through the live renderer.
local FDJ = _G.ForeverDungeonJournal_NS
if not FDJ then return end

local PATH = "Interface\\AddOns\\ForeverDungeonJournal\\Media\\Portraits\\"
FDJ.BAKED_PORTRAITS = {
    [414]=true, [517]=true, [522]=true, [523]=true, [524]=true, [556]=true, [559]=true, [571]=true, [825]=true, [1065]=true, [1131]=true, [1204]=true,
    [1267]=true, [1269]=true, [1305]=true, [1621]=true, [1693]=true, [1773]=true, [1816]=true, [1951]=true, [2007]=true, [2026]=true, [2029]=true, [2040]=true,
    [2041]=true, [2042]=true, [2043]=true, [2044]=true, [2142]=true, [2149]=true, [2172]=true, [2314]=true, [2316]=true, [2318]=true, [2347]=true, [2349]=true,
    [2352]=true, [2353]=true, [2438]=true, [2440]=true, [2447]=true, [2450]=true, [2605]=true, [2606]=true, [2837]=true, [3004]=true, [3222]=true, [3223]=true,
    [3224]=true, [3250]=true, [4088]=true, [4203]=true, [4211]=true, [4213]=true, [4214]=true, [4215]=true, [4256]=true, [4313]=true, [4642]=true, [4644]=true,
    [4652]=true, [4735]=true, [4939]=true, [4979]=true, [5027]=true, [5126]=true, [5230]=true, [5231]=true, [5266]=true, [5489]=true, [5497]=true, [5534]=true,
    [5710]=true, [5781]=true, [5945]=true, [5988]=true, [6059]=true, [6089]=true, [6097]=true, [6102]=true, [6110]=true, [6375]=true, [6434]=true, [6439]=true,
    [6441]=true, [6669]=true, [6708]=true, [6709]=true, [6774]=true, [6915]=true, [6980]=true, [7109]=true, [7113]=true, [7124]=true, [7125]=true, [7271]=true,
    [7353]=true, [7534]=true, [7550]=true, [7553]=true, [7555]=true, [7806]=true, [7845]=true, [7848]=true, [7856]=true, [7864]=true, [7873]=true, [7919]=true,
    [7970]=true, [7975]=true, [8053]=true, [8055]=true, [8177]=true, [8270]=true, [8271]=true, [8329]=true, [8652]=true, [8658]=true, [8667]=true, [8704]=true,
    [8705]=true, [8711]=true, [8756]=true, [8759]=true, [8760]=true, [8761]=true, [8762]=true, [8807]=true, [9014]=true, [9089]=true, [9212]=true, [9292]=true,
    [9293]=true, [9564]=true, [9567]=true, [9581]=true, [9584]=true, [9668]=true, [9686]=true, [9732]=true, [9733]=true, [9738]=true, [9755]=true, [9778]=true,
    [9783]=true, [9785]=true, [9786]=true, [9793]=true, [9806]=true, [9929]=true, [10115]=true, [10193]=true, [10222]=true, [10248]=true, [10433]=true, [10482]=true,
    [10544]=true, [10546]=true, [10669]=true, [10674]=true, [10691]=true, [10698]=true, [10728]=true, [10729]=true, [10771]=true, [10798]=true, [10901]=true, [11069]=true,
    [11070]=true, [11072]=true, [11073]=true, [11165]=true, [11172]=true, [11179]=true, [11250]=true, [11256]=true, [11270]=true, [11335]=true, [11382]=true, [11396]=true,
    [11429]=true, [11492]=true, [11537]=true, [11538]=true, [11545]=true, [11561]=true, [11564]=true, [11565]=true, [11574]=true, [11576]=true, [11578]=true, [11583]=true,
    [11611]=true, [11809]=true, [11835]=true, [12073]=true, [12162]=true, [12292]=true, [12293]=true, [12334]=true, [12350]=true, [12389]=true, [12818]=true, [12822]=true,
    [13589]=true, [14173]=true, [14308]=true, [14378]=true, [14383]=true, [14384]=true, [14403]=true, [14416]=true, [14556]=true,
    -- (144378, Grubbis: the picture cut by hand from a screenshot in 2.0.6 is
    -- out, M 16 Nov 2026, "looks really bad"; baked again below, bake2.)
    -- bakeall (2.0.9, M 15 Nov 2026: "find a solution to these portraits...
    -- they look nice, but they are heavy"): every look the journal still had
    -- the game draw, photographed in M's game with /dj bake (15 Nov 2026,
    -- 1920 x 1080; lossless screenshots, on black and on white), so no
    -- portrait of a known creature is a render target any more. 2: there is
    -- a 128-pixel picture too (Media\\Portraits\\128), for where the portrait
    -- is shown large (the boss looks).
    [110]=2, [200]=true, [487]=true, [519]=true, [545]=true, [612]=true, [807]=true, [960]=true, [1035]=true, [1045]=true, [1088]=true, [1337]=true,
    [1339]=true, [2021]=true, [2317]=2, [2424]=2, [2426]=true, [2460]=true, [2462]=true, [2463]=true, [2476]=true, [2497]=true, [2499]=true, [2501]=true,
    [2507]=true, [2511]=true, [2514]=true, [2522]=true, [2603]=true, [2875]=true, [3024]=true, [3942]=true, [4065]=true, [4764]=true, [4973]=2, [4975]=true,
    [5233]=true, [5285]=2, [6078]=true, [6124]=2, [6195]=true, [6374]=2, [6433]=2, [6671]=true, [6685]=2, [6687]=2, [6690]=2, [6696]=2,
    [6698]=2, [6699]=2, [6700]=2, [6701]=2, [6702]=2, [6707]=2, [6841]=true, [7112]=true, [7114]=true, [7533]=true, [7549]=true, [7552]=2,
    [7847]=true, [7914]=2, [7971]=2, [8681]=true, [8687]=2, [8782]=true, [8803]=true, [8812]=true, [8894]=true, [9010]=2, [9233]=true, [9291]=2,
    [9633]=true, [9656]=true, [9660]=true, [9734]=true, [9758]=true, [9760]=true, [9788]=true, [10032]=true, [10458]=2, [10475]=2, [10484]=true, [10490]=true,
    [10495]=true, [10497]=true, [10500]=true, [10504]=true, [10509]=true, [10515]=true, [10516]=true, [10530]=true, [10534]=true, [10542]=true, [10626]=true, [10632]=true,
    [11071]=true, [11124]=true, [11126]=true, [11155]=true, [11161]=true, [11177]=true, [11315]=true, [11397]=true, [11489]=true, [11579]=true, [11582]=true, [12074]=true,
    [12235]=2, [12819]=true, [14272]=true, [14424]=2, [14591]=2, [15981]=2, [16020]=2, [17273]=2, [129891]=2, [129894]=2, [129895]=2, [129900]=2,
    [129945]=2, [129954]=2, [130061]=2, [130102]=true, [130208]=true, [130218]=true, [130220]=2, [130223]=true, [130224]=true, [130235]=2, [130427]=2, [130432]=2,
    [130436]=2, [130440]=2, [130447]=2, [131644]=2, [138667]=2, [138722]=true, [138843]=true, [139455]=2, [140001]=true, [140092]=2, [140708]=2, [141215]=2,
    [141217]=2, [141218]=2, [141219]=2, [141443]=2, [142144]=2, [142245]=2, [142322]=2, [142457]=2, [142826]=2, [142837]=2, [142840]=2, [142989]=2,
    [143035]=2, [143039]=2, [143040]=2, [143063]=2, [143122]=2, [143142]=true, [143673]=2, [143832]=2, [144022]=2, [144023]=2, [144170]=2, [144175]=2,
    -- bake2 (2.0.9, M 16 Nov 2026, /dj bake again): the looks added since,
    -- Grubbis's new picture among them (both sizes).
    [2078]=2, [4972]=2, [5047]=2, [6350]=2, [10315]=2, [10751]=2, [11345]=2, [12929]=2, [13109]=2, [13489]=2, [14253]=2, [14254]=2,
    [15997]=2, [16003]=2, [16018]=2, [144378]=2,
    [144188]=2, [144189]=2, [144209]=2, [144210]=2, [144224]=2, [144356]=true, [144475]=2, [144487]=2, [144511]=2, [144514]=2, [144515]=2, [145398]=true,
    [145404]=true, [145787]=2, [145808]=2, [145809]=true, [147098]=2,
    -- bake3 (2.1.1, M 20 Nov 2026, /dj bake): Krol'dok Stronghold's quest mobs
    -- Tunk and Zalfan Moonshadow (both sizes).
    [144671]=2, [145448]=2,
    -- bake4 (2.1.1, M 20 Nov 2026, /dj bake): Isalien, Dire Maul East's
    -- Dungeon Set 2 boss (both sizes).
    [16000]=2,
    -- bake5 (2.1.2, M 21 Nov 2026, /dj bake): Sabella No-Eyes, Blackmaw
    -- Hold's rare (both sizes).
    [6829]=2,
}
local BAKED = FDJ.BAKED_PORTRAITS

-- bakeall (2.0.9): the game draws a portrait as large as it is shown, so a
-- 64-pixel picture is soft where the portrait is larger than that on screen
-- (the selected boss's, a large journal, a high resolution). There the
-- 128-pixel picture is used, where there is one; smaller ones keep the
-- 64-pixel picture (a 128 one shrunk that far would shimmer).
local function ShownLarge(texture)
    local width = texture:GetWidth() or 0
    local parent = texture:GetParent()
    local scale = parent and parent.GetEffectiveScale and parent:GetEffectiveScale() or 1
    local height = 1080
    if type(GetPhysicalScreenSize) == "function" then
        local _, h = GetPhysicalScreenSize()
        if tonumber(h) and h > 0 then height = h end
    end
    return width * scale * height / 768 > 64
end
local function PicturePath(texture, displayID)
    if BAKED[displayID] == 2 then
        local ok, large = pcall(ShownLarge, texture)
        if ok and large then return PATH .. "128\\" .. displayID end
    end
    return PATH .. displayID
end
FDJ.BakedPortraitPath = PicturePath

function FDJ.SetBakedPortrait(texture, displayID)
    if not texture or type(displayID) ~= "number" or not BAKED[displayID] then return false end
    texture:SetTexture(PicturePath(texture, displayID))
    return true
end

local liveAcquire = FDJ.AcquirePortrait
FDJ.AcquirePortrait = function(host, displayID)
    if host and type(displayID) == "number" and BAKED[displayID] then
        if FDJ.ReleasePortrait then pcall(FDJ.ReleasePortrait, host) end
        host:SetTexture(PicturePath(host, displayID))
        host:SetAlpha(1)
        return true
    end
    if liveAcquire then return liveAcquire(host, displayID) end
    return false
end

