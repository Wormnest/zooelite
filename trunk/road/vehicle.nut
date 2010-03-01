//Vehicle.nut
//Vehicle-related road functions

function ZooElite::AdjustBusesInTown(townId) {
	local group_id = 0;
	local vehicle_count = 0;
	local vehicle_list;
	
	//Load up the currently deployed vehicles for the city
	group_id = town_table[townId].bus_group_id;
	local vehicle_list = AIVehicleList_Group(group_id);
	vehicle_count = vehicle_list.Count();
	
	//TODO: Check for unprofitability / new vehicles that don't affect the count yet
	
	local production = AITown.GetLastMonthProduction(townId, GetPassengerCargoID());
	local transported = AITown.GetLastMonthTransported(townId, GetPassengerCargoID());
	local pct_transported = transported / production;
	LogManager.Log("Pct Transported for " + AITown.GetName(townId) + ": " + transported + "/" + production + " = " + pct_transported, 4);
	if(group_id == 0 || transported / production < CITY_BUS_CAPACITY_THRESHOLD) {
		//CREATE MORE
		//Let's shoot to transport 90%
		local shortfall = production * CITY_BUS_CAPACITY_TARGET - transported;
		// How many more buses do we need?
		local capacity = AIEngine.GetCapacity(GetBestEngine(GetPassengerCargoID()));
		local loads_per_month = 2;
		local more_bus = Floor((shortfall / capacity) / loads_per_month);
		LogManager.Log("Creating " + more_bus + " more buses for " + AITown.GetName(townId), 4);
		ZooElite.CreateNewBusesInTown(more_bus, townId);
		//TODO: Return and Budget?
		//TODO: Saturation Point
	}
	
	
	
	
	
	
}

function ZooElite::CreateNewBusesInTown(num, townId) {
	//Try to get group_id
	local town = town_table[townId];
	local group_id = town.bus_group_id;
	
	local depot_list = AIDepotList(AITile.TRANSPORT_ROAD);
	depot_list.Valuate(AITile.GetClosestTown);
	depot_list.KeepValue(townId);
	local depotId = depot_list.Begin();
	
	local engineId = GetBestEngine(GetPassengerCargoID());
	
	local vehicle_list = AIVehicleList_Group(group_id);
	local seed_it = false;
	if(vehicle_list.Count() == 0) {
		seed_it = true;
	}
	
	for(local built = 0; built < num; built++) {
		local this_vehicle = AIVehicle.BuildVehicle(depotId, engineId);
		AIGroup.MoveVehicle(group_id, this_vehicle);
		if(seed_it) {
			town.seed_bus_id = this_vehicle;
			seed_it = false;
			ZooElite.UpdateBusRoutesForTown(townId);
		} else {
			AIOrder.ShareOrders(this_vehicle, town.seed_bus_id);
		}
		AIVehicle.StartStopVehicle(this_vehicle);
		this.Sleep(60);
	}
}

function ZooElite::UpdateBusRoutesForTown(townId) {
	LogManager.Log("Updating bus route for " + AITown.GetName(townId), 4);
	local town = town_table[townId];
	local seed_vehicle = town.seed_bus_id;
	
	local station_list = ZooElite.GetBusStationsInCity(townId);
	station_list.Valuate(AIStation.HasStationType, AIStation.STATION_TRAIN);
	station_list.RemoveValue(1);
	
	//TODO: Lookup this towns train station and pass it as first stop
	local first_stop = AIBaseStation.GetLocation(station_list.Begin());
	
	local stationId = town.rail_station_id;
	if(stationId != null) {
		local stops = station_table[stationId].bus_stops;
		if(stops.len() > 0) {
			first_stop = stops.pop();
			stops.push(first_stop);
		} else {
			station_list.RemoveTop(1);
		}
	} else {
		station_list.RemoveTop(1);
	}
	local route = TravelingSalesman(first_stop, station_list);
	
	
	local orders = AIOrder.GetOrderCount(seed_vehicle);
	for(local i = 0; i < orders; i ++) {
		local this_dest = AIOrder.GetOrderDestination(seed_vehicle, i);
		local new_dest = route.pop();
		if(this_dest != new_dest) {
			//make it so
			AIOrder.RemoveOrder(seed_vehicle, i);
			if(first_stop == new_dest) {
				AIOrder.InsertOrder(seed_vehicle, i, new_dest, AIOrder.AIOF_TRANSFER);
			} else {
				AIOrder.InsertOrder(seed_vehicle, i, new_dest, AIOrder.AIOF_NONE);
			}
		}
	}
	while(route.len() > 0) {
		local dest = route.pop();
		//TODO: Do we want any modifiers
		if(first_stop == dest) {
			AIOrder.AppendOrder(seed_vehicle, dest, AIOrder.AIOF_TRANSFER);
		} else {
			AIOrder.AppendOrder(seed_vehicle, dest, AIOrder.AIOF_NONE);
		}
	}
}

