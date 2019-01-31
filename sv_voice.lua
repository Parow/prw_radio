-------------------------------------------------------
----------------RADIO MADE BY PAROW--------------------
-------------------------------------------------------
local voip = {}
RegisterNetEvent('parow:ToggleRadio')
AddEventHandler('parow:ToggleRadio', function(freq,checked)
	for i = 1, #voip,1 do
		if voip[i].freq == freq then
			TriggerClientEvent("parow:mute",source,checked,voip[i].source)
		end
	end
end)
RegisterNetEvent('parow:SetFreq')
AddEventHandler('parow:SetFreq', function(freq)
	local found = true
	local k = 0
	for i = 1, #voip,1 do
		if voip[i].source == source then
			found = false
			k = i
			for p = 1, #voip,1 do
				TriggerClientEvent("parow:SyncRadio",voip[p].source,voip,false)
			end
			break
		end
	end
	if found then
		table.insert(voip,{source=source, freq=freq}) 
	else 
		voip[k].freq = freq
	end
	for i = 1, #voip,1 do
		if voip[i].freq == freq then
			TriggerClientEvent("parow:SyncRadio",voip[i].source,voip,true)
		end
	end
end)
