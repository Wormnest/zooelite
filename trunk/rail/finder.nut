
//Get Potentially usable, existing rail station placements for a given city
function ZooElite::GetRailStationsForCity(townId) {
	//Get a list of stations which are bus stops in this town
	local stations = AIStationList(AIStation.STATION_TRAIN);
	
	//Special Valuate
	for(local stationIndex = stations.Begin(); stations.HasNext(); stationIndex = stations.Next()) {
		local distance = AIMap.DistanceManhattan(AIBaseStation.GetLocation(stationIndex), AITown.GetLocation(townId));
		stations.SetValue(stationIndex, distance);
	}
	
	//Figure out how far we want to go
	stations.RemoveAboveValue(STATION_REUSE_DISTANCE_FROM_TOWN);
	stations.Sort(AIAbstractList.SORT_BY_VALUE, false);
	LogManager.Log("Found " + stations.Count() + " potentially valid, existing station placements", 1);
	return stations;
}

function ZooElite::BuildRailStationForTown(townId, direction_of_tileId, platforms, is_terminus) {
	//TODO: Give an "In direction of Tile" option
	
	//TODO: What we actually want here is a station associated with a town...it doesn't have to be in a town
	//Attempt to find exsisting stations close to the town
	LogManager.Log("Attempting to get rail station for " + AITown.GetName(townId), 3);
	local curStations = ZooElite.GetRailStationsForCity(townId);
	if(curStations.Count() > 0) {
		LogManager.Log("Reusing existing station" + curStations.Begin(), 4);
		return curStations.Begin();
	}
	
	local tilelist = AITileList();
	local seed_tile = AITown.GetLocation(townId);
	//local searchRadius = STATION_REUSE_DISTANCE_FROM_TOWN;
	local searchRadius = 20;
	
	//TODO: IMPORTANT: Improve this algorithm, we otherwise restrict the search too much when things are close to the edge
	if(AIMap.DistanceFromEdge(AITown.GetLocation(townId)) < searchRadius) {
		searchRadius = AIMap.DistanceFromEdge(AITown.GetLocation(townId)) - 1;
		LogManager.Log("Town near edge of map, reduced radius search to " + searchRadius, 3);
	}
	
	tilelist.AddRectangle(AIMap.GetTileIndex(AIMap.GetTileX(seed_tile) - searchRadius, AIMap.GetTileY(seed_tile) - searchRadius),
							AIMap.GetTileIndex(AIMap.GetTileX(seed_tile) + searchRadius, AIMap.GetTileY(seed_tile) + searchRadius)); 

	local town_to_tile = AIMap.DistanceManhattan(AITown.GetLocation(townId), direction_of_tileId);
	LogManager.Log("Town to Tile Distance: " + town_to_tile, 1);
	tilelist.Valuate(AIMap.DistanceManhattan, direction_of_tileId);
	
	//TODO: Constant???
	tilelist.RemoveAboveValue(town_to_tile + 4);
	
	
	
	//OK So now we have a pretty good list, time to start testing rectangles, we want a station like so:
	// 	  B B B
	// 	/SSSSSS-\
	//	/SSSSSS--\
	//	/SSSSSS---\
	//	/SSSSSS----\---------
	//	\--------------------
	//
	//Equates to around a  5x15 rectangle, or 5x9 core with extension. (platforms + 1)
	//Search is a 5x11 rectange, attempt to clear extra tile if needed, then search the rail extension.
	
	//Or for a non terminus station
	// 		   /-SSSSSS-\
	//		  /--SSSSSS--\
	//		 /---SSSSSS---\
	//------/----SSSSSS----\---------
	//-----/----------------\--------
	
	
	//IMPORTANT: TODO: RIGHT NOW THIS FUNCTION IS CONFUSING BECAUSE HORIZONTAL AND VERTICAL ARE BACKWARDS
	
	//Attempt to determine if we could build on this spot
	local square_x = RAIL_STATION_PLATFORM_LENGTH + 2 * (platforms + 2);
	if(is_terminus)
		square_x -= (platforms + 2);
	
	//One for return track, one for bus stations, one for road from bus stations?
	local square_y = 2 + platforms;
	
	local verticletilelist = AITileList();
	verticletilelist.AddList(tilelist);
	
	/*
	for(local tileId = tilelist.Begin(); tilelist.HasNext(); tileId = tilelist.Next()) {
		if(!AITile.IsWaterTile(tileId))
			Sign(tileId, "Horz start here");
	}
	for(local tileId = verticletilelist.Begin(); verticletilelist.HasNext(); tileId = verticletilelist.Next()) {
		if(!AITile.IsWaterTile(tileId))
			Sign(tileId, "Verticle start here");
	}
	*/
	
	tilelist.Valuate(canBuildRectangleAtCorner, square_x, square_y, false);
	tilelist.RemoveValue(0);
	
	verticletilelist.Valuate(canBuildRectangleAtCorner, square_x, square_y, true);
	verticletilelist.RemoveValue(0);
	//Ok so we may or may not actually be able to build on these...let's try to figure out how much it'd cost
	
	for(local tileId = tilelist.Begin(); tilelist.HasNext(); tileId = tilelist.Next()) {
		local result = CostToLevelRectangle(tileId, square_x, square_y, false);
		tilelist.SetValue(tileId, result);
	}
	tilelist.RemoveValue(-1);
	tilelist.Sort(AIAbstractList.SORT_BY_VALUE, true);
	
	for(local tileId = verticletilelist.Begin(); verticletilelist.HasNext(); tileId = verticletilelist.Next()) {
		local result = CostToLevelRectangle(tileId, square_x, square_y, false);
		verticletilelist.SetValue(tileId, result);
	}
	verticletilelist.RemoveValue(-1);
	verticletilelist.Sort(AIAbstractList.SORT_BY_VALUE, true);
	
	if(verticletilelist.Count() == 0 && tilelist.Count() == 0) {
		LogManager.Log("Unable to find suitable location to build station in " + AITown.GetName(townId), 4);
		return false;
	}
	
	//TODO: ADD A FUNCTION TO GENERATE A SCORING METRIC
	local vert_propisiton = verticletilelist.Begin();
	local horz_propisiton = tilelist.Begin();
	local top_left_tile = null;
	local horizontal = true;
	local swap = true;
	if(verticletilelist.GetValue(vert_propisiton) < tilelist.GetValue(horz_propisiton)) {
		top_left_tile = vert_propisiton;
		horizontal = false;
	} else {
		top_left_tile = horz_propisiton;
	}
	if(horizontal) {
		if(AIMap.DistanceManhattan(top_left_tile, direction_of_tileId) > AIMap.DistanceManhattan(GetTileRelative(top_left_tile, square_y, square_x), direction_of_tileId))
			swap = false;
	} else {
		if(AIMap.DistanceManhattan(top_left_tile, direction_of_tileId) > AIMap.DistanceManhattan(GetTileRelative(top_left_tile, square_x, square_y), direction_of_tileId))
			swap = false;
	}
	
	//Attempt to build it!
	return BuildTrainStation(townId, top_left_tile, platforms, is_terminus, horizontal, swap);
		
	
		
	/*
	//Lastly, asess the tiles in the order of closest to in direct line OR COST TO LEVEL
	//Special Valuate
	for(local tileIndex = tilelist.Begin(); tilelist.HasNext(); tileIndex = tilelist.Next()) {
		local sum = 2* AIMap.DistanceManhattan(tileIndex, AITown.GetLocation(townId))
						+ AIMap.DistanceManhattan(tileIndex, tileId);
		tilelist.SetValue(tileIndex, sum);
	}
	tilelist.Sort(AIAbstractList.SORT_BY_VALUE, true);
	*/
}

function canBuildRectangleAtCorner(tileId, square_x, square_y, verticle) {
	if(!verticle) {
		local temp = square_x;
		square_x = square_y;
		square_y = temp;
	}
	if(!AITile.IsBuildableRectangle(tileId, square_x, square_y))
		return false;
	
	local tilelist = AITileList();	
	tilelist.AddRectangle(tileId, GetTileRelative(tileId, square_x, square_y)); 
	//Create our target rectangle and get the tile count for comparison
	local old_count = tilelist.Count();
	tilelist.Valuate(AITile.IsBuildable);
	tilelist.RemoveValue(0);
	tilelist.Valuate(AITile.IsWaterTile);
	tilelist.RemoveValue(1);
	if(tilelist.Count() != old_count) {
		return false;
	}
	
	return true;
}

function CostToLevelRectangle(tileId, square_x, square_y, verticle) {
	local level_cost = 0;
	//tileId = top_left_tile;
	{{
		local test = AITestMode();
		local account = AIAccounting();
		if(!verticle) {
			local temp = square_x;
			square_x = square_y;
			square_y = temp;	
		}
		local tiles = AITileList();
		tiles.AddRectangle(GetTileRelative(tileId, 0, 0),
								GetTileRelative(tileId, square_x, square_y));
		local prev_count = tiles.Count();
		tiles.Valuate(AITile.GetSlope);
		tiles.KeepValue(0);
		if(tiles.Count() == prev_count)
			return 0;
		if(!AITile.LevelTiles(tileId, GetTileRelative(tileId, square_x, square_y)))
			return -1;

		level_cost = account.GetCosts();
	}}

	return level_cost;
}

function BuildTrainStation(townId, top_left_tile, platforms, is_terminus, horz, shift) {
	
	//Let's level it quick
	local width = RAIL_STATION_PLATFORM_LENGTH + 2 * (platforms + 2);
	local height = 2 + platforms;
	if(is_terminus)
		width -= platforms + 2;
	if(horz) {
		local temp = width;
		width = height;
		height = temp;
	}
	AITile.DemolishTile(top_left_tile);
	AITile.DemolishTile(GetTileRelative(top_left_tile, width, height));
	Sign(GetTileRelative(top_left_tile, 0, 0), "Corner 1");
	Sign(GetTileRelative(top_left_tile, width, height), "Corner 2");
	AITile.LevelTiles(top_left_tile, GetTileRelative(top_left_tile, width, height));
	
	//TODO: Set railtype that we're using, how does this change?
	local types = AIRailTypeList();
	AIRail.SetCurrentRailType(types.Begin());

	
	//TODO: We only handle terminuses at this point
	//Determine if top_left_tile is towards the city or not
	if(AIMap.DistanceManhattan(AITown.GetLocation(townId), top_left_tile) > AIMap.DistanceManhattan(AITown.GetLocation(townId), GetTileRelative(top_left_tile, width, height))) {
		//Shoot, it's backwards, we'll get around to this later	
	}
	
	if(horz && !shift) {
		LogManager.Log("Building normal, horizontal configuration", 3);
		//We shift the actual tile so that we have room for the bus stations
		top_left_tile = GetTileRelative(top_left_tile, 1, 0);
		
		local success = AIRail.BuildRailStation(GetTileRelative(top_left_tile, 0, 1), AIRail.RAILTRACK_NW_SE, platforms, RAIL_STATION_PLATFORM_LENGTH, AIBaseStation.STATION_NEW);

		if(!success) {
			LogManager.Log(AIError.GetLastErrorString(), 4);
			return false;
		}
		
		local turn_tile = GetTileRelative(top_left_tile, platforms, 0)
		AIRail.BuildRailTrack(turn_tile, AIRail.RAILTRACK_NE_SE);
		AIRail.BuildSignal(turn_tile, GetTileRelative(turn_tile, -1, 0), AIRail.SIGNALTYPE_NORMAL);
		for(local i = 0; i < platforms; i++) {
			local tile = GetTileRelative(top_left_tile, i, 0);
			AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_SW_SE);
		}
		for(local i = 1; i < platforms; i++) {
			local tile = GetTileRelative(top_left_tile, i, 0);
			AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NE_SW);
		}
		
		local signal_tile = false;
		local exit_tile = turn_tile;
		for(local i = 1; i <= RAIL_STATION_PLATFORM_LENGTH + platforms; i++) {
			local tile = GetTileRelative(turn_tile, 0, i);
			AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NW_SE);
			if(!signal_tile) {
				signal_tile = true;
			} else {
				AIRail.BuildSignal(tile, GetTileRelative(tile, 0, -1), AIRail.SIGNALTYPE_NORMAL);
				signal_tile = false;
			}
			exit_tile = tile;
		}
		
		//Exit is now properly built, build entrances
		local entry_tile = GetTileRelative(exit_tile, -1, 0);
		AIRail.BuildRailTrack(entry_tile, AIRail.RAILTRACK_NW_SE);
		AIRail.BuildSignal(entry_tile, GetTileRelative(entry_tile, 0, 1), AIRail.SIGNALTYPE_PBS_ONEWAY);
		for(local i = 1; i < platforms; i++) {
			AIRail.BuildRailTrack(GetTileRelative(entry_tile, 0, -1 * i), AIRail.RAILTRACK_NW_SE);
			for(local j = 0; j < platforms - i; j++) {
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, -1 * j,  -1 * (i + j)), AIRail.RAILTRACK_NE_SE);
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, -1 * j - 1,  -1 * (i + j)), AIRail.RAILTRACK_NW_SW);
			}	
		}
		
	} else if (horz && shift) {
		LogManager.Log("Building flipped, horizontal configuration", 3);
		//This is tough because we literally want to spin the entire station 180 degrees
		local bot_right = GetTileRelative(top_left_tile, width, height);
		
		//We shift the actual tile so that we have room for the bus stations
		bot_right = GetTileRelative(bot_right, -1, 0);
		
		local success = AIRail.BuildRailStation(GetTileRelative(bot_right, -1 * platforms, -1 * RAIL_STATION_PLATFORM_LENGTH), AIRail.RAILTRACK_NW_SE, platforms, RAIL_STATION_PLATFORM_LENGTH, AIBaseStation.STATION_NEW);
		LogManager.Log(AIError.GetLastErrorString(), 4);
		if(!success)
			return false;
		local turn_tile = GetTileRelative(bot_right, -1 * platforms - 1, 0);
		AIRail.BuildRailTrack(turn_tile, AIRail.RAILTRACK_NW_SW);
		AIRail.BuildSignal(turn_tile, GetTileRelative(turn_tile, 1, 0), AIRail.SIGNALTYPE_NORMAL);
		for(local i = 0; i < platforms; i++) {
			local tile = GetTileRelative(bot_right, -i - 1, 0);
			AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NW_NE);
		}
		for(local i = 1; i < platforms; i++) {
			local tile = GetTileRelative(bot_right, -i - 1, 0);
			AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NE_SW);
		}
		
		local signal_tile = false;
		local exit_tile = turn_tile;
		for(local i = 1; i <= RAIL_STATION_PLATFORM_LENGTH + platforms; i++) {
			local tile = GetTileRelative(turn_tile, 0, -i);
			AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NW_SE);
			if(!signal_tile) {
				signal_tile = true;
			} else {
				AIRail.BuildSignal(tile, GetTileRelative(tile, 0, 1), AIRail.SIGNALTYPE_NORMAL);
				signal_tile = false;
			}
			exit_tile = tile;
		}
		
		//Exit is now properly built, build entrances
		local entry_tile = GetTileRelative(exit_tile, 1, 0);
		AIRail.BuildRailTrack(entry_tile, AIRail.RAILTRACK_NW_SE);
		AIRail.BuildSignal(entry_tile, GetTileRelative(entry_tile, 0, 1), AIRail.SIGNALTYPE_PBS_ONEWAY);
		for(local i = 1; i < platforms; i++) {
			AIRail.BuildRailTrack(GetTileRelative(entry_tile, 0, 1 * i), AIRail.RAILTRACK_NW_SE);
			for(local j = 0; j < platforms - i; j++) {
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, j, (i + j)), AIRail.RAILTRACK_NW_SW);
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, j + 1, (i + j)), AIRail.RAILTRACK_NE_SE);
			}	
		}
		
	} else if(!horz && !shift) {
		LogManager.Log("Building normal, vertical configuration", 3);
		local bot_right = GetTileRelative(top_left_tile, width, height);
		local success = AIRail.BuildRailStation(GetTileRelative(top_left_tile, 1, 1), AIRail.RAILTRACK_NE_SW, platforms, RAIL_STATION_PLATFORM_LENGTH, AIBaseStation.STATION_NEW);
		if(!success)
			return false;
		//Build rail around
		AIRail.BuildRailTrack(top_left_tile, AIRail.RAILTRACK_SW_SE);
		AIRail.BuildSignal(top_left_tile, GetTileRelative(top_left_tile, 0, 1), AIRail.SIGNALTYPE_NORMAL);
		local turn_tile = top_left_tile;
		
		for(local i = 1; i <= platforms; i++) {
			local tile = GetTileRelative(top_left_tile, 0, i);
			AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NW_SW);
		}
		for(local i = 1; i < platforms; i++) {
			local tile = GetTileRelative(top_left_tile, 0, i);
			AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NW_SE);
		}
		
		local signal_tile = false;
		local exit_tile = turn_tile;
		for(local i = 1; i <= RAIL_STATION_PLATFORM_LENGTH + platforms; i++) {
			local tile = GetTileRelative(turn_tile, i, 0);
			AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NE_SW);
			if(!signal_tile) {
				signal_tile = true;
			} else {
				AIRail.BuildSignal(tile, GetTileRelative(tile, -1, 0), AIRail.SIGNALTYPE_NORMAL);
				signal_tile = false;
			}
			exit_tile = tile;
		}
		
		//Exit is now properly built, build entrances
		local entry_tile = GetTileRelative(exit_tile, 0, 1);
		AIRail.BuildRailTrack(entry_tile, AIRail.RAILTRACK_NE_SW);
		AIRail.BuildSignal(entry_tile, GetTileRelative(entry_tile, 1, 0), AIRail.SIGNALTYPE_PBS_ONEWAY);
		for(local i = 1; i < platforms; i++) {
			AIRail.BuildRailTrack(GetTileRelative(entry_tile, -1 * i, 0), AIRail.RAILTRACK_NE_SW);
			for(local j = 0; j < platforms - i; j++) {
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, -1 * (i + j), 1 * j), AIRail.RAILTRACK_SW_SE);
				AIRail.BuildRailTrack(GetTileRelative(entry_tile,  -1 * (i + j), 1 * j + 1), AIRail.RAILTRACK_NW_NE);
			}	
		}
		
	} else if(!horz && shift) {
		LogManager.Log("Building flipped, vertical configuration", 3);
		local bot_right = GetTileRelative(top_left_tile, width, height);
		local success = AIRail.BuildRailStation(GetTileRelative(bot_right, -1 * RAIL_STATION_PLATFORM_LENGTH, -1 * platforms), AIRail.RAILTRACK_NE_SW, platforms, RAIL_STATION_PLATFORM_LENGTH, AIBaseStation.STATION_NEW);
		if(!success)
			return false;
		//Build rail around
		AIRail.BuildRailTrack(bot_right, AIRail.RAILTRACK_NW_NE);
		AIRail.BuildSignal(bot_right, GetTileRelative(bot_right, -1, 0), AIRail.SIGNALTYPE_NORMAL);
		local turn_tile = bot_right;
		
		for(local i = 1; i <= platforms; i++) {
			local tile = GetTileRelative(bot_right, 0, -i);
			AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NE_SE);
		}
		for(local i = 1; i < platforms; i++) {
			local tile = GetTileRelative(bot_right, 0, -i);
			AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NW_SE);
		}
		
		local signal_tile = false;
		local exit_tile = turn_tile;
		for(local i = 1; i <= RAIL_STATION_PLATFORM_LENGTH + platforms; i++) {
			local tile = GetTileRelative(turn_tile, -i, 0);
			AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NE_SW);
			if(!signal_tile) {
				signal_tile = true;
			} else {
				AIRail.BuildSignal(tile, GetTileRelative(tile, 1, 0), AIRail.SIGNALTYPE_NORMAL);
				signal_tile = false;
			}
			exit_tile = tile;
		}
		
		//Exit is now properly built, build entrances
		local entry_tile = GetTileRelative(exit_tile, 0, -1);
		AIRail.BuildRailTrack(entry_tile, AIRail.RAILTRACK_NE_SW);
		AIRail.BuildSignal(entry_tile, GetTileRelative(entry_tile, -1, 0), AIRail.SIGNALTYPE_PBS_ONEWAY);
		for(local i = 1; i < platforms; i++) {
			AIRail.BuildRailTrack(GetTileRelative(entry_tile, i, 0), AIRail.RAILTRACK_NE_SW);
			for(local j = 0; j < platforms - i; j++) {
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, (i + j), -1 * j), AIRail.RAILTRACK_NW_NE);
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, (i + j), -1 * j - 1), AIRail.RAILTRACK_SW_SE);
			}	
		}
	}
	
}



//Check if this tile could be valid...valid means that the tile must be buildable and ALL tiles around it must be too
//TODO: Note that in the future we could ease this restriction
function ZooElite::GetBuildableTilesAround(tileid) {
	if(!AITile.IsBuildable(tileid)) {
		return 0;
	}
	local tilelist = GetNeighbours8(tileid);
	tilelist.Valuate(AITile.IsBuildable);
	tilelist.RemoveValue(0);
	return tilelist.Count();
}
