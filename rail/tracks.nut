//tracks.nut
//require("util/direction.nut");

function ZooElite::ConnectStations(stationId1, stationId2) {
	LogManager.Log("Connecting Stations: " + stationId1 + " and " + stationId2, 4);
	
	//for junctions
	local JUNCTION_GAP_SIZE = 5;
	local MAXIMUM_DISTANCE_JUNCTION_POINT = 15000;
	
	ClearSigns();
	//station_table[stationId1].signStation();
	//station_table[stationId2].signStation();

		dtp = ai_instance.dtp;
		//a little sketchy on why the getoppositepart thing is used. might not be neccesary. still need to work on this.
		LogManager.Log("direction of station2 is: " + station_table[stationId2].station_dir[0], 4);
		
		//the tiles that we will pass to the path finder
		local station1_tile;
		local station2_tile;
		local dirIndex1;
		local dirIndex2;
		
		local station2 = station_table[stationId2];
		local station1 = station_table[stationId1];

		
		/* PATHING FROM THIS STATION */
		//dealing with terminal station with only 1 directions:
		if(station2.station_dir.len() == 1) {
			//must use the only direction
			dirIndex2 = 0;

			//make it connect up right depending on station orientation.
			if(station2.station_dir[0] == dtp.SN_LINE) {
				station2_tile = station2.exit_tile;
			}	
			else if (station2.station_dir[0] == dtp.NS_LINE) {
				station2_tile = GetTileRelative(station2.enter_tile, 0, 1);
			}
			else if (station2.station_dir[0] == dtp.WE_LINE) {
				station2_tile = station2.enter_tile;
			}
			else if (station2.station_dir[0] == dtp.EW_LINE) {
				station2_tile = GetTileRelative(station2.exit_tile, 1, 0);
			}			
		}
		
		//non termial station, must choose the side to connect to
		if(station2.station_dir.len() == 2) {
			//if its a NS/SN station
			if(station2.station_dir[0] == dtp.NS_LINE) {
				if(AIMap.GetTileY(AIBaseStation.GetLocation(station2.stationId)) >
					AIMap.GetTileY(AIBaseStation.GetLocation(station1.stationId)) ) {
					//then our station is more north so should use the NS-direction
					dirIndex2 = 0;
				}
				else {
					dirIndex2 = 1;
				}
			}
			//if its a EW/WE station
			if(station2.station_dir[0] == dtp.EW_LINE) {
				if(AIMap.GetTileX(AIBaseStation.GetLocation(station2.stationId)) >
					AIMap.GetTileX(AIBaseStation.GetLocation(station1.stationId)) ) {
					//then our station is more ease so should use the EW-direction
					dirIndex2 = 0;
				}
				else {
					dirIndex2 = 1;
				}
			}
			
			//now choose the proper tiles to path to: (remember REGIONAL station)
			if(station2.station_dir[dirIndex2] == dtp.SN_LINE) {
				//LogManager.Log("SN_LINE", 4);
				local exitside = station2.exit2_tile;
				local enterside = station2.enter2_tile;
				if(Direction.GetDirectionsToTile(exitside, enterside).first == Direction.EAST) station2_tile = enterside;
				else station2_tile = exitside;				
			}
			else if (station2.station_dir[dirIndex2] == dtp.NS_LINE) {
				local exitside = GetTileRelative(station2.exit_tile, 0, 1);
				local enterside = GetTileRelative(station2.enter_tile, 0, 1);
				if(Direction.GetDirectionsToTile(exitside, enterside).first == Direction.EAST) station2_tile = enterside;
				else station2_tile = exitside;
			}
			else if (station2.station_dir[dirIndex2] == dtp.WE_LINE) {
				local exitside = station2.exit2_tile;
				local enterside = station2.enter2_tile;
				if(Direction.GetDirectionsToTile(exitside, enterside).first == Direction.NORTH) station2_tile = enterside;
				else station2_tile = exitside;
			}
			else if (station2.station_dir[dirIndex2] == dtp.EW_LINE) {
				local exitside = GetTileRelative(station2.exit_tile, 1, 0);
				local enterside = GetTileRelative(station2.enter_tile, 1, 0);
				if(Direction.GetDirectionsToTile(exitside, enterside).first == Direction.NORTH) station2_tile = enterside;
				else station2_tile = exitside;
			}
		}
		
		local station2_part = station2.station_dir[dirIndex2];
		
		//now finally we must check if all our work was in vain and we need a junction:
		if(station2.routes[dirIndex2] != null) {
			LogManager.Log("Need to buildJunction for station: " + station2.stationId, 4);
			local djb = DoubleJunctionBuilder([station2.routes[dirIndex2]],
										AIBaseStation.GetLocation(station1.stationId) , JUNCTION_GAP_SIZE , MAXIMUM_DISTANCE_JUNCTION_POINT);
			LogManager.Log("Path Tile: " + AIMap.GetTileY(station2.routes[dirIndex2].tile), 4);
			LogManager.Log("Station Tile: " + AIMap.GetTileY(AIBaseStation.GetLocation(station2.stationId)), 4);
			LogManager.Log("Prefered Direction: " + Direction.GetDirectionsToTile(AIBaseStation.GetLocation(station2.stationId), AIBaseStation.GetLocation(station1.stationId)).first, 4);
			local junction_information2 = djb.BuildJunction(Direction.GetDirectionsToTile(AIBaseStation.GetLocation(station1.stationId),
																					AIBaseStation.GetLocation(station2.stationId)).first);//aqui esta o erro (Nao so aqui)
			if(junction_information2 == null) {
				LogManager.Log("Junction construction failed", 4);
			}
			station2_tile = 0 - dtp.parts[junction_information2.junction_part_index].previous_part_offset + junction_information2.tile;
			station2_part = dtp.parts[junction_information2.junction_part_index].previous_part;
		}
		
		//-------------------------------------------//
		//-------------------------------------------//
		/*PATHING TO THIS STATION */
		
		//if its a TERMINAL station
		if(station1.station_dir.len() == 1) {
			//must use the only direction
			dirIndex1 = 0;
			//make it connect up right depending on station orientation.
			if(station1.station_dir[0] == dtp.SN_LINE) {
				station1_tile = station1.exit_tile2;
			}
			else if (station1.station_dir[0] == dtp.NS_LINE) {
				station1_tile = station1.enter_tile;
			}	
			else if (station1.station_dir[0] == dtp.WE_LINE) {
				station1_tile = station1.enter_tile2;
			}
			else if (station1.station_dir[0] == dtp.EW_LINE) {
				station1_tile = station1.exit_tile;
			}
		}
		
		//non termial station, must choose the side to connect to
		if(station1.station_dir.len() == 2) {
			//if its a NS/SN station
			if(station1.station_dir[0] == dtp.NS_LINE) {
				if(AIMap.GetTileY(AIBaseStation.GetLocation(station1.stationId)) >
					AIMap.GetTileY(AIBaseStation.GetLocation(station2.stationId)) ) {
					//then our station is more north so should use the NS-direction
					dirIndex1 = 0;
				}
				else {
					dirIndex1 = 1;
				}
			}
			//if its a EW/WE station
			if(station1.station_dir[0] == dtp.EW_LINE) {
				if(AIMap.GetTileX(AIBaseStation.GetLocation(station1.stationId)) >
					AIMap.GetTileX(AIBaseStation.GetLocation(station2.stationId)) ) {
					//then our station is more ease so should use the EW-direction
					dirIndex1 = 0;
				}
				else {
					dirIndex1 = 1;
				}
			}
			
			//no choose pathing tile. (Remember: this is NONTERIMAL station going TO IT)
			if(station1.station_dir[dirIndex1] == dtp.SN_LINE) {
				LogManager.Log("SN_LINE", 4);
				local exitside = station_table[stationId1].exit2_tile2;
				local enterside = station1.enter2_tile2;
				if(Direction.GetDirectionsToTile(exitside, enterside).first == Direction.EAST) station1_tile = enterside;
				else station1_tile = exitside;
			}
			else if (station1.station_dir[dirIndex1] == dtp.NS_LINE) {
				local exitside = station1.exit_tile;
				local enterside = station1.enter_tile;
				if(Direction.GetDirectionsToTile(exitside, enterside).first == Direction.EAST) station1_tile = enterside;
				else station1_tile = exitside;
			}	
			else if (station1.station_dir[dirIndex1] == dtp.WE_LINE) {
				local exitside = station1.exit2_tile2;
				local enterside = station1.enter2_tile2;
				if(Direction.GetDirectionsToTile(exitside, enterside).first == Direction.NORTH) station1_tile = enterside;
				else station1_tile = exitside;
			}
			else if (station1.station_dir[dirIndex1] == dtp.EW_LINE) {
				local exitside = station1.exit_tile;
				local enterside = station1.enter_tile;
				if(Direction.GetDirectionsToTile(exitside, enterside).first == Direction.NORTH) station1_tile = enterside;
				else station1_tile = exitside;
			}
		}
		
		local station1_part = station1.station_dir[dirIndex1];
		
		//now finally we must check if all our work was in vain and we need a junction:
		if(station1.routes[dirIndex1] != null) {
			LogManager.Log("Need to buildJunction for station: " + station1.stationId, 4);
			local djb = DoubleJunctionBuilder([station1.routes[dirIndex1]],
										AIBaseStation.GetLocation(station1.stationId) , JUNCTION_GAP_SIZE , MAXIMUM_DISTANCE_JUNCTION_POINT);
			local junction_information1 = djb.BuildJunction(Direction.GetDirectionsToTile(AIBaseStation.GetLocation(station2.stationId),
																					AIBaseStation.GetLocation(station1.stationId)).first);//aqui esta o erro (Nao so aqui)
			if(junction_information1 == null) {
				LogManager.Log("Junction1 construction failed", 4);
			}
			station1_tile = dtp.parts[junction_information1.junction_part_index].previous_part_offset + junction_information1.tile;
			station1_part = dtp.parts[junction_information1.junction_part_index].previous_part;
		}
		
		//--------------------------------//
		/////// BUILD TRACK  ////////////////
		local drrb = DoubleRailroadBuilder(station2_tile, station1_tile, station2_part, 
											dtp.GetOppositePart(station1_part));
				
		local double_railroad = drrb.BuildTrack();
		
		if(double_railroad != null) {
			station1.routes[dirIndex1] = double_railroad.path;
			station2.routes[dirIndex2] = double_railroad.path;
		}
				
	//I have no idea how this is supposed to work, but we're going to try it
	//Holder Function for rail builder

	/* Create an instance of the pathfinder. */
	//local pathfinder = RailPathFinder();
	/* Set the cost for making a turn high. */
/*	
	local from_tile = station_table[stationId1].exit_tile;
	local from_tile2 = station_table[stationId1].exit_tile2;
	local to_tile = station_table[stationId2].enter_tile;
	local to_tile2 = station_table[stationId2].enter_tile2;
	
	LogManager.Log("Pathing Stations from " + from_tile + " to " + to_tile, 4);
	Sign(from_tile, "Start1");
	Sign(from_tile2, "Start2");
	Sign(to_tile, "End1");
	Sign(to_tile2, "End2");
	AITile.DemolishTile(from_tile2);
	AITile.DemolishTile(to_tile2);
	pathfinder.InitializePath([[from_tile2, from_tile]], [[to_tile2, to_tile]]);
	

	/* Try to find a path. */
 /* local path = false;
  while (path == false) {
	path = pathfinder.FindPath(-1);
	this.Sleep(1);
  }

  
  if (path == null) {
	/* No path was found. */
/*	LogManager.Log("pathfinder.FindPath return null", 5);
	return false;
  }
  	
	local prev = null;
	local prevprev = null;
	while (path != null) {
	  if (prevprev != null) {
	    if (AIMap.DistanceManhattan(prev, path.GetTile()) > 1) {
	      if (AITunnel.GetOtherTunnelEnd(prev) == path.GetTile()) {
	        AITunnel.BuildTunnel(AIVehicle.VT_RAIL, prev);
	      } else {
	        local bridge_list = AIBridgeList_Length(AIMap.DistanceManhattan(path.GetTile(), prev) + 1);
	        bridge_list.Valuate(AIBridge.GetMaxSpeed);
	        bridge_list.Sort(AIAbstractList.SORT_BY_VALUE, false);
	        AIBridge.BuildBridge(AIVehicle.VT_RAIL, bridge_list.Begin(), prev, path.GetTile());
	      }
	      prevprev = prev;
	      prev = path.GetTile();
	      path = path.GetParent();
	    } else {
	      AIRail.BuildRail(prevprev, prev, path.GetTile());
	    }
	  }
	  if (path != null) {
	    prevprev = prev;
	    prev = path.GetTile();
	    path = path.GetParent();
	  }
	}
	*/

	LogManager.Log("Pathing Done!", 2);
}