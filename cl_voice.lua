local VoiceMode = {
	{ dist = 3, message = "Voice range set on 3 meters." },
	{ dist = 8, message = "Voice range set on 8 meters." },
	{ dist = 14, message = "Voice range set on 14 meters." },
	{ veh = true, dist = 4, func = function(ped) return IsPedInAnyVehicle(ped) end, message = "Voice range set to your vehicle." },
}
local Keys = {
    ["ESC"] = 322, ["F1"] = 288, ["F2"] = 289, ["F3"] = 170, ["F5"] = 166, ["F6"] = 167, ["F7"] = 168, ["F8"] = 169, ["F9"] = 56, ["F10"] = 57,
    ["~"] = 243, ["1"] = 157, ["2"] = 158, ["3"] = 160, ["4"] = 164, ["5"] = 165, ["6"] = 159, ["7"] = 161, ["8"] = 162, ["9"] = 163, ["-"] = 84, ["="] = 83, ["BACKSPACE"] = 177,
    ["TAB"] = 37, ["Q"] = 44, ["W"] = 32, ["E"] = 38, ["R"] = 45, ["T"] = 245, ["Y"] = 246, ["U"] = 303, ["P"] = 199, ["["] = 39, ["]"] = 40, ["ENTER"] = 18,
    ["CAPS"] = 137, ["A"] = 34, ["S"] = 8, ["D"] = 9, ["F"] = 23, ["G"] = 47, ["H"] = 74, ["K"] = 311, ["L"] = 182,
    ["LEFTSHIFT"] = 21, ["Z"] = 20, ["X"] = 73, ["C"] = 26, ["V"] = 0, ["B"] = 29, ["N"] = 249, ["M"] = 244, [","] = 82, ["."] = 81,
    ["LEFTCTRL"] = 36, ["LEFTALT"] = 19, ["SPACE"] = 22, ["RIGHTCTRL"] = 70,
    ["HOME"] = 213, ["PAGEUP"] = 10, ["PAGEDOWN"] = 11, ["DELETE"] = 178,
    ["LEFT"] = 174, ["RIGHT"] = 175, ["TOP"] = 27, ["DOWN"] = 173,
    ["NENTER"] = 201, ["N4"] = 108, ["N5"] = 60, ["N6"] = 107, ["N+"] = 96, ["N-"] = 97, ["N7"] = 117, ["N8"] = 61, ["N9"] = 118
}
local Voice = {}
Voice.Listeners = {}
Voice.ListenersRadio = {}
Voice.Mode = 2
Voice.distance = 8.0
local currentFreq
Voice.onlyVehicle = false
local muted = false
local function SendVoiceToPlayer(intPlayer, boolSend)
	Citizen.InvokeNative(0x97DD4C5944CC2E6A, intPlayer, boolSend)
end

local function GetPlayers()
	local players = {}
	for i = 0, 64 do
		if NetworkIsPlayerActive(i) then
			players[#players + 1] = i
		end
	end
	return players
end
function round2(num, numDecimalPlaces)
  return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
end
function Voice:UpdateVoices()

--print(json.encode(Voice.Listeners))
	local ped = GetPlayerPed(-1)
	local InVeh = IsPedInAnyVehicle(ped)

	if Voice.onlyVehicle and not InVeh then
		Voice.Mode = 1
		Voice:OnModeModified()
	end

	for _,v in pairs(GetPlayers()) do
		
		local otherPed, serverID = GetPlayerPed(v), GetPlayerServerId(v)
		if otherPed and Voice:CanPedBeListened(ped, otherPed) or  Voice.ListenersRadio[serverID] == true then
			if not Voice.Listeners[serverID] then
				Voice.Listeners[serverID] = true
			end
			if Voice.ListenersRadio[serverID] ~= true then
			--	print(v)
				SendVoiceToPlayer(v, true)
			elseif Voice.ListenersRadio[serverID] then
				local playerIdx = GetPlayerFromServerId(serverID)
			
				SendVoiceToPlayer(playerIdx,true)
			else
				SendVoiceToPlayer(v, true)
			end
		elseif Voice.Listeners[serverID] then
			Voice.Listeners[serverID] = false
			SendVoiceToPlayer(v, false)
		elseif Voice.ListenersRadio[serverID] ~= true  then
			local playerIdx = GetPlayerFromServerId(serverID)
			
			SendVoiceToPlayer(playerIdx,false)
	
		end
	end
	
	if Voice.onlyVehicle and not InVeh then
		Voice.Mode = 1
		Voice:OnModeModified()
	end
end

local function ShowAboveRadarMessage(message)
	SetNotificationTextEntry("jamyfafi")
	AddTextComponentString(message)
	return DrawNotification(0, 1)
end

local notifID
function Voice:OnModeModified()
	local modeData = VoiceMode[self.Mode]
	if modeData then
		self.distance = modeData.dist
		self.onlyVehicle = modeData.veh
		if modeData.message then
			if notifID then RemoveNotification(notifID) end
			notifID = ShowAboveRadarMessage(modeData.message)
			Citizen.SetTimeout(4000, function() if notifID then RemoveNotification(notifID) end end)
		end

		self:UpdateVoices()
	end
end

function Voice:CanPedBeListened(ped, otherPed)
	local listenerHeadPos, InSameVeh = GetPedBoneCoords(otherPed, 12844, .0, .0, .0), IsPedInAnyVehicle(ped) and GetVehiclePedIsUsing(ped) == GetVehiclePedIsUsing(otherPed)
	local distance = GetDistanceBetweenCoords(listenerHeadPos, GetEntityCoords(ped))

	local bypassVOIP, checkDistance = InSameVeh, self.distance
	return bypassVOIP or (not self.onlyVehicle and (HasEntityClearLosToEntityInFront(ped, otherPed) or distance < (math.max(0, math.min(18, checkDistance)) * .6)) and distance < checkDistance)
end

function Voice:ShouldSendVoice()
	return NetworkIsPlayerTalking(PlayerId()) or IsControlPressed(0, 249)
end

local shouldReset = false
Citizen.CreateThread(function()
	for i = 0, 63 do SendVoiceToPlayer(i, false) end
	NetworkSetTalkerProximity(-1000.0)

	while true do
		Citizen.Wait(300)

		local sendVoice = Voice:ShouldSendVoice()
		if sendVoice then
			if not shouldReset then
				shouldReset = true
			end
		elseif not sendVoice and shouldReset then
			shouldReset = false
			for i = 0, 63 do

				SendVoiceToPlayer(i, false)
			end
		end

		Voice:UpdateVoices()
	end
end)

local function DrawText3D(x,y,z, canSee)
	local _, _, _ = World3dToScreen2d(x,y,z)
	local px, py, pz = table.unpack(GetGameplayCamCoords())
	local dist = GetDistanceBetweenCoords(px,py,pz, x,y,z, 1)

	local scale = ( 1 / dist ) * 20
	scale = scale * ( ( 1 / GetGameplayCamFov() ) * 100 )

	local color = canSee and {0, 70, 200} or {255, 255, 255}
	SetDrawOrigin(x,y,z, 0)
	DrawRect(.0, .02, .0003 * scale, .0375 * scale, color[1], color[2], color[3], 255)
	ClearDrawOrigin()
end

local function UpdateVocalMode(mode)
	local nextMode = mode or Voice.Mode + 1
	while not VoiceMode[nextMode] or (VoiceMode[nextMode] and VoiceMode[nextMode].func and not VoiceMode[nextMode].func(GetPlayerPed(-1))) do
		nextMode = VoiceMode[nextMode + 1] or 1
	end

	Voice.Mode = nextMode
	Voice:OnModeModified()
end
RegisterNetEvent('parow:mute')
AddEventHandler('parow:mute', function(bool,sour)

	Voice.ListenersRadio[sour] = bool
end)
RegisterNetEvent('parow:SyncRadio')
AddEventHandler('parow:SyncRadio', function(azz,bool)
	for i = 1,#azz,1 do
		Voice.ListenersRadio[azz[i].source] = bool

	end
end)
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)

		if IsControlJustPressed(1, 56) then
			UpdateVocalMode()
		end
        if IsControlPressed(0, Keys["LEFTCTRL"]) and IsControlPressed(0, Keys["H"]) then

            OpenRadioMenu()
        end
		if IsControlPressed(1, 56) then
			
			local ped = GetPlayerPed(-1)
			local headPos = GetPedBoneCoords(ped, 12844, .0, .0, .0)

			for _,v in pairs(GetPlayers()) do
				local otherPed = GetPlayerPed(v)
				if otherPed and Voice.Listeners[GetPlayerServerId(v)] then
					local entPos = GetEntityCoords(otherPed)
					DrawText3D(entPos.x, entPos.y, entPos.z, true)
				end
			end

			local distance = Voice.distance + .0
			DrawMarker(28, headPos, 0.0, 0.0, 0.0, 0.0, 0.0, .0, distance + .0, distance + .0, distance + .0, 20, 192, 255, 70, 0, 0, 2, 0, 0, 0, 0)
		end
	end
end)
RegisterNetEvent('parow:SyncRadio2')
AddEventHandler('parow:SyncRadio2', function(azz)
--	print(json.encode(azz))
	for i = 1,#azz,1 do
	--	print(azz[i].freq)
	--	print(CurrentFreq)
		if azz[i].freq == currentFreq then
			Voice.ListenersRadio[azz[i].source] = true
		else
			Voice.ListenersRadio[azz[i].source] = false
		end

	end
end)

--------
--MENU--
--------
local _menuPool = NativeUI.CreatePool()
_menuPool:RefreshIndex()
local radioMenu = nil
local muet = true
local ppks = nil
local freq = nil
function OpenRadioMenu()

    if radioMenu == nil then
        radioMenu = NativeUI.CreateMenu("Radio", "Frequency", 5, 200)
        _menuPool:Add(radioMenu)

		AddRadioMenu(radioMenu)
		radioMenu:Visible(true)
    end
    if not _menuPool:IsAnyMenuOpen() then
		radioMenu:Visible(true)
    else
        _menuPool:CloseAllMenus()
    end
end
function AddRadioMenu(menu)

    pp = NativeUI.CreateItem('Frequency', "")
    pp:RightLabel(freq)
    menu:AddItem(pp)
    menu.OnItemSelect = function(m, i, ind)
        if ind == 1 then
            drawnotifcolor("Frequency range incorrect (range 0 to 100)", 26)
            dm = gettxt2(freq)
            drawnotifcolor("Frequency preset : " .. tostring(dm), 18)
            dm = tonumber(dm)
            if dm ~= nil then
                if dm > 0 then
                    dm = round2(dm, 2)
                    if dm <= 100 then
                        if freq == nil then
                            vali = NativeUI.CreateItem("Valider", "")
                            m:AddItem(vali)
                            _menuPool:RefreshIndex()
                            m:CurrentSelection(ind - 1)
                        end
                        freq = tonumber(dm)
						
                        pp:RightLabel(dm)
                    else
                        drawnotifcolor("Frequency range incorrect (range 0 to 100)", 6)
                    end
                end
            end
        end

        if ind == 2 then
            drawnotifcolor("Frequency set to " .. freq, 18)
            TriggerServerEvent("parow:SetFreq", freq)
			_menuPool:RefreshIndex()
			if ppks == nil then
			--menu:RemoveItemAt(3)
				currentFreq = freq
			ppks = NativeUI.CreateCheckboxItem('Radio status', muet, "")
            menu:AddItem(ppks)
			_menuPool:RefreshIndex()
			end
        end

    end

    menu.OnCheckboxChange = function(_, _, checked)
        TriggerServerEvent("parow:ToggleRadio", freq, checked)
    end
    _menuPool:RefreshIndex()
end



function drawnotifcolor(text, color)
    Citizen.InvokeNative(0x92F0DA1E27DB96DC, tonumber(color))
    SetNotificationTextEntry("STRING")
    AddTextComponentString(text)
    DrawNotification(false, true)
end



function gettxt2(txtt)
    AddTextEntry('FMMC_MPM_NA', "Texte")
    DisplayOnscreenKeyboard(1, "FMMC_MPM_NA", "", txtt, "", "", "", 100)
    while (UpdateOnscreenKeyboard() == 0) do
        DisableAllControlActions(0);
        Wait(0);
    end
    if (GetOnscreenKeyboardResult()) then
		local result = GetOnscreenKeyboardResult()
		if tonumber(result) ~= nil then
			if tonumber(result) > 1 then
				return result
			else

			end
		else
		return result
		end
    end

end
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)
		_menuPool:ProcessMenus()
	end
end)
