

function ZooElite::BuildMaxBusStationsInTown(town, max) {
	local pop = AITown.GetPopulation(town);
	pop = Floor(pop / 250);
	if(pop < 1)
		pop = 1;
	LogManager.Log("Limiting to " + pop + " stations", 2);
	local array = [];
	if(max < 1)
		array = ZooElite.FindPlacesInTownForMaxNMoreBusStations(town, pop);
	else
		array = ZooElite.FindPlacesInTownForMaxNMoreBusStations(town, max);
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

function ZooElite::BuildDepotForTown(townId) {
	local depots = AIDepotList(AITile.TRANSPORT_ROAD);
	depots.Valuate(AITile.GetClosestTown);
	depots.KeepValue(townId);
	if(depots.Count() > 1) {
		return depots.Begin();
	}
	//TODO: Search for a depot location to build, build, and return spot
}

function ZooElite::LinkTileToTown(tileId, townId) {
	local town_loc = AITown.GetLocation(townId);
	//Holder Function for rail builder
	/* Create an instance of the pathfinder. */
	local pathfinder = RoadPathFinder();
	/* Set the cost for making a turn extremely high. */
	pathfinder.cost.turn = 500;
	pathfinder.cost.no_existing_road = 120;
	
	//TODO: Add some Intelligence to figure out if we can afford things based on available cash / master plan
	pathfinder.cost.tunnel_per_tile = 200;
	LogManager.Log("Pathing Stations", 3);
	pathfinder.InitializePath([tileId], [town_loc]);

	/* Try to find a path. */
  local path = false;
  while (path == false) {
	path = pathfinder.FindPath(100);
	this.Sleep(1);
  }

  
  if (path == null) {
	/* No path was found. */
	AILog.Error("pathfinder.FindPath return null", 4);
  }
  	
	/* If a path was found, build a road over it. */
	//AND FIND SUITABLE STATION SPOT
	while (path != null) {
		local par = path.GetParent();
		if (par != null) {
		  local last_node = path.GetTile();
		  if (AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) == 1 ) {
			if (!AIRoad.BuildRoad(path.GetTile(), par.GetTile())) {
			  /* An error occured while building a piece of road. TODO: handle it. 
			   * Note that is can also be the case that the road was already build. */
			}
		  } else {
			/* Build a bridge or tunnel. */
			if (!AIBridge.IsBridgeTile(path.GetTile()) && !AITunnel.IsTunnelTile(path.GetTile())) {
			  /* If it was a road tile, demolish it first. Do this to work around expended roadbits. */
			  if (AIRoad.IsRoadTile(path.GetTile())) AITile.DemolishTile(path.GetTile());
			  if (AITunnel.GetOtherTunnelEnd(path.GetTile()) == par.GetTile()) {
				if (!AITunnel.BuildTunnel(AIVehicle.VT_ROAD, path.GetTile())) {
				  /* An error occured while building a tunnel. TODO: handle it. */
				}
			  } else {
				local bridge_list = AIBridgeList_Length(AIMap.DistanceManhattan(path.GetTile(), par.GetTile()) + 1);
				bridge_list.Valuate(AIBridge.GetMaxSpeed);
				bridge_list.Sort(AIAbstractList.SORT_BY_VALUE, false);
				if (!AIBridge.BuildBridge(AIVehicle.VT_ROAD, bridge_list.Begin(), path.GetTile(), par.GetTile())) {
				  /* An error occured while building a bridge. TODO: handle it. */
				}
			  }
			}
		  }
		}
		path = par;
	}
	LogManager.Log("Pathing Done!", 3);
}