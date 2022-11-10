local DEBUG = true

-- CACHE
local PlayerPedId = PlayerPedId
local PlayerId = PlayerId
local IsPlayerDead = IsPlayerDead
local DoesEntityExist = DoesEntityExist
local GetSeatPedIsTryingToEnter = GetSeatPedIsTryingToEnter
local IsPedInAnyVehicle = IsPedInAnyVehicle
local VehToNet = VehToNet
local IsPedOnMount = IsPedOnMount
local GetMount = GetMount
local NetworkGetNetworkIdFromEntity = NetworkGetNetworkIdFromEntity
local IsPlayerDead = IsPlayerDead

local GetNumberOfEvents = GetNumberOfEvents
local GetEventAtIndex = GetEventAtIndex

local ON_HORSE = false
local CURRENT_HORSE = nil 

local IN_VEHICLE = false
local ENTERING_VEHICLE = false
local CURRENT_VEHICLE = nil
local CURRENT_SEAT = nil
local CURRENT_WEAPON = nil
local HOLDING_WEAPON = false


local function GetPedVehicleSeat(ped)
    local vehicle = GetVehiclePedIsIn(ped, false)
    for i=-2,GetVehicleMaxNumberOfPassengers(vehicle) do
        if(GetPedInVehicleSeat(vehicle, i) == ped) then return i end
    end
    return -2
end

exports("InVehicle", function()
    return IN_VEHICLE
end)

exports("Vehicle", function()
    return CURRENT_VEHICLE
end)

exports("Seat", function()
    return CURRENT_SEAT
end)

exports("Horse", function()
    return CURRENT_HORSE
end)

exports("Weapon", function()
    return CURRENT_WEAPON
end)

exports("HoldingWeapon", function()
    return HOLDING_WEAPON
end)

CreateThread(function()
	while true do

        -- RD2 Events : https://github.com/femga/rdr3_discoveries/blob/master/AI/EVENTS/events.lua
        local size = GetNumberOfEvents(0)
        if size > 0 then
            for i = 0, size - 1 do
                local eventAtIndex = GetEventAtIndex(0, i)
                if EVENTS[eventAtIndex] then
                    if DEBUG then
                        print(EVENTS[eventAtIndex].name)
                    end
                    TriggerEvent("events:listener", EVENTS[eventAtIndex].name, index, eventAtIndex)
                    TriggerServerEvent("events:listener", EVENTS[eventAtIndex].name, index, eventAtIndex)
                end
            end
        end

        local ped = PlayerPedId()
        local id = PlayerId()

        -- Vehicles
        if not IN_VEHICLE and not IsPlayerDead(id) then
			if DoesEntityExist(GetVehiclePedIsEntering(ped)) and not ENTERING_VEHICLE then
				-- trying to enter a vehicle!
				local vehicle = GetVehiclePedIsEntering(ped)
				local seat = GetSeatPedIsTryingToEnter(ped)
				local netId = VehToNet(vehicle)
				ENTERING_VEHICLE = true
                TriggerEvent('events:EnteringVehicle', vehicle, seat, netId)
				TriggerServerEvent('events:EnteringVehicle', vehicle, seat, netId)
                --print(string.format("ATTEMPTING: %s %s %s", vehicle, seat, netId))
			elseif not DoesEntityExist(GetVehiclePedIsEntering(ped)) and not IsPedInAnyVehicle(ped, true) and ENTERING_VEHICLE then
				-- vehicle entering aborted
				TriggerServerEvent('events:EnteringAborted')
				ENTERING_VEHICLE = false
                --print("aborted")
			elseif IsPedInAnyVehicle(ped, false) then
				-- suddenly appeared in a vehicle, possible teleport
				ENTERING_VEHICLE = false
				IN_VEHICLE = true
				CURRENT_VEHICLE = GetVehiclePedIsUsing(ped)
				CURRENT_SEAT = GetPedVehicleSeat(ped)
				local model = GetEntityModel(CURRENT_VEHICLE)
				local netId = VehToNet(CURRENT_VEHICLE)
                --print(string.format("ENTERED: %s %s %s", CURRENT_VEHICLE, CURRENT_SEAT, netId))
                TriggerEvent('events:EnteredVehicle', CURRENT_VEHICLE, CURRENT_SEAT, netId)
				TriggerServerEvent('events:EnteredVehicle', CURRENT_VEHICLE, CURRENT_SEAT, netId)
			end
		elseif IN_VEHICLE then
			if not IsPedInAnyVehicle(ped, false) then
				-- bye, vehicle
				local model = GetEntityModel(CURRENT_VEHICLE)
				local netId = VehToNet(CURRENT_VEHICLE)
                --print(string.format("LEFT: %s %s %s", CURRENT_VEHICLE, CURRENT_SEAT, netId))
                TriggerEvent('events:LeftVehicle', CURRENT_VEHICLE, CURRENT_SEAT, netId)
				TriggerServerEvent('events:LeftVehicle', CURRENT_VEHICLE, CURRENT_SEAT, netId)
				IN_VEHICLE = false
				CURRENT_VEHICLE = 0
				CURRENT_SEAT = 0
			end
		end

        -- Mounts
        if not ON_HORSE and not IsPlayerDead(id) then
            if IsPedOnMount(ped) then
                CURRENT_HORSE = GetMount(ped)
                ON_HORSE = true
                local netId = NetworkGetNetworkIdFromEntity(CURRENT_HORSE)
                TriggerEvent('events:MountOn', netId)
                TriggerServerEvent('events:MountOn', netId)
            end
        elseif ON_HORSE then
            if not IsPedOnMount(ped) then
                local netId = NetworkGetNetworkIdFromEntity(CURRENT_HORSE)
                TriggerEvent('events:MountOff', netId)
                TriggerServerEvent('events:MountOff', netId)
                ON_HORSE = false
                CURRENT_HORSE = nil
            end
        end

        Wait(0)
	end
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local weapon = Citizen.InvokeNative(0x8425C5F057012DAB, ped)
        if not HOLDING_WEAPON and not IsPlayerDead(ped) and weapon ~= `WEAPON_UNARMED`then
            HOLDING_WEAPON = true
            CURRENT_WEAPON = weapon
            TriggerEvent('events:holdingWeapon', weapon)
            TriggerServerEvent('events:holdingWeapon', weapon)
        elseif HOLDING_WEAPON and not IsPlayerDead(PlayerPed) and weapon == `WEAPON_UNARMED` then
            TriggerEvent('events:holsterWeapon', weapon)
            TriggerServerEvent('events:holsterWeapon', weapon)
            CURRENT_WEAPON = nil
            HOLDING_WEAPON = false
        end
        Wait(300)
    end
end)