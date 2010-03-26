class Route {
	routeId = null;
	groupId = null;
	routeRailType = null;
	seedVehicle = null;
	lastUpdated = null;
	routeDistance = null;
	
	includedPaths = null;
	servicedStations = null;
	
	constructor() {
		this.routeRailType = AIRail.GetCurrentRailType();
		this.includedPaths = [];
		servicedStations = [];
		routeDistance = 0;
	}
	
	function balanceRailService() {
		local pct_transported = 0;		
		
		if(this.groupId != null) {
			local vehicles = AIVehicleList_Group(this.groupId);
			AIVehicle.GetProfitLastYear();
			local waiting = 0;
			foreach(station in servicedStations) {
				waiting += AIStation.GetCargoWaiting(station, GetPassengerCargoID());
			}
			
			local vehicle_capacity = AIVechicle.GetCapacity(seedVehicle, GetPassengerCargoID());
			local route_capacity = vehicles.Count() * vehicle_capacity / (routeDistance / 200);
			local add_vehicles = (waiting - route_capacity) / vehicle_capacity;
			if(add_vehicles == 0) {
				LogManager.Log("Route analyzed. No more trains need to be added");
				return true;
			}
		
		} else {
			this.groupId = AIGroup.CreateGroup(AIVehicle.VT_RAIL);
			add_vehicles = 2;
		}
		
		//Locate Depot to build in
		local depotTile = 0;
		
		if(seedVehicle == null) {
			//We need to build our seeder, setup orders, then clone the rest
			//Make sure we have the right vehicle for the rail type and all that
			this.seedVehicle = AIVehicle.BuildVehicle(depotTile, GetBestRailEngine(this.routeRailType));
			
			//Put some wagons on it
			for(local i = 0; i < 8; i++) {
				local wagon = AIVehicle.BuildVehicle(depotTile, GetBestRailWagon(GetPassengerCargoID(), this.routeRailType));
				AIVehicle.MoveWagon(wagon, 0, this.seedVehicle, 0);
			}
			
			//Call order Manager
			AIVehicle.MoveVehicle(this.groupId, this.seedVehicle);
			this.updateOrders();
			
			//then finish cloning as normal
			AIVehicle.StartStopVehicle(this.seedVehicle);
			add_vehicles--;
			if(add_vehicles > 0)
				this.wait(300);
		}
		
		//Clone/get best engine and send them in
		//TODO: Should we be building vehicles that might be newer than our seed vehicle? This could require more computation later when deciding when to upgrade
		for(local i = 0; i < add_vehicles; i++;) {
			local vehicle = AIVehicle.BuildVehicle(depotTile, GetBestRailEngine(this.routeRailType));
			//Put some wagons on it
			for(local j = 0; j < 8; j++) {
				local wagon = AIVehicle.BuildVehicle(depotTile, GetBestRailWagon(GetPassengerCargoID(), this.routeRailType));
				AIVehicle.MoveWagon(wagon, 0, vehicle, 0);
			}
			AIOrder.ShareOrders(vehicle, this.seedVehicle);
			AIVehicle.StartStopVehicle(vehicle);
			if(i < add_vehicles - 1)
				this.wait(300);
			
		}	
		
		this.lastUpdated = ZooElite.GetTick();
	}
	
	//TODO: We should probably take an explicit list instead of traveling salesmaning it because we don't know the rail layout
	//TODO: This also ruins the current orders since I don't think we have an "origin" station which will cause all the trains to go weird places
	function updateOrders() {
		local seed_vehicle = this.seedVehicle;
		local station_list = this.servicedStations;
		
		//TODO: Lookup this towns train station and pass it as first stop
		local first_stop = station_list.pop();
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
}
	
	
	