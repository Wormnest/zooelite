/*
 * This file is part of ZooElite, an OpenTTD AI
 *
 */
import("pathfinder.road", "RoadPathFinder", 3);
require("log_manager.nut");
require("constants.nut");
require("helper.nut");
require("RoutePlanner.nut");


class ZooElite extends AIController {
	function Start();
	var = 0;
	
}

require("road/road.nut");
require("road/builder.nut");
require("road/placer.nut");
require("rail/finder.nut");

function ZooElite::Start() {
	LogManager.Log("Starting up!", 3);
	AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
	local towns = AITownList();
	towns.Valuate(AITown.GetPopulation);
	towns.Sort(AIAbstractList.SORT_BY_VALUE, false);
	//RoutePlanner.getRegionalStations();
	local center_tile = AIMap.GetTileIndex(AIMap.GetMapSizeX() / 2, AIMap.GetMapSizeY() / 2);
	foreach(town, townIndex in towns) {
		//Inputs: town, in_direction_of_tile, platforms, is_terminus(should be true)
		//ZooElite.BuildRailStationForTown(town, center_tile, 2, true);
		//ZooElite.BuildMaxBusStationsInTown(town);
	}
	
	
	
		
	// Make sure we can actually operate
	if(AIGameSettings.IsDisabledVehicleType(AIVehicle.VT_RAIL) ||
		(AIGameSettings.IsValid("vehicle.max_trains") &&
		AIGameSettings.GetValue("vehicle.max_trains") == 0)){

		LogManager.Log("I can only play with road vehicles and trains and they are disabled.", 5);
		return;
	}
	if(AIGameSettings.IsDisabledVehicleType(AIVehicle.VT_ROAD) ||
		(AIGameSettings.IsValid("vehicle.max_roadveh") &&
		AIGameSettings.GetValue("vehicle.max_roadveh") == 0)){

		LogManager.Log("I can only play with road vehicles and trains and they are disabled.", 5);
		return;
	}
	
	
	//Name the company and setup cosmetic details
	if (!AICompany.SetName("ZooElite")) {
		local i = 2;
		while (!AICompany.SetName("ZooElite #" + i)) {
		  i = i + 1;
		}
	  }
	  AICompany.SetPresidentName("C.C. Ubuntu");
	  //TODO: Figure out how to access Enums
	  //AICompany.SetPresidentGender(AICompany::Gender.size());
	  AICompany.SetPresidentGender(AICompany.GENDER_MALE);


	if (AIGameSettings.GetValue("difficulty.vehicle_breakdowns") >= 1) {
		LogManager.Log("Breakdowns are on or the setting always_autorenew is on, so enabling autorenew", 1);
		AICompany.SetAutoRenewMonths(-3);
		AICompany.SetAutoRenewStatus(true);
	} else {
		LogManager.Log("Breakdowns are off, so disabling autorenew");
		AICompany.SetAutoRenewStatus(false);
	}
	while (true) {
		if(AICompany.GetBankBalance(AICompany.COMPANY_SELF) > 50000) {
			//this.CityPairing();
			if(AICompany.GetLoanAmount() > 50000)
				AICompany.SetLoanAmount(AICompany.GetLoanAmount() * 2 / 3);
		}
		//LogManager.Log("I am a new AI with a ticker and I am at tick " + this.GetTick() + " with bank bal " + AICompany.GetBankBalance(AICompany.COMPANY_SELF));
		this.Sleep(1000);
		
	}
}

function ZooElite::CityPairing() {
	//TODO: Ensure it's not already covered
	local towns1 = AITownList();
	local towns2 = AITownList();
	local score = 0;
	local pair1;
	local pair2;
	foreach(index1, townID1 in towns1) {
		foreach(index2, townID2 in towns2) {
			local pair_score;
			if(index1 != index2 && !this.CheckPair(index1, index2)) {
				local pop1 = AITown.GetPopulation(index1);
				local pop2 = AITown.GetPopulation(index2);
				local distance = AITown.GetDistanceManhattanToTile(index1, AITown.GetLocation(index2));
				local pop_diff = abs(pop1-pop2);
				local divisor = (distance / 40 + pop_diff / 600);
				if(divisor == 0)
					divisor = 1;
				pair_score = (pop1 + pop2) / divisor;
				//LogManager.Log("Comparing " + AITown.GetName(index1) + " and " + AITown.GetName(index2) + " for score of " + pair_score);
				if(pair_score > score) {
					pair1 = index1;
					pair2 = index2;
					score = pair_score;
				}
			}
		}
	}
	//Check to see if there is perhaps a city or two inbetween them...
	LogManager.Log("Found max score to be " + score + " with " + AITown.GetName(pair1) + " and " + AITown.GetName(pair2) + "...proceeding to build route",3);
	this.LinkTownsByBus(pair1,pair2);
	this.SavePair(pair1,pair2);
	local primary_distance = AITown.GetDistanceManhattanToTile(pair1, AITown.GetLocation(pair2));
	foreach(index, townID in towns1) {
		if(AITown.GetDistanceManhattanToTile(pair1, AITown.GetLocation(index)) < (0.8 * primary_distance) && AITown.GetDistanceManhattanToTile(pair2, AITown.GetLocation(index)) < (0.8 * primary_distance)) {
			LogManager.Log("Also located potential middle town: " + AITown.GetName(index), 3);
			this.LinkTownsByBus(index,pair1);
			this.SavePair(index,pair2);
			this.LinkTownsByBus(index,pair2);
			this.SavePair(index, pair2);
		}
	}
	

	
}

function ZooElite::LinkTownsByBus(townID1, townID2) {
	LogManager.Log("Attempting to build bus route between " + AITown.GetName(townID1) + " and " + AITown.GetName(townID2), 3);
	/* Tell OpenTTD we want to build normal road (no tram tracks). */
	AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
	
	//IF WE ALREADY HAVE STATIONS HERE...SKIP IT!
	LogManager.Log("Buiding Stations...", 2);
	local station1;
	local station2;
	local stations = AIStationList(AIStation.STATION_BUS_STOP);
	stations.Valuate(AIStation.GetNearestTown);
	stations.KeepValue(townID1);
	if(stations.Count() > 0) {
		LogManager.Log("Existing station found1", 2);
		station1 = stations.Begin();
		station1 = AIBaseStation.GetLocation(station1);
	} else
		station1 = this.GetOptimalStationLocation(townID1);
	stations = AIStationList(AIStation.STATION_BUS_STOP);
	stations.Valuate(AIStation.GetNearestTown);
	stations.KeepValue(townID2);
	if(stations.Count() > 0) {
		LogManager.Log("Existing station found2", 2);
		station2 = stations.Begin();
		station2 = AIBaseStation.GetLocation(station2);
	} else
		station2 = this.GetOptimalStationLocation(townID2);

	
	
	/* Create an instance of the pathfinder. */
	local pathfinder = RoadPathFinder();
	/* Set the cost for making a turn extremely high. */
	pathfinder.cost.turn = 500;
	pathfinder.cost.no_existing_road = 80;
	
	//TODO: Add some Intelligence to figure out if we can afford things based on available cash / master plan
	pathfinder.cost.tunnel_per_tile = 200;
	LogManager.Log("Joining Stations: " + station1 + " and " + station2, 3);
	pathfinder.InitializePath([station1], [station2]);

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

  	local length = 0;
  	local length_cur = 0;
  	local temppath = path;
  	local depot_built = false;
	local depot_tile = 0;
  	
	/* If a path was found, build a road over it. */
	//AND FIND SUITABLE STATION SPOT
	while (path != null) {
		local par = path.GetParent();
		length++;
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
	
	//Cycle again to build a depot
	while (temppath != null) {
		length_cur++;
		temppath = temppath.GetParent();
		if(temppath!= null && !depot_built && length/2 <= length_cur) {
				local path_tile = temppath.GetTile();
				local build_tile = AIMap.GetTileIndex(AIMap.GetTileX(path_tile), AIMap.GetTileY(path_tile) + 1);
				//Check to ensure we aren't trying to build parrallel with the road
				if(AIRoad.IsRoadTile(build_tile)) {
					build_tile = AIMap.GetTileIndex(AIMap.GetTileX(path_tile) + 1, AIMap.GetTileY(path_tile));
					//Try the other side of the road too
					if(AITile.GetMaxHeight(build_tile) != AITile.GetMaxHeight(temppath.GetTile())
						|| AITile.GetSlope(temppath.GetTile()) != AITile.SLOPE_FLAT)
						build_tile = AIMap.GetTileIndex(AIMap.GetTileX(path_tile) - 1, AIMap.GetTileY(path_tile));
					
					if(AITile.GetMaxHeight(build_tile) == AITile.GetMaxHeight(temppath.GetTile())
						&& AITile.GetSlope(temppath.GetTile()) == AITile.SLOPE_FLAT)
						depot_built = AIRoad.BuildRoadDepot(build_tile, temppath.GetTile());
					
				} else {
					//Same checks as above
					if(AITile.GetMaxHeight(build_tile) != AITile.GetMaxHeight(temppath.GetTile())
						|| AITile.GetSlope(temppath.GetTile()) != AITile.SLOPE_FLAT)
						build_tile = AIMap.GetTileIndex(AIMap.GetTileX(path_tile), AIMap.GetTileY(path_tile) - 1);
					if(AITile.GetMaxHeight(build_tile) == AITile.GetMaxHeight(temppath.GetTile())
						&& AITile.GetSlope(temppath.GetTile()) == AITile.SLOPE_FLAT)
						depot_built = AIRoad.BuildRoadDepot(build_tile, temppath.GetTile());
				}
				LogManager.Log("Trying to build Depot..." + path_tile + " " + build_tile, 2);		
				if(depot_built) {
					AIRoad.BuildRoad(build_tile, temppath.GetTile());	
					depot_tile = build_tile;
				}	
			}
	}
	local stationList = AIList();
	stationList.AddItem(station1, station1);
	stationList.AddItem(station2, station1);
	this.CreateNewRoute(depot_tile, AICargo.CC_PASSENGERS , 6, stationList);
	
}

function ZooElite::GetOptimalStationLocation(townId) {
	local tilelist = AITileList();
	local seed_tile = AITown.GetLocation(townId);
	
	tilelist.AddRectangle(AIMap.GetTileIndex(AIMap.GetTileX(seed_tile) - 3, AIMap.GetTileY(seed_tile) - 3),
							AIMap.GetTileIndex(AIMap.GetTileX(seed_tile) + 3, AIMap.GetTileY(seed_tile)) + 3); 
	//Create TileList to check against and check each tile to get it's 
	tilelist.Valuate(AITile.GetCargoProduction, AICargo.CC_MAIL, 1, 1, 4);
	tilelist.Sort(AIAbstractList.SORT_BY_VALUE, false);
	local success = false;
	for(local tileIndex = tilelist.Begin(); tilelist.HasNext(); tileIndex = tilelist.Next()) {
		
		local cargoAmt = AITile.GetCargoProduction(tileIndex, AICargo.CC_MAIL, 1, 1, 3);
		//LogManager.Log("Evaluating tile " + tileIndex + " cargo prod: " + cargoAmt);
		//try to buld
		local temptilelist = AITileList();
		temptilelist.AddRectangle(AIMap.GetTileIndex(AIMap.GetTileX(tileIndex) + 1, AIMap.GetTileY(tileIndex) - 1),
								AIMap.GetTileIndex(AIMap.GetTileX(tileIndex) + 1, AIMap.GetTileY(tileIndex)) + 1); 
		foreach(frontTileIndex, frontTile in temptilelist) {
			if(AIRoad.IsRoadTile(frontTileIndex) && AIMap.DistanceManhattan(frontTileIndex, tileIndex) == 1) {
				if(AIRoad.IsRoadTile(tileIndex)) {	
					if(!success) {
						success = AIRoad.BuildDriveThroughRoadStation(tileIndex, frontTileIndex, AIRoad.ROADVEHTYPE_BUS, AIStation.STATION_NEW);
						AIRoad.BuildRoad(tileIndex, frontTileIndex);
						if(success)
							return tileIndex;
					}
				} else {
					if(!success) {
						success = AIRoad.BuildRoadStation(tileIndex, frontTileIndex, AIRoad.ROADVEHTYPE_BUS, AIStation.STATION_NEW);
						AIRoad.BuildRoad(tileIndex, frontTileIndex);
						if(success)
							return tileIndex;
					}
				}
			}
		}
			
	}
	/*
	//IGNORE CLOSE STATIONS FOR NOW
	local stationsbydistance = AIStationList();
	// Start with town with biggest POP and walk down, for easier debugging
	stationsbytown.Valuate(AIMap.DistanceManhattan(AIStation.GetTile));
	serviced_towns.Sort(AIAbstractList.SORT_BY_VALUE, false); // highest value first
	*/
	
	//Check cargo production for each
	//AITile::GetCargoProduction
}

function ZooElite::CreateNewRoute(depot_tile, cargoType, clones, stationList) {
	LogManager.Log("Creating new vehicles for route", 3);
	//What is passanger cargo?
	local cargoList = AICargoList();
	cargoList.Valuate(AICargo.HasCargoClass, cargoType);
	cargoList.KeepValue(1);
	if (cargoList.Count() == 0) AILog.Error("Your game doesn't have any passengers cargo, and as we are a passenger only AI, we can't do anything", 5);
	local paxCargo = cargoList.Begin();

	
	
	//Select Vehicle To Use
	local seed_vehicle;
	local enginelist = AIEngineList(AIVehicle.VT_ROAD);
	enginelist.Valuate(AIEngine.GetCargoType);
	enginelist.RemoveAboveValue(paxCargo);
	enginelist.RemoveBelowValue(paxCargo);
	enginelist.Valuate(AIEngine.GetCapacity);
	enginelist.Sort(AIAbstractList.SORT_BY_VALUE, false);
	local engineID = enginelist.Begin();
	
	//Build, give orders, clone and dispatch
	//LogManager.Log("Building vehicles to haul " + AICargo.GetCargoLabel(AIEngine.GetCargoType(engineID)) + " Wanted: " + paxCargo + AICargo.GetCargoLabel(paxCargo));
	seed_vehicle = AIVehicle.BuildVehicle(depot_tile, engineID);
	foreach(stationID, station in stationList) {
		AIOrder.AppendOrder(seed_vehicle, stationID, AIOrder.AIOF_NONE);
	}
	//TODO: Group them all
	AIVehicle.StartStopVehicle(seed_vehicle);
	for(local i = 1; i <= clones; i++) {
		local new_vehicle = AIVehicle.CloneVehicle(depot_tile, seed_vehicle, true);
		AIOrder.SkipToOrder(new_vehicle, i);
		AIVehicle.StartStopVehicle(new_vehicle);
		this.Sleep(200);
	}
	
	
}

function ZooElite::SavePair(value1, value2) {
	city_pairs1.AddItem(this.pairs, value1);
	city_pairs2.AddItem(this.pairs, value2);
	this.pairs++;	
}

function ZooElite::CheckPair(value1, value2) {
	for(local i = 0; i <= pairs; i++) {
		local a = city_pairs1.GetValue(i);
		local b = city_pairs2.GetValue(i);
		if((a == value1 && b == value2) || (b == value1 && a == value2))
			return true;
	}
	return false;
	
}








	
