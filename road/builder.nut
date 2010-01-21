

function ZooElite::BuildMaxBusStationsInTown(town) {
	local pop = AITown.GetPopulation(town);
	pop = Floor(pop / 250);
	if(pop < 1)
		pop = 1;
	LogManager.Log("Limiting to " + pop + " stations", 2);
	local array = ZooElite.FindPlacesInTownForMaxNMoreBusStations(town, pop);
	if(array == false)
		return false;
	//Sort each list of tiles based on how many passengers each list would pull
	local testmode = AITestMode();
	local success = [7];
	array.sort(custom_compare);
	while(success.len() != 0 && array.len() > 0) {
		local max_list = array.top();
		success = ZooElite.BuildBusStationList(max_list);
		if(success.len() == 0) {
			testmode = null;
			LogManager.Log("Built "+ max_list.len() +"  Stations in " + AITown.GetName(town), 3);
			success = ZooElite.BuildBusStationList(max_list);
		} else {
			array.remove(array.len() - 1);
		}
	}
	
}

//Build station list assuming that you already have verified the tile you want
function ZooElite::BuildBusStationList(list) {
	//If the list is empty or null, break
	if(list == false || list.len() < 1)
		return false;
	//Go through list
	local failedLocations = [];
	foreach(tileIndex in list) {
		local success = false;
		local temptilelist = GetNeighbours4(tileIndex);
			if(AIRoad.IsRoadTile(tileIndex)) {
				//We want a drive through, now to orient it
				LogManager.Log("Building Drive through Station on: " + tileIndex, 3);
				for(local frontTileIndex = temptilelist.Begin(); temptilelist.HasNext(); frontTileIndex = temptilelist.Next()) {
					//Are we facing a road tile
					if(!success && AIRoad.IsRoadTile(frontTileIndex)) {
						LogManager.Log("Attempting to face: " + frontTileIndex, 1);
						success = AIRoad.BuildDriveThroughRoadStation(tileIndex, frontTileIndex, AIRoad.ROADVEHTYPE_BUS, AIStation.STATION_NEW);
						AIRoad.BuildRoad(tileIndex, frontTileIndex);
					} else {
						LogManager.Log("Skipping: " + frontTileIndex, 1);
					}
				}
			} else {
				//we want a depot...orient
				LogManager.Log("Trying to build depot at " + tileIndex, 3);
				for(local frontTileIndex = temptilelist.Begin(); temptilelist.HasNext(); frontTileIndex = temptilelist.Next()) {
					//Are we facing a road tile?
					if(!success && AIRoad.IsRoadTile(frontTileIndex)) {
						LogManager.Log("Attempting to face: " + frontTileIndex, 1);
						success = AIRoad.BuildRoadStation(tileIndex, frontTileIndex, AIRoad.ROADVEHTYPE_BUS, AIStation.STATION_NEW);
						AIRoad.BuildRoad(tileIndex, frontTileIndex);
					} else {
						LogManager.Log("Skipping: " + frontTileIndex, 1);
					}
				}
			}
		if(!success) {
			failedLocations.push(tileIndex);
			//TODO: Change This
			LogManager.Log("Failed to build station in " + AITown.GetName(AITile.GetClosestTown(tileIndex)) + " on tile " + tileIndex + "! Error: " + AIError.GetLastErrorString()	, 4);	
			AITile.DemolishTile(tileIndex);
			Sign(tileIndex, "I wanted a depot here, but now it's dead");
		}
	}
	return failedLocations;
	//TODO: Return an appropriate value...perhaps a list of stations which we could not build?
}