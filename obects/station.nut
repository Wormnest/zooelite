class Station {
		station_tile = null;
		stationId = null;
		platforms = null;
		type = null;
		
		bus_built = false;
		
		
		bus_stops = null;
		bus_front_tiles = null;
		serviced_cities = null;
		
		enter_tile = null;
		enter_tile2 = null;
		
		exit_tile = null;
		exit_tile2 = null;
		//exit_part;
		
		enter2_tile = null;
		enter2_tile2 = null;
		
		exit2_tile = null;
		exit2_tile2 = null;
		
		//used for the trAins path finder
		station_dir = null;
		//says whether the station has been incorperated into the grid yet.
		routes = null;
		
	constructor() {
		
	}
	
	function buildBusStops() {
		LogManager.Log("Building bus stops for station " + this.stationId, 4);
		if(this.bus_built == true) {
			LogManager.Log("Bus stops ALREADY built", 4);
			return true;
		}
		foreach(idx, build_tile in this.bus_stops) {
			local front_tile = bus_front_tiles[idx];
			LogManager.Log(idx + " " + build_tile + " " + front_tile, 4);
			Sign(build_tile, "BUSSTOP" + idx);
			Sign(front_tile, "FRONT" + idx);
			if(AIRoad.BuildRoadStation(build_tile, front_tile, AIRoad.ROADVEHTYPE_BUS, this.stationId) == false) {
				LogManager.Log("FAILED busstop", 4);
				//this.bus_stops[idx] = null;
			}
			
			AIRoad.BuildRoad(build_tile, front_tile);
		}
		this.bus_built = true;
	}
	
	function connectStopsToTown(townId) {
		foreach(idx, front_tile in this.bus_stops) {
			local success = ZooElite.LinkTileToTile(front_tile,AITown.GetLocation(townId));
		}
	}
	
	function signStation() {
		Sign(this.enter_tile, "Enter11");
		Sign(this.enter_tile2, "Enter12");
		Sign(this.exit_tile, "Exit11");
		Sign(this.exit_tile2, "Exit12");
		if(this.station_dir.len() == 2) {
			Sign(this.exit2_tile, "Exit21");
			Sign(this.exit2_tile2, "Exit22");
			Sign(this.enter2_tile, "Enter21");
			Sign(this.enter2_tile2, "Enter22");
		}
	}
}