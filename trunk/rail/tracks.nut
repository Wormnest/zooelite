//tracks.nut
function ZooElite::ConnectStations(stationId1, stationId2) {
	LogManager.Log("Connecting Stations: " + stationId1 + " and " + stationId2, 4);
	
	ClearSigns();
	//station_table[stationId1].signStation();
	//station_table[stationId2].signStation();

		dtp = ai_instance.dtp;
		//a little sketchy on why the getoppositepart thing is used. might not be neccesary. still need to work on this.
		LogManager.Log("direction of station2 is: " + station_table[stationId2].station_dir, 4);
		local station1_tile;
		local station2_tile;
		
		//make it connect up right depending on station orientation.
		if(station_table[stationId2].station_dir == dtp.SN_LINE) {
			station2_tile = station_table[stationId2].exit_tile;
		}
		else if (station_table[stationId2].station_dir == dtp.NS_LINE) {
			station2_tile = GetTileRelative(station_table[stationId2].enter_tile, 0, 1);
		}
		else if (station_table[stationId2].station_dir == dtp.WE_LINE) {
			station2_tile = station_table[stationId2].enter_tile;
		}
		else if (station_table[stationId2].station_dir == dtp.EW_LINE) {
			station2_tile = GetTileRelative(station_table[stationId2].exit_tile, 1, 0);
		}
		
		
		if(station_table[stationId1].station_dir == dtp.SN_LINE) {
			station1_tile = station_table[stationId1].exit_tile2;
		}
		else if (station_table[stationId1].station_dir == dtp.NS_LINE) {
			station1_tile = station_table[stationId1].enter_tile;
		}
		else if (station_table[stationId1].station_dir == dtp.WE_LINE) {
			station1_tile = station_table[stationId1].enter_tile2;
		}
		else if (station_table[stationId1].station_dir == dtp.EW_LINE) {
			station1_tile = station_table[stationId1].exit_tile;
		}
		
		local drrb = DoubleRailroadBuilder(station2_tile, station1_tile, station_table[stationId2].station_dir, 
											dtp.GetOppositePart(station_table[stationId1].station_dir));
				
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