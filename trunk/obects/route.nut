class Route {

	railstation_id1 = null;
	railstation_id2 = null;
	depot_tile = null;
	
	routeId = null;
	groupId = null;
	routeRailType = null;
	seedVehicle = null;
	lastUpdated = null;
	routeDistance = null;
	includedPaths = null;
	servicedStations = null;

	constructor(r_id1, r_id2, depot) {
		this.railstation_id1 = r_id1;
		this.railstation_id2 = r_id2;	
		this.depot_tile = depot;
		this.routeRailType = AIRail.GetCurrentRailType();
		this.includedPaths = [];
		servicedStations = [];
		routeDistance = 0;
	}
	
	function balanceRailService() {
		local pct_transported = 0;	
			local add_vehicles;
		
		if(this.groupId != null) {
			local vehicles = AIVehicleList_Group(this.groupId);
			AIVehicle.GetProfitLastYear();
			local waiting = 0;
			foreach(station in servicedStations) {
				waiting += AIStation.GetCargoWaiting(station, GetPassengerCargoID());
			}
			
			local vehicle_capacity = AIVechicle.GetCapacity(seedVehicle, GetPassengerCargoID());
			local route_capacity = vehicles.Count() * vehicle_capacity / (routeDistance / 200);
			add_vehicles = (waiting - route_capacity) / vehicle_capacity;
			if(add_vehicles == 0) {
				LogManager.Log("Route analyzed. No more trains need to be added");
				return true;
			}
		
		} else {
			this.groupId = AIGroup.CreateGroup(AIVehicle.VT_RAIL);
			add_vehicles = 2;
		}
		
		//Locate Depot to build in
		//local depotTile = 0;
		
		if(seedVehicle == null) {
			//We need to build our seeder, setup orders, then clone the rest
			//Make sure we have the right vehicle for the rail type and all that
			this.seedVehicle = AIVehicle.BuildVehicle(this.depot_tile, GetBestRailEngine(this.routeRailType));
			
			//Put some wagons on it
			for(local i = 0; i < 8; i++) {
				local wagon = AIVehicle.BuildVehicle(this.depot_tile, GetBestRailWagon(GetPassengerCargoID(), this.routeRailType));
				AIVehicle.MoveWagon(wagon, 0, this.seedVehicle, 0);
			}
			
			//Call order Manager
			//AIVehicle.MoveVehicle(this.groupId, this.seedVehicle);
			this.updateOrders();
			
			LogManager.Log("our vehicle has this many orders: " + AIOrder.GetOrderCount(this.seedVehicle), 4);
			
			//then finish cloning as normal
			AIVehicle.StartStopVehicle(this.seedVehicle);
			
			/*if(AIVehicle.IsStoppedInDepot(this.seedVehicle)) {
				LogManager.Log("it is stopped in the depot", 4);
			}
			else {
				LogManager.Log("it is in the depot but not stopped", 4);
			}*/
			
			/*LogManager.Log("order0", 4);
			if(AIOrder.IsGotoStationOrder(seedVehicle, 0)) {
				LogManager.Log("order 0 is GOTO Sation", 4);
			}
			else {
				LogManager.Log("order 0 is BAD", 4);
			}
			
			LogManager.Log("order1", 4);
			if(AIOrder.IsGotoStationOrder(seedVehicle, 1)) {
				LogManager.Log("order 1 is Goto Station", 4);
			}
			else {
				LogManager.Log("order 1 is BAD", 4);
			}*/
			
			add_vehicles--;
			if(add_vehicles > 0)
				ZooElite.Sleep(300);
		}
		
		//Clone/get best engine and send them in
		//TODO: Should we be building vehicles that might be newer than our seed vehicle? This could require more computation later when deciding when to upgrade
		for(local i = 0; i < add_vehicles; i++) {
			local vehicle = AIVehicle.BuildVehicle(this.depot_tile, GetBestRailEngine(this.routeRailType));
			//Put some wagons on it
			for(local j = 0; j < 8; j++) {
				local wagon = AIVehicle.BuildVehicle(this.depot_tile, GetBestRailWagon(GetPassengerCargoID(), this.routeRailType));
				AIVehicle.MoveWagon(wagon, 0, vehicle, 0);
			}
			AIOrder.ShareOrders(vehicle, this.seedVehicle);
			AIVehicle.StartStopVehicle(vehicle);
			if(i < add_vehicles - 1)
				ZooElite.Sleep(300);
			
		}	
		
		this.lastUpdated = ZooElite.GetTick();
	}
	
	//TODO: We should probably take an explicit list instead of traveling salesmaning it because we don't know the rail layout
	//TODO: This also ruins the current orders since I don't think we have an "origin" station which will cause all the trains to go weird places
	function updateOrders() {
		local seed_vehicle = this.seedVehicle;
		local station_list = [railstation_id1, railstation_id2];
		
		//TODO: Lookup this towns train station and pass it as first stop
		local first_stop = railstation_id2;
		local route = [railstation_id1, railstation_id2];//TravelingSalesman(first_stop, station_list);
		LogManager.Log("rail station id1 is: " + railstation_id1,4);
		LogManager.Log("rail station id2 is: " + railstation_id2,4);
		
		
		//Got rid of AIOF_TRANSFER
		local orders = AIOrder.GetOrderCount(seed_vehicle);
		for(local i = 0; i < orders; i++) {
			LogManager.Log("We're in the for loop? WTF", 4);
			local this_dest = AIOrder.GetOrderDestination(seed_vehicle, i);
			local new_dest = route.pop();
			if(this_dest != new_dest) {
				//make it so
				AIOrder.RemoveOrder(seed_vehicle, i);
				if(first_stop == new_dest) {
					AIOrder.InsertOrder(seed_vehicle, i, new_dest, AIOrder.AIOF_NON_STOP_INTERMEDIATE);
				} else {
					AIOrder.InsertOrder(seed_vehicle, i, new_dest, AIOrder.AIOF_NON_STOP_INTERMEDIATE);
				}
			}
		}
		LogManager.Log("the route length is: " + route.len(), 4);
		while(route.len() > 0) {
			LogManager.Log("in while loop adding first trains", 4);
			local dest = AIStation.GetLocation(route.pop());
			//TODO: Do we want any modifiers
			if(first_stop == dest) {
				LogManager.Log("Appending order1", 4);
				AIOrder.AppendOrder(seed_vehicle, dest, AIOrder.AIOF_NON_STOP_INTERMEDIATE);
			} else {
				LogManager.Log("Appending order2", 4);
				AIOrder.AppendOrder(seed_vehicle, dest, AIOrder.AIOF_NON_STOP_INTERMEDIATE);
			}
		}
		
	}
}
