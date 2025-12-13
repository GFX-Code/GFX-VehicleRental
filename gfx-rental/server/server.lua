local QBCore = exports['qb-core']:GetCoreObject()
local playerKeyPlates = {}
local rentedVehicles = {}
local activeRentals = {}

local function ProtectedEvent()
    local res = GetInvokingResource()
    if res and res ~= GetCurrentResourceName() then
        print(("^1[ANTI-EXPLOIT] Blocked unauthorized event call from resource: %s^0"):format(res))
        return false
    end
    return true
end

local function GeneratePlate()
    return "RENT"..math.random(1000,9999)
end

RegisterNetEvent("gfx-rental:server:startRental", function(car)
    if not ProtectedEvent() then return end
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not car then return end

    if not Player.Functions.RemoveMoney("cash", car.price) then
        TriggerClientEvent("QBCore:Notify", src, "Not enough money.", "error")
        return
    end

    local plate = GeneratePlate()

    playerKeyPlates[src] = playerKeyPlates[src] or {}
    table.insert(playerKeyPlates[src], plate)

    Player.Functions.AddItem("vehiclekeys", 1, false, { plate = plate })
    if Config.RentalItem then
        Player.Functions.AddItem(Config.RentalItem, 1, false, { plate = plate })
    end

    rentedVehicles[plate] = car.price
    activeRentals[src] = activeRentals[src] or {}
    activeRentals[src][plate] = true

    TriggerClientEvent("gfx-rental:client:spawnVehicle", src, { car = car, plate = plate, price = car.price })
end)

RegisterNetEvent("gfx-rental:server:refundOnClientFail", function(plate)
    if not ProtectedEvent() then return end
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not plate then return end

    local price = rentedVehicles[plate] or 0
    if price > 0 then
        Player.Functions.AddMoney("cash", price)
        TriggerClientEvent("QBCore:Notify", src, "Payment refunded due to spawn block.", "error")
    end

    rentedVehicles[plate] = nil
    if activeRentals[src] then activeRentals[src][plate] = nil end
    if playerKeyPlates[src] then
        for i, p in ipairs(playerKeyPlates[src]) do
            if p == plate then table.remove(playerKeyPlates[src], i); break end
        end
    end
end)

RegisterNetEvent("gfx-rental:server:attemptReturn", function(plate)
    if not ProtectedEvent() then return end
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not plate then return end

    if not activeRentals[src] or not activeRentals[src][plate] then
        TriggerClientEvent("QBCore:Notify", src, "You do not have this rented vehicle.", "error")
        return
    end

    local hasKeys, hasPapers = false, false
    for _, item in pairs(Player.PlayerData.items or {}) do
        local itemPlate = (item.info and item.info.plate) or (item.metadata and item.metadata.plate)
        if item.name == "vehiclekeys" and itemPlate == plate then hasKeys = true end
        if item.name == Config.RentalItem and itemPlate == plate then hasPapers = true end
    end

    if not hasKeys or not hasPapers then
        TriggerClientEvent("QBCore:Notify", src, "You are missing keys or rental papers.", "error")
        return
    end

    local price = rentedVehicles[plate] or 0
    local refund = math.floor(price * 0.5)
    Player.Functions.AddMoney("cash", refund)
    TriggerClientEvent("QBCore:Notify", src, "Vehicle returned. You received $"..refund.." back.", "success")

    for _, item in pairs(Player.PlayerData.items or {}) do
        local itemPlate = (item.info and item.info.plate) or (item.metadata and item.metadata.plate)
        if item.name == "vehiclekeys" and itemPlate == plate then
            Player.Functions.RemoveItem(item.name, 1, item.slot)
            break
        end
    end
    if Config.RentalItem then
        for _, item in pairs(Player.PlayerData.items or {}) do
            local itemPlate = (item.info and item.info.plate) or (item.metadata and item.metadata.plate)
            if item.name == Config.RentalItem and itemPlate == plate then
                Player.Functions.RemoveItem(item.name, 1, item.slot)
                break
            end
        end
    end

    TriggerClientEvent("gfx-rental:client:deleteVehicle", src, plate)

    rentedVehicles[plate] = nil
    if activeRentals[src] then activeRentals[src][plate] = nil end
    if playerKeyPlates[src] then
        for i, p in ipairs(playerKeyPlates[src]) do
            if p == plate then table.remove(playerKeyPlates[src], i); break end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    if playerKeyPlates[src] then
        for _, plate in ipairs(playerKeyPlates[src]) do
            rentedVehicles[plate] = nil
        end
    end
    playerKeyPlates[src] = nil
    activeRentals[src] = nil
end)
