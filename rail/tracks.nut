//tracks.nut
//require("util/direction.nut");

function ZooElite::ConnectStations(stationId1, stationId2) {
	LogManager.Log("Connecting Stations: " + stationId1 + " and " + stationId2, 4);
	
	ClearSigns();
	station_table[stationId1].signStation();
	station_table[stationId2].signStation();

		dtp = ai_instance.dtp;
		//a little sketchy on why the getoppositepart thing is used. might not be neccesary. still need to work on this.
		LogManager.Log("direction of station2 is: " + station_table[stationId2].station_dir[0], 4);
		
		//the tiles that we will pass to the path finder
		local station1_tile;
		local station2_tile;
		local dirIndex1;
		local dirIndex2;

		
		/* PATHING FROM THIS STATION */
		
		//dealing with terminal station with only 1 directions:
		if(station_table[stationId2].station_dir.len() == 1) {
			//must use the only direction
			dirIndex2 = 0;
			//make it connect up right depending on station orientation.
			if(station_table[stationId2].station_dir[0] == dtp.SN_LINE) {
				station2_tile = station_table[stationId2].exit_tile;
			}
			else if (station_table[stationId2].station_dir[0] == dtp.NS_LINE) {
				station2_tile = GetTileRelative(station_table[stationId2].enter_tile, 0, 1);
			}
			else if (station_table[stationId2].station_dir[0] == dtp.WE_LINE) {
				station2_tile = station_table[stationId2].enter_tile;
			}
			else if (station_table[stationId2].station_dir[0] == dtp.EW_LINE) {
				station2_tile = GetTileRelative(station_table[stationId2].exit_tile, 1, 0);
			}			
		}
		
		//non termial station, must choose the side to connect to
		if(station_table[stationId2].station_dir.len() == 2) {
			//if its a NS/SN station
			if(station_table[stationId2].station_dir[0] == dtp.NS_LINE) {
				if(AIMap.GetTileY(AIBaseStation.GetLocation(station_table[stationId2].stationId)) >
					AIMap.GetTileY(AIBaseStation.GetLocation(station_table[stationId1].stationId)) ) {
					//then our station is more north so should use the NS-direction
					dirIndex2 = 0;
				}
				else {
					dirIndex2 = 1;
				}
			}
			//if its a EW/WE station
			if(station_table[stationId2].station_dir[0] == dtp.EW_LINE) {
				if(AIMap.GetTileX(AIBaseStation.GetLocation(station_table[stationId2].stationId)) >
					AIMap.GetTileX(AIBaseStation.GetLocation(station_table[stationId1].stationId)) ) {
					//then our station is more ease so should use the EW-direction
					dirIndex2 = 0;
				}
				else {
					dirIndex2 = 1;
				}
			}
			
			//now choose the proper tiles to path to: (remember REGIONAL station)
			if(station_table[stationId2].station_dir[dirIndex2] == dtp.SN_LINE) {
				LogManager.Log("SN_LINE", 4);
				local exitside = station_table[stationId2].exit2_tile;
				local enterside = station_table[stationId2].enter2_tile;
				if(Direction.GetDirectionsToTile(exitside, enterside).first == Direction.EAST) station2_tile = enterside;
				else station2_tile = exitside;				
			}
			else if (station_table[stationId2].station_dir[dirIndex2] == dtp.NS_LINE) {
				local exitside = GetTileRelative(station_table[stationId2].exit_tile, 0, 1);
				local enterside = GetTileRelative(station_table[stationId2].enter_tile, 0, 1);
				if(Direction.GetDirectionsToTile(exitside, enterside).first == Direction.EAST) station2_tile = enterside;
				else station2_tile = exitside;
			}
			else if (station_table[stationId2].station_dir[dirIndex2] == dtp.WE_LINE) {
				local exitside = station_table[stationId2].exit2_tile;
				local enterside = station_table[stationId2].enter2_tile;
				if(Direction.GetDirectionsToTile(exitside, enterside).first == Direction.NORTH) station2_tile = enterside;
				else station2_tile = exitside;
			}
			else if (station_table[stationId2].station_dir[dirIndex2] == dtp.EW_LINE) {
				local exitside = GetTileRelative(station_table[stationId2].exit_tile, 1, 0);
				local enterside = GetTileRelative(station_table[stationId2].enter_tile, 1, 0);
				if(Direction.GetDirectionsToTile(exitside, enterside).first == Direction.NORTH) station2_tile = enterside;
				else station2_tile = exitside;
			}
		}
		
		//-------------------------------------------//
		//-------------------------------------------//
		/*PATHING TO THIS STATION */
		
		//if its a TERMINAL station
		if(station_table[stationId1].station_dir.len() == 1) {
			//must use the only direction
			dirIndex1 = 0;
			//make it connect up right depending on station orientation.
			if(station_table[stationId1].station_dir[0] == dtp.SN_LINE) {
				station1_tile = station_table[stationId1].exit_tile2;
			}
			else if (station_table[stationId1].station_dir[0] == dtp.NS_LINE) {
				station1_tile = station_table[stationId1].enter_tile;
			}	
			else if (station_table[stationId1].station_dir[0] == dtp.WE_LINE) {
				station1_tile = station_table[stationId1].enter_tile2;
			}
			else if (station_table[stationId1].station_dir[0] == dtp.EW_LINE) {
				station1_tile = station_table[stationId1].exit_tile;
			}
		}
		
		//non termial station, must choose the side to connect to
		if(station_table[stationId1].station_dir.len() == 2) {
			//if its a NS/SN station
			if(station_table[stationId1].station_dir[0] == dtp.NS_LINE) {
				if(AIMap.GetTileY(AIBaseStation.GetLocation(station_table[stationId1].stationId)) >
					AIMap.GetTileY(AIBaseStation.GetLocation(station_table[stationId2].stationId)) ) {
					//then our station is more north so should use the NS-direction
					dirIndex1 = 0;
				}
				else {
					dirIndex1 = 1;
				}
			}
			//if its a EW/WE station
			if(station_table[stationId1].station_dir[0] == dtp.EW_LINE) {
				if(AIMap.GetTileX(AIBaseStation.GetLocation(station_table[stationId1].stationId)) >
					AIMap.GetTileX(AIBaseStation.GetLocation(station_table[stationId2].stationId)) ) {
					//then our station is more ease so should use the EW-direction
					dirIndex1 = 0;
				}
				else {
					dirIndex1 = 1;
				}
			}
			
			//no choose pathing tile. (Remember: this is NONTERIMAL station going TO IT)
			if(station_table[stationId1].station_dir[dirIndex1] == dtp.SN_LINE) {
				LogManager.Log("SN_LINE", 4);
				local exitside = station_table[stationId1].exit2_tile2;
				local enterside = station_table[stationId1].enter2_tile2;
				if(Direction.GetDirectionsToTile(exitside, enterside).first == Direction.EAST) station1_tile = enterside;
				else station1_tile = exitside;
			}
			else if (station_table[stationId1].station_dir[dirIndex1] == dtp.NS_LINE) {
				local exitside = station_table[stationId1].exit_tile;
				local enterside = station_table[stationId1].enter_tile;
				if(Direction.GetDirectionsToTile(exitside, enterside).first == Direction.EAST) station1_tile = enterside;
				else station1_tile = exitside;
			}	
			else if (station_table[stationId1].station_dir[dirIndex1] == dtp.WE_LINE) {
				local exitside = station_table[stationId1].exit2_tile2;
				local enterside = station_table[stationId1].enter2_tile2;
				if(Direction.GetDirectionsToTile(exitside, enterside).first == Direction.NORTH) station1_tile = enterside;
				else station1_tile = exitside;
			}
			else if (station_table[stationId1].station_dir[dirIndex1] == dtp.EW_LINE) {
				local exitside = station_table[stationId1].exit_tile;
				local enterside = station_table[stationId1].enter_tile;
				if(Direction.GetDirectionsToTile(exitside, enterside).first == Direction.NORTH) station1_tile = enterside;
				else station1_tile = exitside;
			}
		}
		
		
		local drrb = DoubleRailroadBuilder(station2_tile, station1_tile, station_table[stationId2].station_dir[dirIndex2], 
											dtp.GetOppositePart(station_table[stationId1].station_dir[dirIndex1]));
				
		drrb.BuildTrack();
		
		station_table[stationId1].route_connected = true;
		station_table[stationId2].route_connected = true;
				
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