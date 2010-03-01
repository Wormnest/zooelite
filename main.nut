/*
 * This file is part of ZooElite, an OpenTTD AI
 *
 */
import("pathfinder.road", "RoadPathFinder", 3);
import("pathfinder.rail", "RailPathFinder", 1);
require("log_manager.nut");
require("constants.nut");
require("helper.nut");
require("RoutePlanner.nut");


class ZooElite extends AIController {
	function Start();
	town_table = {};
	station_table = {};
	
}

require("road/road.nut");
require("road/builder.nut");
require("road/placer.nut");
require("road/vehicle.nut");
require("rail/finder.nut");
require("rail/tracks.nut");
require("obects/town.nut");
require("obects/station.nut");

function ZooElite::Start() {
	this.Sleep(1);
	LogManager.Log("Starting up!", 3);
		
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
	
	
	AIRoad.SetCurrentRoadType(AIRoad.ROADTYPE_ROAD);
	local towns = AITownList();
	towns.Valuate(AITown.GetPopulation);
	//towns.RemoveAboveValue(500);
	towns.Sort(AIAbstractList.SORT_BY_VALUE, false);
	//RoutePlanner.getRegionalStations();
	local center_tile = AIMap.GetTileIndex(AIMap.GetMapSizeX() / 2, AIMap.GetMapSizeY() / 2);
	foreach(town, townIndex in towns) {
		//TODO: Initalize Towns
		local this_town = Town();
		this_town.townId = town;
		local group = AIGroup.CreateGroup(AIVehicle.VT_ROAD);
		this_town.bus_group_id = group;
		town_table[town] <- this_town;
	}	
	
	
		local town = towns.Begin();
		local town2 = towns.Next();
		
		//Inputs: near town, search from tileId, in_direction_of_tile, platforms, is_terminus(True: Cities, False:regional)
		local station1 = ZooElite.BuildRailStationForTown(town, 0, center_tile, 3, true);
		local station2 = ZooElite.BuildRailStationForTown(town2, 0, center_tile, 3, true);
		
		//Connect the two stations using rails...actually works more or less...
		ZooElite.ConnectStations(station1, station2);
		ZooElite.ConnectStations(station2, station1);
		
		//First build a center station, then additional ones...more efficent
		ZooElite.BuildMaxBusStationsInTown(town, 1);
		ZooElite.BuildMaxBusStationsInTown(town, 0);
		//Add Depot
		ZooElite.BuildDepotForTown(town);
		//Add Buses
		ZooElite.AdjustBusesInTown(town);
		//Give the buses some routing (This will be done automatically in the above funtion too)
		//ZooElite.UpdateBusRoutesForTown(town);
		
		
			//First build a center station, then additional ones...more efficent
		ZooElite.BuildMaxBusStationsInTown(town2, 1);
		ZooElite.BuildMaxBusStationsInTown(town2, 0);
		ZooElite.BuildDepotForTown(town2);
		ZooElite.AdjustBusesInTown(town2);
		//ZooElite.UpdateBusRoutesForTown(town2);
		
		ClearSigns();
		
	while(true) {
		
		if(AICompany.GetBankBalance(AICompany.COMPANY_SELF) > 50000) {
			//this.CityPairing();
			if(AICompany.GetLoanAmount() > 50000)
				AICompany.SetLoanAmount(AICompany.GetLoanAmount() * 2 / 3);
		}
		//LogManager.Log("I am a new AI with a ticker and I am at tick " + this.GetTick() + " with bank bal " + AICompany.GetBankBalance(AICompany.COMPANY_SELF));
		this.Sleep(1000);
		
		
	}
}