
//Get Potentially usable, existing rail station placements for a given city
//returns a list of stations within the constant STATION_REUSE_DISTANCE_FROM_TOWN
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

//This function actually finds an appropriate build site for the given specifications
//ARGS: TownId, TileId to search from, Direction to point (MUST BE FAR ENOUGH AWAY), number of platforms, boolean is_terminus
//RETURNS: stationId of new station?

function ZooElite::BuildRailStationForTown(townId, tileId, direction_of_tileId, platforms, is_terminus) {
	
	//Attempt to determine if we could build on this spot
	local square_x = RAIL_STATION_PLATFORM_LENGTH + 2 * (platforms);
	if(is_terminus)
		square_x -= platforms - 2;
	
	//One for return track, one for bus stations, one for road from bus stations?
	local square_y = 3 + platforms;
	if(!is_terminus)
		square_y -= 3;
		
		
	local tilelist = AITileList();
	local seed_tile = 0;
	
	//TODO: What we actually want here is a station associated with a town...it doesn't have to be in a town
	//		Moreover, do we want to check from the city distance or now?
	//Attempt to find exsisting stations close to the town
	if(AITown.IsValidTown(townId) && !AIMap.IsValidTile(tileId)) {
		LogManager.Log("Attempting to get rail station for " + AITown.GetName(townId), 3);
		local curStations = ZooElite.GetRailStationsForCity(townId);
		if(curStations.Count() > 0) {
			LogManager.Log("Reusing existing station" + curStations.Begin(), 4);
			return curStations.Begin();
		}
		seed_tile = AITown.GetLocation(townId);
	} else {
		seed_tile = tileId;
	}
	
	//TODO: SHould this be a constant? Should it be computed? Raised slowly?
	local searchRadius = 10;
	
	//TODO: IMPORTANT: Improve this algorithm, we otherwise restrict the search too much when things are close to the edge
	//Ensure we aren't analyzing off the map as this will cause issues
	if(AIMap.DistanceFromEdge(AITown.GetLocation(townId)) < searchRadius + square_x || AIMap.DistanceFromEdge(AITown.GetLocation(townId)) < searchRadius + square_y) {
		searchRadius = AIMap.DistanceFromEdge(AITown.GetLocation(townId)) - 1;
		tilelist.AddRectangle(AIMap.GetTileIndex(AIMap.GetTileX(seed_tile) - searchRadius, AIMap.GetTileY(seed_tile) - searchRadius),
							AIMap.GetTileIndex(AIMap.GetTileX(seed_tile) + searchRadius, AIMap.GetTileY(seed_tile) + searchRadius)); 
		LogManager.Log("Town near edge of map, reduced radius search to " + searchRadius, 3);
		
	} else {
		tilelist.AddRectangle(AIMap.GetTileIndex(AIMap.GetTileX(seed_tile) - searchRadius - square_x, AIMap.GetTileY(seed_tile) - searchRadius - square_y),
							AIMap.GetTileIndex(AIMap.GetTileX(seed_tile) + searchRadius, AIMap.GetTileY(seed_tile) + searchRadius)); 
		Sign(AIMap.GetTileIndex(AIMap.GetTileX(seed_tile) - searchRadius - square_x, AIMap.GetTileY(seed_tile) - searchRadius - square_y), "Search Corner 1");
		Sign(AIMap.GetTileIndex(AIMap.GetTileX(seed_tile) + searchRadius, AIMap.GetTileY(seed_tile) + searchRadius), "Search Corner 2");
	}
	
	

	//Ensure that we are on the right side of the tile
	local town_to_tile = AIMap.DistanceManhattan(seed_tile, direction_of_tileId);
	LogManager.Log("Town to Tile Distance: " + town_to_tile, 1);
	tilelist.Valuate(AIMap.DistanceManhattan, direction_of_tileId);
	tilelist.RemoveAboveValue(town_to_tile + RAILSTATION_IN_DIRECTION_OF_FLEX);
	
	
	
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
	
	
	//IMPORTANT: TODO: RIGHT NOW THIS FUNCTION IS CONFUSING BECAUSE HORIZONTAL AND VERTICAL ARE BACKWARDS OR ARE THEY?
	
	
	//Build seperate vertical tilelist
	local verticletilelist = AITileList();
	verticletilelist.AddList(tilelist);
	
	//Remove unbuildable options
	tilelist.Valuate(canBuildRectangleAtCorner, square_y, square_x);
	tilelist.RemoveValue(0);
	verticletilelist.Valuate(canBuildRectangleAtCorner, square_x, square_y);
	verticletilelist.RemoveValue(0);
	
	//Ok so we may or may not actually be able to build on these...let's try to figure out how much it'd cost
	//Sort results by cost
	for(local tileId = tilelist.Begin(); tilelist.HasNext(); tileId = tilelist.Next()) {
		local result = CostToLevelRectangle(tileId, square_y + 1, square_x + 1);
		if(result > -1) {
			result += RAIL_STATION_SEARCH_DISTANCE_WEIGHT * AITile.GetBuildCost(AITile.BT_TERRAFORM) 
							* AIMap.DistanceManhattan(GetTileRelative(tileId, Floor(square_y / 2), Floor(square_x / 2)), seed_tile);
			result -= AITile.GetBuildCost(AITile.BT_TERRAFORM) * RAIL_STATION_SEARCH_CARGO_WEIGHT * AITile.GetCargoProduction(GetTileRelative(tileId, Floor(square_x / 2), Floor(square_y / 2)), GetPassengerCargoID(), 4, 4, 3);
			//Sign(tileId, result);
		}
		tilelist.SetValue(tileId, result);
	}
	tilelist.RemoveValue(-1);
	tilelist.Sort(AIAbstractList.SORT_BY_VALUE, true);
	for(local tileId = verticletilelist.Begin(); verticletilelist.HasNext(); tileId = verticletilelist.Next()) {
		local result = CostToLevelRectangle(tileId, square_x + 1, square_y + 1);
		if(result > -1) {
			result += RAIL_STATION_SEARCH_DISTANCE_WEIGHT * AITile.GetBuildCost(AITile.BT_TERRAFORM) 
							* AIMap.DistanceManhattan(GetTileRelative(tileId, Floor(square_x / 2), Floor(square_y / 2)), seed_tile);
			result -= AITile.GetBuildCost(AITile.BT_TERRAFORM) * RAIL_STATION_SEARCH_CARGO_WEIGHT * AITile.GetCargoProduction(GetTileRelative(tileId, Floor(square_x / 2), Floor(square_y / 2)), GetPassengerCargoID(), 4, 4, 3);
			//Sign(tileId, result);
		}
		
		verticletilelist.SetValue(tileId, result);
	}
	verticletilelist.RemoveValue(-1);
	verticletilelist.Sort(AIAbstractList.SORT_BY_VALUE, true);
	
	//This means we can't build here...sad
	if(verticletilelist.Count() == 0 && tilelist.Count() == 0) {
		LogManager.Log("Unable to find suitable location to build station in " + AITown.GetName(townId), 4);
		return false;
	}
	
	//TODO: ADD A FUNCTION TO GENERATE A SCORING METRIC
	//Evaluate each, and choose the best plot to build on
	local vert_propisiton = verticletilelist.Begin();
	local horz_propisiton = tilelist.Begin();
	LogManager.Log("Found " + verticletilelist.Count() + " " + tilelist.Count() + " locations for " +  AITown.GetName(townId), 4);
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
	
	//Attempt to build it by sending it to another function!
	if(!is_terminus)
		return BuildRegionalStation(top_left_tile, platforms, horizontal, swap);
	return BuildTrainStation(townId, top_left_tile, platforms, is_terminus, horizontal, swap);
		
	
		
	/*
	//Lastly, asess the tiles in the order of closest to in direct line OR COST TO LEVEL
	//Special Valuate
	for(local tileIndex = tilelist.Begin(); tilelist.HasNext(); tileIndex = tilelist.Next()) {
		local sum = 2* AIMap.DistanceManhattan(tileIndex, AITown.GetLocation(townId))
						+ AIMap.DistanceManhattan(tileIndex, tileId);
		tilelist.SetValue(tileIndex, sum);
		AITile.BT_TERRAFORM
	}
	tilelist.Sort(AIAbstractList.SORT_BY_VALUE, true);
	*/
}

//Figure out if we can build here...
function canBuildRectangleAtCorner(tileId, square_x, square_y) {
	
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
	tilelist.Valuate(AITile.IsCoastTile);
	tilelist.RemoveValue(1);
	if(tilelist.Count() != old_count) {
		return false;
	}
	
	return true;
}

//Return the cost to flatten this rectangle
function CostToLevelRectangle(tileId, square_x, square_y) {
	local level_cost = 0;
	//tileId = top_left_tile;
	{{
		local test = AITestMode();
		local account = AIAccounting();
		local tiles = AITileList();
		tiles.AddRectangle(tileId, GetTileRelative(tileId, square_x, square_y));
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

//Big nasty function to build a big regional station
//Regional stations do not have bus stops and are non-terminus stations
function BuildRegionalStation(top_left_tile, platforms, horz, shift) {
	//TODO: Shift might be easy to build in so we'll keep it for now
	local left_bot_bool = 1;
	local right_bot_bool = 1;
	
	local is_terminus = false;
	local width = RAIL_STATION_PLATFORM_LENGTH + 2 * (platforms + 1);
	local height = platforms;
	if(is_terminus)
		width -= platforms - 1;
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
	local StationId = 0;
	if(horz) {
		LogManager.Log("Building regional, horizontal configuration", 3);
		//We shift the actual tile so that we have room for rails on both sides
		top_left_tile = GetTileRelative(top_left_tile, 0, platforms + 1);
		local top_right_tile = GetTileRelative(top_left_tile, 0, RAIL_STATION_PLATFORM_LENGTH);
		//so the station should actually line up to the top of the bounding box
		local success = AIRail.BuildRailStation(top_left_tile, AIRail.RAILTRACK_NW_SE, platforms, RAIL_STATION_PLATFORM_LENGTH, AIBaseStation.STATION_NEW);

		if(!success) {
			LogManager.Log(AIError.GetLastErrorString(), 4);
			return false;
		}
		
		stationId = AIStation.GetStationID(top_left_tile);
		
		
		//Build hookups and signals for each side
			local exit_tile = GetTileRelative(top_left_tile, left_bot_bool * platforms - left_bot_bool, -platforms - 1);
			local entry_tile = GetTileRelative(exit_tile, Neg1Bool(left_bot_bool), 0);
			
			//Build Entry and exit tiles
			AIRail.BuildRailTrack(exit_tile, AIRail.RAILTRACK_NW_SE);
			AIRail.BuildRailTrack(entry_tile, AIRail.RAILTRACK_NW_SE);
			if(left_bot_bool == 0) {
				AIRail.BuildSignal(exit_tile, GetTileRelative(exit_tile, 0, 1), AIRail.SIGNALTYPE_NORMAL);
				AIRail.BuildSignal(entry_tile, GetTileRelative(entry_tile, 0, -1), AIRail.SIGNALTYPE_PBS_ONEWAY);
			} else {
				AIRail.BuildSignal(entry_tile, GetTileRelative(entry_tile, 0, 1), AIRail.SIGNALTYPE_NORMAL);
				AIRail.BuildSignal(exit_tile, GetTileRelative(exit_tile, 0, -1), AIRail.SIGNALTYPE_PBS_ONEWAY);
			}
			
			for(local i = 1; i < platforms; i++) {
				AIRail.BuildRailTrack(GetTileRelative(exit_tile, 0, 1 * i), AIRail.RAILTRACK_NW_SE);
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, 0, 1 * i), AIRail.RAILTRACK_NW_SE);
				for(local j = 0; j < platforms - i; j++) {
					AIRail.BuildRailTrack(GetTileRelative(exit_tile, Neg1Bool(left_bot_bool) * j,  1 * (i + j)), GetTrackDirection(AIRail.RAILTRACK_NW_SW, left_bot_bool));
					AIRail.BuildRailTrack(GetTileRelative(exit_tile, Neg1Bool(left_bot_bool) * j + Neg1Bool(left_bot_bool),  1 * (i + j)), GetTrackDirection(AIRail.RAILTRACK_NE_SE, left_bot_bool));
				}
				//Build platform rail and signal	
			}
			
			//Do the twist
			AIRail.BuildRailTrack(GetTileRelative(entry_tile, 0 , platforms - 1), GetTrackDirection(AIRail.RAILTRACK_NW_NE, left_bot_bool));
			AIRail.BuildRailTrack(GetTileRelative(exit_tile, 0, platforms -  1), GetTrackDirection(AIRail.RAILTRACK_SW_SE, left_bot_bool));
			
			for(local i = 0; i < platforms; i++) {
				AIRail.BuildRailTrack(GetTileRelative(exit_tile, Neg1Bool(left_bot_bool) * i, platforms), AIRail.RAILTRACK_NW_SE);
				AIRail.BuildSignal(GetTileRelative(exit_tile, Neg1Bool(left_bot_bool) * i, platforms), GetTileRelative(exit_tile, (1 - 2 * left_bot_bool) * i, platforms + 1), AIRail.SIGNALTYPE_PBS);
			}
			
			
		//Build Second side
			local entry_tile = GetTileRelative(top_right_tile, right_bot_bool * platforms - right_bot_bool, platforms);
			local exit_tile = GetTileRelative(entry_tile, Neg1Bool(right_bot_bool), 0);
			
			
			//Build Entry/Exit Tracks
			AIRail.BuildRailTrack(exit_tile, AIRail.RAILTRACK_NW_SE);
			AIRail.BuildRailTrack(entry_tile, AIRail.RAILTRACK_NW_SE);
			if(right_bot_bool == 0) {
				AIRail.BuildSignal(exit_tile, GetTileRelative(exit_tile, 0, -1), AIRail.SIGNALTYPE_NORMAL);
				AIRail.BuildSignal(entry_tile, GetTileRelative(entry_tile, 0, 1), AIRail.SIGNALTYPE_PBS_ONEWAY);
			} else {
				AIRail.BuildSignal(entry_tile, GetTileRelative(entry_tile, 0, -1), AIRail.SIGNALTYPE_NORMAL);
				AIRail.BuildSignal(exit_tile, GetTileRelative(exit_tile, 0, 1), AIRail.SIGNALTYPE_PBS_ONEWAY);
			}
			
			for(local i = 1; i < platforms; i++) {
				AIRail.BuildRailTrack(GetTileRelative(exit_tile, 0, -i), AIRail.RAILTRACK_NW_SE);
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, 0, -i), AIRail.RAILTRACK_NW_SE);
				for(local j = 0; j < platforms - i; j++) {
					AIRail.BuildRailTrack(GetTileRelative(entry_tile, Neg1Bool(right_bot_bool) * j,  -1 * (i + j)), GetTrackDirection(AIRail.RAILTRACK_SW_SE, right_bot_bool));
					AIRail.BuildRailTrack(GetTileRelative(entry_tile, Neg1Bool(right_bot_bool) * j + Neg1Bool(right_bot_bool),  -1 * (i + j)), GetTrackDirection(AIRail.RAILTRACK_NW_NE, right_bot_bool));
				}
				//Build platform rail and signal	
			}
			
			//Do the twist
			
			AIRail.BuildRailTrack(GetTileRelative(entry_tile, 0, -platforms + 1), GetTrackDirection(AIRail.RAILTRACK_NW_SW, right_bot_bool));
			AIRail.BuildRailTrack(GetTileRelative(exit_tile, 0, -platforms + 1), GetTrackDirection(AIRail.RAILTRACK_NE_SE, right_bot_bool));
			
			for(local i = 0; i < platforms; i++) {
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, Neg1Bool(right_bot_bool) * i, -platforms), AIRail.RAILTRACK_NW_SE);
				AIRail.BuildSignal(GetTileRelative(entry_tile, Neg1Bool(right_bot_bool) * i, -platforms), GetTileRelative(entry_tile, Neg1Bool(right_bot_bool) * i, -platforms - 1), AIRail.SIGNALTYPE_PBS);
			}
			
	} else {
		LogManager.Log("Building regional, vertical configuration", 3);
		//We shift the actual tile so that we have room for rails on both sides
		top_left_tile = GetTileRelative(top_left_tile, platforms + 1, 0);
		local top_right_tile = GetTileRelative(top_left_tile, RAIL_STATION_PLATFORM_LENGTH, 0);
		//so the station should actually line up to the top of the bounding box
		local success = AIRail.BuildRailStation(top_left_tile, AIRail.RAILTRACK_NE_SW, platforms, RAIL_STATION_PLATFORM_LENGTH, AIBaseStation.STATION_NEW);

		if(!success) {
			LogManager.Log(AIError.GetLastErrorString(), 4);
			return false;
		}
		stationId = AIStation.GetStationID(top_left_tile);
		
		
		//Build hookups and signals for each side
			local exit_tile = GetTileRelative(top_left_tile, -platforms - 1, left_bot_bool * platforms - left_bot_bool);
			local entry_tile = GetTileRelative(exit_tile, 0, Neg1Bool(left_bot_bool));
			
			//Build Entry and exit tiles
			Sign(exit_tile, "Exit Tile");
			AIRail.BuildRailTrack(exit_tile, AIRail.RAILTRACK_NE_SW);
			AIRail.BuildRailTrack(entry_tile, AIRail.RAILTRACK_NE_SW);
			if(left_bot_bool == 1) {
				AIRail.BuildSignal(exit_tile, GetTileRelative(exit_tile, 1, 0), AIRail.SIGNALTYPE_NORMAL);
				AIRail.BuildSignal(entry_tile, GetTileRelative(entry_tile, -1, 0), AIRail.SIGNALTYPE_PBS_ONEWAY);
			} else {
				AIRail.BuildSignal(entry_tile, GetTileRelative(entry_tile, 1, 0), AIRail.SIGNALTYPE_NORMAL);
				AIRail.BuildSignal(exit_tile, GetTileRelative(exit_tile, -1, 0), AIRail.SIGNALTYPE_PBS_ONEWAY);
			}
			
			for(local i = 1; i < platforms; i++) {
				AIRail.BuildRailTrack(GetTileRelative(exit_tile, 1 * i, 0), AIRail.RAILTRACK_NE_SW);
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, 1 * i, 0), AIRail.RAILTRACK_NE_SW);
				for(local j = 0; j < platforms - i; j++) {
					AIRail.BuildRailTrack(GetTileRelative(exit_tile, 1 * (i + j), Neg1Bool(left_bot_bool) * j - left_bot_bool), GetTrackDirection(AIRail.RAILTRACK_NE_SE, left_bot_bool));
					AIRail.BuildRailTrack(GetTileRelative(exit_tile, 1 * (i + j), Neg1Bool(left_bot_bool) * j + 1 -left_bot_bool), GetTrackDirection(AIRail.RAILTRACK_NW_SW, left_bot_bool));
				}
				//Build platform rail and signal	
			}
			
			//Do the twist
			if(left_bot_bool == 1) {
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, platforms - 1, 0), AIRail.RAILTRACK_NE_SE);
				AIRail.BuildRailTrack(GetTileRelative(exit_tile, platforms -  1, 0), AIRail.RAILTRACK_NW_SW);
			} else {
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, platforms - 1, 0), GetTrackDirection(AIRail.RAILTRACK_NW_NE, left_bot_bool));
				AIRail.BuildRailTrack(GetTileRelative(exit_tile, platforms -  1, 0), GetTrackDirection(AIRail.RAILTRACK_SW_SE, left_bot_bool));
			}
			
			for(local i = 0; i < platforms; i++) {
				AIRail.BuildRailTrack(GetTileRelative(exit_tile, platforms, Neg1Bool(left_bot_bool) * i), AIRail.RAILTRACK_NE_SW);
				AIRail.BuildSignal(GetTileRelative(exit_tile, platforms, Neg1Bool(left_bot_bool) * i), GetTileRelative(exit_tile, platforms + 1, Neg1Bool(left_bot_bool) * i), AIRail.SIGNALTYPE_PBS);
			}
			
			
		//Build Second side
			local entry_tile = GetTileRelative(top_right_tile, platforms, right_bot_bool * platforms - right_bot_bool);
			local exit_tile = GetTileRelative(entry_tile, 0, Neg1Bool(right_bot_bool));
			
			
			//Build Entry/Exit Tracks
			AIRail.BuildRailTrack(exit_tile, AIRail.RAILTRACK_NE_SW);
			AIRail.BuildRailTrack(entry_tile, AIRail.RAILTRACK_NE_SW);
			if(right_bot_bool == 1) {
				AIRail.BuildSignal(exit_tile, GetTileRelative(exit_tile, -1, 0), AIRail.SIGNALTYPE_NORMAL);
				AIRail.BuildSignal(entry_tile, GetTileRelative(entry_tile, 1, 0), AIRail.SIGNALTYPE_PBS_ONEWAY);
			} else {
				AIRail.BuildSignal(entry_tile, GetTileRelative(entry_tile, -1, 0), AIRail.SIGNALTYPE_NORMAL);
				AIRail.BuildSignal(exit_tile, GetTileRelative(exit_tile, 1, 0), AIRail.SIGNALTYPE_PBS_ONEWAY);
			}
			
			for(local i = 1; i < platforms; i++) {
				AIRail.BuildRailTrack(GetTileRelative(exit_tile, -i, 0), AIRail.RAILTRACK_NE_SW);
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, -i, 0), AIRail.RAILTRACK_NE_SW);
				for(local j = 0; j < platforms - i; j++) {
					AIRail.BuildRailTrack(GetTileRelative(entry_tile, -1 * (i + j), Neg1Bool(right_bot_bool) * j + 1 - right_bot_bool), GetTrackDirection(AIRail.RAILTRACK_NW_NE, right_bot_bool));
					AIRail.BuildRailTrack(GetTileRelative(entry_tile, -1 * (i + j), Neg1Bool(right_bot_bool) * j - right_bot_bool), GetTrackDirection(AIRail.RAILTRACK_SW_SE, right_bot_bool));
				}
				//Build platform rail and signal	
			}
			
			//Do the twist
			if(right_bot_bool == 1) {
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, -platforms + 1, 0), GetTrackDirection(AIRail.RAILTRACK_NW_SW, right_bot_bool));
				AIRail.BuildRailTrack(GetTileRelative(exit_tile, -platforms + 1, 0), GetTrackDirection(AIRail.RAILTRACK_NE_SE, right_bot_bool));
			} else {
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, -platforms + 1, 0), AIRail.RAILTRACK_NE_SE);
				AIRail.BuildRailTrack(GetTileRelative(exit_tile, -platforms + 1, 0), AIRail.RAILTRACK_NW_SW);	
			}
			
			for(local i = 0; i < platforms; i++) {
				AIRail.BuildRailTrack(GetTileRelative(entry_tile, -platforms, Neg1Bool(right_bot_bool) * i), AIRail.RAILTRACK_NE_SW);
				AIRail.BuildSignal(GetTileRelative(entry_tile, -platforms, Neg1Bool(right_bot_bool) * i), GetTileRelative(entry_tile, -platforms - 1, Neg1Bool(right_bot_bool) * i), AIRail.SIGNALTYPE_PBS);
			}
	}
	return stationId;
	
}

//Some Helper stuff
function GetTrackDirection(dir, rot) {
	if(rot == 0)
		return dir;
	switch (dir) {
		case AIRail.RAILTRACK_NW_SE: return AIRail.RAILTRACK_NW_SE;
		case AIRail.RAILTRACK_NW_SW: return AIRail.RAILTRACK_NW_NE;
		case AIRail.RAILTRACK_NE_SE: return AIRail.RAILTRACK_SW_SE;
		case AIRail.RAILTRACK_SW_SE: return AIRail.RAILTRACK_NE_SE;
		case AIRail.RAILTRACK_NW_NE: return AIRail.RAILTRACK_NW_SW;	
	}	
}

function Neg1Bool(aBool) {
	return (1 - 2 * aBool);
}

function Pos1Bool(aBool) {
	return (-1 + 2 * aBool);
}

//Build normal city train station.
//This is a terminus which will have bus stops attached to townId
function BuildTrainStation(townId, top_left_tile, platforms, is_terminus, horz, shift) {
	//Let's level it quick
	local width = RAIL_STATION_PLATFORM_LENGTH + (2 * platforms);
	local height = 3 + platforms;
	if(is_terminus)
		width -= platforms - 2;
	if(horz) {
		local temp = width;
		width = height;
		height = temp;
	}
	AITile.DemolishTile(top_left_tile);
	AITile.DemolishTile(GetTileRelative(top_left_tile, width + 1, height + 1));
	
	
	Sign(GetTileRelative(top_left_tile, 0, 0), "Corner 1");
	Sign(GetTileRelative(top_left_tile, width, height), "Corner 2");
	
	AITile.LevelTiles(top_left_tile, GetTileRelative(top_left_tile, width + 1, height + 1));
	
	//TODO: Set railtype that we're using, how does this change?
	local types = AIRailTypeList();
	AIRail.SetCurrentRailType(types.Begin());

	
	//TODO: We only handle terminuses at this point
	//Determine if top_left_tile is towards the city or not
	if(AIMap.DistanceManhattan(AITown.GetLocation(townId), top_left_tile) > AIMap.DistanceManhattan(AITown.GetLocation(townId), GetTileRelative(top_left_tile, width, height))) {
		//Shoot, it's backwards, we'll get around to this later	
		//I think this is somewhere else already?
	}
	
	local stationId;
	
	if(horz && !shift) {
		LogManager.Log("Building normal, horizontal configuration", 3);
		//We shift the actual tile so that we have room for the bus stations
		top_left_tile = GetTileRelative(top_left_tile, 2, 0);
		
		local success = AIRail.BuildRailStation(GetTileRelative(top_left_tile, 0, 2), AIRail.RAILTRACK_NW_SE, platforms, RAIL_STATION_PLATFORM_LENGTH, AIBaseStation.STATION_NEW);

		if(!success) {
			LogManager.Log(AIError.GetLastErrorString(), 4);
			return false;
		}
		
		stationId = AIStation.GetStationID(GetTileRelative(top_left_tile, 0, 2));
		
		local turn_tile = GetTileRelative(top_left_tile, platforms, 0);
		AIRail.BuildRailTrack(turn_tile, AIRail.RAILTRACK_NE_SE);
		AIRail.BuildSignal(turn_tile, GetTileRelative(turn_tile, -1, 0), AIRail.SIGNALTYPE_NORMAL);
		
		//The next two things build the loop around back...only for terminus
		if(is_terminus) {
			for(local i = 0; i < platforms; i++) {
				local tile = GetTileRelative(top_left_tile, i, 0);
				AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_SW_SE);
				AIRail.BuildRailTrack(GetTileRelative(top_left_tile, i, 1), AIRail.RAILTRACK_NW_SE);
				AIRail.BuildSignal(GetTileRelative(top_left_tile, i, 1), GetTileRelative(top_left_tile, i, 2), AIRail.SIGNALTYPE_PBS);
			}
			for(local i = 1; i < platforms; i++) {
				local tile = GetTileRelative(top_left_tile, i, 0);
				AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NE_SW);
			}		
			local signal_tile = false;
			local exit_tile = turn_tile;
			for(local i = 1; i <= RAIL_STATION_PLATFORM_LENGTH + platforms + 1; i++) {
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
		}
		
		local build_tile = true;
		local start_tile = GetTileRelative(top_left_tile, -1, 2);
		for(local i = 0; i < RAIL_STATION_PLATFORM_LENGTH; i++) {
			local active_tile = GetTileRelative(start_tile, 0, i);
			local front_tile  = GetTileRelative(start_tile, -1, i);
			if(build_tile) {
				success = AIRoad.BuildRoadStation(active_tile, front_tile, AIRoad.ROADVEHTYPE_BUS, stationId);
				AIRoad.BuildRoad(active_tile, front_tile);
				build_tile = false;
			} else {
				build_tile = true;
			}
			AIRoad.BuildRoad(front_tile, GetTileRelative(start_tile, -1, i + 1));
		}
		ZooElite.LinkTileToTown(start_tile, townId);
		
		
	} else if (horz && shift) {
		LogManager.Log("Building flipped, horizontal configuration", 3);
		//This is tough because we literally want to spin the entire station 180 degrees
		local bot_right = GetTileRelative(top_left_tile, width, height);
		
		//We shift the actual tile so that we have room for the bus stations
		bot_right = GetTileRelative(bot_right, -2, 0);
		
		local success = AIRail.BuildRailStation(GetTileRelative(bot_right, -1 * platforms, -RAIL_STATION_PLATFORM_LENGTH - 1), AIRail.RAILTRACK_NW_SE, platforms, RAIL_STATION_PLATFORM_LENGTH, AIBaseStation.STATION_NEW);
		LogManager.Log(AIError.GetLastErrorString(), 4);
		if(!success)
			return false;
		stationId = AIStation.GetStationID(GetTileRelative(bot_right, -1 * platforms, -RAIL_STATION_PLATFORM_LENGTH - 1));
		local turn_tile = GetTileRelative(bot_right, -1 * platforms - 1, 0);
		AIRail.BuildRailTrack(turn_tile, AIRail.RAILTRACK_NW_SW);
		AIRail.BuildSignal(turn_tile, GetTileRelative(turn_tile, 1, 0), AIRail.SIGNALTYPE_NORMAL);
		for(local i = 0; i < platforms; i++) {
			local tile = GetTileRelative(bot_right, -i - 1, 0);
			AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NW_NE);
			AIRail.BuildRailTrack(GetTileRelative(bot_right, -i - 1, -1), AIRail.RAILTRACK_NW_SE);
			AIRail.BuildSignal(GetTileRelative(bot_right, -i - 1, -1), GetTileRelative(bot_right, -i - 1, -2), AIRail.SIGNALTYPE_PBS);
		}
		for(local i = 1; i < platforms; i++) {
			local tile = GetTileRelative(bot_right, -i - 1, 0);
			AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NE_SW);
		}
		
		local signal_tile = false;
		local exit_tile = turn_tile;
		for(local i = 1; i <= RAIL_STATION_PLATFORM_LENGTH + platforms + 1; i++) {
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
		
		local build_tile = true;
		local start_tile = GetTileRelative(bot_right, 0, -2);
		for(local i = 0; i < RAIL_STATION_PLATFORM_LENGTH; i++) {
			local active_tile = GetTileRelative(start_tile, 0, -i);
			local front_tile  = GetTileRelative(start_tile, 1, -i);
			if(build_tile) {
				success = AIRoad.BuildRoadStation(active_tile, front_tile, AIRoad.ROADVEHTYPE_BUS, stationId);
				AIRoad.BuildRoad(active_tile, front_tile);
				build_tile = false;
			} else {
				build_tile = true;
			}
			AIRoad.BuildRoad(front_tile, GetTileRelative(start_tile, 1, -i - 1));
		}
		ZooElite.LinkTileToTown(start_tile, townId);
		
	} else if(!horz && !shift) {
		LogManager.Log("Building normal, vertical configuration", 3);
		local bot_right = GetTileRelative(top_left_tile, width, height);
		local success = AIRail.BuildRailStation(GetTileRelative(top_left_tile, 2, 1), AIRail.RAILTRACK_NE_SW, platforms, RAIL_STATION_PLATFORM_LENGTH, AIBaseStation.STATION_NEW);
		if(!success)
			return false;
		stationId = AIStation.GetStationID(GetTileRelative(top_left_tile, 2, 1));
		//Build rail around
		AIRail.BuildRailTrack(top_left_tile, AIRail.RAILTRACK_SW_SE);
		AIRail.BuildSignal(top_left_tile, GetTileRelative(top_left_tile, 0, 1), AIRail.SIGNALTYPE_NORMAL);
		local turn_tile = top_left_tile;
		
		for(local i = 1; i <= platforms; i++) {
			local tile = GetTileRelative(top_left_tile, 0, i);
			AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NW_SW);
			AIRail.BuildRailTrack(GetTileRelative(top_left_tile, 1, i), AIRail.RAILTRACK_NE_SW);
			AIRail.BuildSignal(GetTileRelative(top_left_tile, 1, i), GetTileRelative(top_left_tile, 2, i), AIRail.SIGNALTYPE_PBS);
		}
		for(local i = 1; i < platforms; i++) {
			local tile = GetTileRelative(top_left_tile, 0, i);
			AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NW_SE);
		}
		
		local signal_tile = false;
		local exit_tile = turn_tile;
		for(local i = 1; i <= RAIL_STATION_PLATFORM_LENGTH + platforms + 1; i++) {
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
		
		local build_tile = true;
		local start_tile = GetTileRelative(top_left_tile, 2, platforms + 1);
		for(local i = 0; i < RAIL_STATION_PLATFORM_LENGTH; i++) {
			local active_tile = GetTileRelative(start_tile, i, 0);
			local front_tile  = GetTileRelative(start_tile, i, 1);
			if(build_tile) {
				success = AIRoad.BuildRoadStation(active_tile, front_tile, AIRoad.ROADVEHTYPE_BUS, stationId);
				AIRoad.BuildRoad(active_tile, front_tile);
				build_tile = false;
			} else {
				build_tile = true;
			}
			AIRoad.BuildRoad(front_tile, GetTileRelative(start_tile, i + 1, 1));
		}
		ZooElite.LinkTileToTown(start_tile, townId);
		
	} else if(!horz && shift) {
		LogManager.Log("Building flipped, vertical configuration", 3);
		local bot_right = GetTileRelative(top_left_tile, width, height);
		local success = AIRail.BuildRailStation(GetTileRelative(bot_right, -1 * RAIL_STATION_PLATFORM_LENGTH - 1, -1 * platforms), AIRail.RAILTRACK_NE_SW, platforms, RAIL_STATION_PLATFORM_LENGTH, AIBaseStation.STATION_NEW);
		if(!success)
			return false;
		stationId = AIStation.GetStationID(GetTileRelative(bot_right, -1 * RAIL_STATION_PLATFORM_LENGTH - 1, -1 * platforms));
		//Build rail around
		AIRail.BuildRailTrack(bot_right, AIRail.RAILTRACK_NW_NE);
		AIRail.BuildSignal(bot_right, GetTileRelative(bot_right, -1, 0), AIRail.SIGNALTYPE_NORMAL);
		local turn_tile = bot_right;
		
		for(local i = 1; i <= platforms; i++) {
			local tile = GetTileRelative(bot_right, 0, -i);
			AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NE_SE);
			AIRail.BuildRailTrack(GetTileRelative(bot_right, -1, -i), AIRail.RAILTRACK_NE_SW);
			AIRail.BuildSignal(GetTileRelative(bot_right, -1, -i), GetTileRelative(bot_right, -2, -i), AIRail.SIGNALTYPE_PBS);
		}
		for(local i = 1; i < platforms; i++) {
			local tile = GetTileRelative(bot_right, 0, -i);
			AIRail.BuildRailTrack(tile, AIRail.RAILTRACK_NW_SE);
		}
		
		local signal_tile = false;
		local exit_tile = turn_tile;
		for(local i = 1; i <= RAIL_STATION_PLATFORM_LENGTH + platforms + 1; i++) {
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
		local build_tile = true;
		local start_tile = GetTileRelative(bot_right, -2, -platforms - 1);
		for(local i = 0; i < RAIL_STATION_PLATFORM_LENGTH; i++) {
			local active_tile = GetTileRelative(start_tile, -i, 0);
			local front_tile  = GetTileRelative(start_tile, -i, -1);
			if(build_tile) {
				success = AIRoad.BuildRoadStation(active_tile, front_tile, AIRoad.ROADVEHTYPE_BUS, stationId);
				AIRoad.BuildRoad(active_tile, front_tile);
				build_tile = false;
			} else {
				build_tile = true;
			}
			AIRoad.BuildRoad(front_tile, GetTileRelative(start_tile, -i - 1, -1));
		}
		ZooElite.LinkTileToTown(start_tile, townId);
	}
	return stationId;
	
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
