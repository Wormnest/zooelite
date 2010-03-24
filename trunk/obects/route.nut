class Route {
	routeId = null;
	groupId = null;
	routeRailType = null;
	seedVehicle = null;
	lastUpdated = null;
	routeDistance = null;
	
	includedPaths = null;
	servicedCities = null;
	
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
		}
		
		//Clone/get best engine and send them in
		
		
		
		
		this.lastUpdated = ZooElite.GetTick();
	}
	
	//TODO: We should probably take an explicit list instead of traveling salesmaning it because we don't know the rail layout
	function updateOrders() {
	
	}
}
	
	
	