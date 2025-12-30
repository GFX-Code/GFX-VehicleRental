local QBCore = exports['qb-core']:GetCoreObject()
local spawnedVehicles = {}
local rentalPeds = {}
local playerCooldown = false
local COOLDOWN_TIME = 5

local function IsSpawnClear(coords, radius)
    local vehicles = GetGamePool("CVehicle")
    for _, v in ipairs(vehicles) do
        if DoesEntityExist(v) and #(GetEntityCoords(v) - coords) <= radius then
            return false
        end
    end
    return true
end

local function SpawnRentalPed(coords, heading)
    local pedModel = GetHashKey(Config.PedModel)
    RequestModel(pedModel)
    while not HasModelLoaded(pedModel) do Wait(10) end

    local ped = CreatePed(4, pedModel, coords.x, coords.y, coords.z - 1, 0.0, false, true)

    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedCanEvasiveDive(ped, false)
    SetPedFleeAttributes(ped, 0, false)

    local modelOffset = 60.0 
    SetEntityHeading(ped, heading + modelOffset)

    TaskStartScenarioInPlace(ped, "WORLD_HUMAN_CLIPBOARD", 0, true)

    FreezeEntityPosition(ped, true)
    SetModelAsNoLongerNeeded(pedModel)

    return ped
end

RegisterNetEvent("gfx-rental:client:spawnVehicle", function(vehicleData)
    local car = vehicleData.car
    local plate = vehicleData.plate
    local price = vehicleData.price
    local coords = car.spawn.xyz
    local heading = car.spawn.w

    if not IsSpawnClear(coords, 3.0) then
        TriggerServerEvent("gfx-rental:server:refundOnClientFail", plate)
        QBCore.Functions.Notify("Spawn blocked! Area occupied.", "error")
        return
    end

    local modelHash = GetHashKey(car.model)
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do Wait(10) end

    local veh = CreateVehicle(modelHash, coords.x, coords.y, coords.z, heading, true, true)
    if DoesEntityExist(veh) then
        SetVehicleNumberPlateText(veh, plate)
        SetVehicleHasBeenOwnedByPlayer(veh, true)
        SetEntityAsMissionEntity(veh, true, true)
        SetVehicleDoorsLocked(veh, 1)

        -- Give keys after vehicle is spawned
        if Config.VehicleKeys == 'renewed' then
            exports['Renewed-Vehiclekeys']:addKey(plate)
        elseif Config.VehicleKeys == 'qbx' then
            -- Wait for vehicle to be networked then give keys on server
            local netId = NetworkGetNetworkIdFromEntity(veh)
            TriggerServerEvent("gfx-rental:server:giveKeysAfterSpawn", plate, netId)
        end

        table.insert(spawnedVehicles, { vehicle = veh, plate = plate, model = car.model, price = price })
        QBCore.Functions.Notify("Rental successful!", "success")
    else
        TriggerServerEvent("gfx-rental:server:refundOnClientFail", plate)
        QBCore.Functions.Notify("Vehicle spawn failed.", "error")
    end
end)

local function RentVehicle(car)
    if playerCooldown then
        QBCore.Functions.Notify("Please wait before renting another vehicle.", "error")
        return
    end

    local coords = car.spawn.xyz
    if not IsSpawnClear(coords, 3.0) then
        QBCore.Functions.Notify("Spawn area blocked! Move any vehicles first.", "error")
        return
    end

    TriggerServerEvent("gfx-rental:server:startRental", car)

    playerCooldown = true
    CreateThread(function()
        Wait(COOLDOWN_TIME * 1000)
        playerCooldown = false
    end)
end

local function ReturnVehicle()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    local closestVeh = nil
    local closestDist = 5.0
    local plateToReturn = nil

    for _, data in ipairs(spawnedVehicles) do
        local veh = data.vehicle
        if DoesEntityExist(veh) then
            local dist = #(playerCoords - GetEntityCoords(veh))
            if dist < closestDist then
                closestDist = dist
                closestVeh = veh
                plateToReturn = data.plate
            end
        end
    end

    if not closestVeh or not plateToReturn then
        QBCore.Functions.Notify("No rented vehicle nearby to return.", "error")
        return
    end

    TriggerServerEvent("gfx-rental:server:attemptReturn", plateToReturn)
end

RegisterNetEvent("gfx-rental:client:deleteVehicle", function(plate)
    for i, data in ipairs(spawnedVehicles) do
        if data.plate == plate and DoesEntityExist(data.vehicle) then
            SetEntityAsMissionEntity(data.vehicle, true, true)
            DeleteVehicle(data.vehicle)
            table.remove(spawnedVehicles, i)
            break
        end
    end
end)

CreateThread(function()
    for _, data in ipairs(Config.RentalLocations) do
        local loc = data.coords
        local ped = SpawnRentalPed(loc, 0.0)
        rentalPeds[#rentalPeds + 1] = ped

        if data.blip then
            local blip = AddBlipForCoord(loc.x, loc.y, loc.z)
            SetBlipSprite(blip, data.blip)
            SetBlipColour(blip, data.colour or 3)
            SetBlipScale(blip, data.scale or 0.7)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString("Vehicle Rental")
            EndTextCommandSetBlipName(blip)
        end

        local options = {}
        for _, car in ipairs(Config.Cars) do
            options[#options + 1] = {
                name = "rent_" .. car.name,
                icon = "fa-solid fa-car",
                label = "Rent: "..car.name.." ($"..car.price..")",
                distance = 2.5,
                onSelect = function() RentVehicle(car) end
            }
        end
        options[#options + 1] = {
            name = "return_vehicle",
            icon = "fa-solid fa-arrow-left",
            label = "Return Vehicle (50% refund)",
            distance = 2.5,
            onSelect = ReturnVehicle
        }

        exports.ox_target:addLocalEntity(ped, options)
    end
end)