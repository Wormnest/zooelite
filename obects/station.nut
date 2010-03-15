class Station {
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
		
		station_dir = null;
		
	constructor() {
		
	}
	
	function buildBusStops() {
		LogManager.Log("Building bus stops for station " + this.stationId, 4);
		foreach(idx, build_tile in this.bus_stops) {
			local front_tile = bus_front_tiles[idx];
			LogManager.Log(idx + " " + build_tile + " " + front_tile, 4);
			AIRoad.BuildRoadStation(build_tile, front_tile, AIRoad.ROADVEHTYPE_BUS, this.stationId);
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
		//Sign(this.enter2_tile, "Enter21");
		//Sign(this.enter2_tile2, "Enter22");
		Sign(this.exit_tile, "Exit11");
		Sign(this.exit_tile2, "Exit12");
		//Sign(this.exit2_tile, "Exit21");
		//Sign(this.exit2_tile2, "Exit22");
	}
}