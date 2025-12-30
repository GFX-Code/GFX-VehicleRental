Config = {}

Config.RentalItem = "rental_papers"

-- Vehicle Keys System: 'qbx' = qbx_vehiclekeys (item or default version, both work), 'renewed' = Renewed-Vehiclekeys
-- i have a version of qbx_vehiclekeys that works with item-based keys which can be found here https://github.com/CodexisPhantom/qbx_vehiclekeys/tree/main, but the default version also works fine
Config.VehicleKeys = 'qbx'

Config.PedModel = "u_m_y_smugmech_01"

Config.RentalLocations = {
    { coords = vec4(135.36, -1057.64, 29.19, 218.85), blip = 227, colour = 3, scale = 0.7 },
}

Config.Cars = {
    { name = "Sultan", model = "sultan", price = 100, spawn = vec4(132.24, -1058.59, 29.19, 87.4) },
}