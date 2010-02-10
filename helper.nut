/*******************************Written by: PAXLINK********************************/
function GetTileRelative(relative_to_tile, delta_x, delta_y)
{
	local tile_x = AIMap.GetTileX(relative_to_tile);
	local tile_y = AIMap.GetTileY(relative_to_tile);

	local new_x = tile_x + delta_x;
	local new_y = tile_y + delta_y;

	return AIMap.GetTileIndex(new_x, new_y);
}

function GetNeighbours4(tile_id)
{
	local list = AITileList();

	if(!AIMap.IsValidTile(tile_id))
		return list;

	local tile_x = AIMap.GetTileX(tile_id);
	local tile_y = AIMap.GetTileY(tile_id);

	list.AddTile(GetTileRelative(tile_id, -1, 0));
	list.AddTile(GetTileRelative(tile_id, 0, -1));
	list.AddTile(GetTileRelative(tile_id, 1, 0));
	list.AddTile(GetTileRelative(tile_id, 0, 1));

	return list;
}

function GetNeighbours8(tile_id)
{
	local list = AITileList();

	if(!AIMap.IsValidTile(tile_id))
		return list;

	local tile_x = AIMap.GetTileX(tile_id);
	local tile_y = AIMap.GetTileY(tile_id);

	list.AddTile(GetTileRelative(tile_id, -1, 0));
	list.AddTile(GetTileRelative(tile_id, 0, -1));
	list.AddTile(GetTileRelative(tile_id, 1, 0));
	list.AddTile(GetTileRelative(tile_id, 0, 1));

	list.AddTile(GetTileRelative(tile_id, -1, -1));
	list.AddTile(GetTileRelative(tile_id, 1, -1));
	list.AddTile(GetTileRelative(tile_id, 1, 1));
	list.AddTile(GetTileRelative(tile_id, -1, 1));

	return list;
}


/*********************************Written by: Ronjde********************************/
/**
 * 
 * Find the cargo ID for passengers.
 * Otto: newgrf can have tourist (TOUR) which qualify as passengers but townfolk won't enter the touristbus...
 * hence this rewrite; you can check for PASS as string, but this is discouraged on the wiki
 */
function GetPassengerCargoID() {
	local list = AICargoList();
	local candidate = -1;
	for (local i = list.Begin(); list.HasNext(); i = list.Next()) {
		if (AICargo.HasCargoClass(i, AICargo.CC_PASSENGERS))
		candidate = i;
	}
	if(candidate != -1)
		return candidate;
	
	throw "no passenger cargo in this game!";
}

/**
 * Return the sum of a vehicle's profit over the last year and the current year.
 */
function GetVehicleProfit(vehicleID) {
	return AIVehicle.GetProfitThisYear(vehicleID) + AIVehicle.GetProfitLastYear(vehicleID);
}

/**
 *
 * Find the best (largest) engine for a given cargo ID.
 */
function GetBestEngine(cargoID) {
	if (!(cargoID in bestEngines)) {
		local engines = AIEngineList(AIVehicle.VT_ROAD);
		engines.Valuate(AIEngine.CanRefitCargo, cargoID)
		engines.KeepValue(1);
		engines.Valuate(AIEngine.GetRoadType);
		engines.KeepValue(AIRoad.ROADTYPE_ROAD);
		engines.Valuate(AIEngine.GetCapacity);
		engines.KeepTop(1);
		bestEngines[cargoID] <- engines.Begin();
	}
	
	return bestEngines[cargoID];
}

/**
 * If this is the month before a bankrupcy check (March, June, September, December),
 * keep enough cash around to pay for station maintenance.
 * In other months, feel free to spend what we have.
 *
 * This function actually was modified by Charlie to just return how much money we NEED to keep around
 */
function GetMinimumSafeMoney() {
	local safe = SAFETY_MARGIN;
	safe += (AIStationList(AIStation.STATION_ANY).Count() * MONTHLY_STATION_MAINTENANCE);
	// this is of course just a guesstimate, as the amount of vehicles constantly fluctuates
	safe += (AIVehicleList().Count() * MONTHLY_STATION_MAINTENANCE);	// TODO get cost from a vehicle(engine)
	return safe;
}

/**
 * Keep enough money around for several months of station maintenance and running costs,
 * to prevent bankrupcy.
 */
 //THIS IS FROM CHOO CHOO, IT'S POSTED HERE FOR COMPARISON
function GetMinimumSafeMoney() {
	local vehicles = AIVehicleList();
	vehicles.Valuate(AIVehicle.GetRunningCost);
	local runningCosts = Sum(vehicles) / 12;
	local maintenance = AIStationList(AIStation.STATION_ANY).Count() * MONTHLY_STATION_MAINTENANCE;
	return 3*(runningCosts + maintenance);
}

/*************************************END RONJDE********************************************/

/************************************trAIns and TransAI*************************************/
/**
 * ClearSigns is AISign cleaner
 * Clear all sign that I have been built while servicing.
 */
function ClearSigns()
{
    AILog.Info("Clearing signs ...");
    local s = AISignList();
  	while (s.Count()) {  		
    	AISign.RemoveSign(s.Begin());
    	s.RemoveTop(1);    	
  	}
}

/**
 * Convert an AIList to a human-readable string.
 * @param list The AIList to convert.
 * @return A string containing all item => value pairs from the list.
 * @author Yexo (Admiral)
 */

function AIListToString(list)
{
	if (typeof(list) != "instance") throw("AIListToString(): argument has to be an instance of AIAbstractList.");
	local ret = "[";
	if (!list.IsEmpty()) {
		local a = list.Begin();
		ret += a + "=>" + list.GetValue(a);
		if (list.HasNext()) {
			for (local i = list.Next(); list.HasNext(); i = list.Next()) {
				ret += ", " + i + "=>" + list.GetValue(i);
			}
		}
	}
	ret += "]";
	return ret;
}

/**
 * Try to use sqrt function
 * @param num number to get square from
 * @return squared root number
 * @author zutty (PathZilla)
 */
function SquareRoot(num)
{
	if (num == 0) return 0;
	local n = (num / 2) + 1;
	local n1 = (n + (num / n)) / 2;
	while (n1 < n) {
		n = n1;
		n1 = (n + (num / n)) / 2;
	}
	return n;
}

/**
 * Wrapper for build sign.
 * Its used with Game.Settings
 * @param tile TileID where to build sign
 * @param txt Text message to be displayed
 * @return a valid signID if its allowed by game setting
*/
function Sign(tile, txt)
{
    if (ZooElite.GetSetting("debug_signs")) {
    	if (typeof txt != "string") txt = txt.tostring();
    	return AISign.BuildSign(tile, txt);
    }
}

/**
 * Unsign is to easy check wether we have build sign before
 * @param id Suspected signID
 */
function UnSign(id)
{
	if (id != null) if (AISign.IsValidSign(id)) AISign.RemoveSign(id); 
}	


/**
* Flatten an area of land, taken from trAIns AI
* @param start_tile tile to start with
* @param end_tile tile to end with
*/

function LevelLand(start_tile , end_tile){
	if(AIMap.GetTileX(start_tile) <= AIMap.GetTileX(end_tile)){
		end_tile += AIMap.GetTileIndex(1 , 0);
	}else{
		start_tile += AIMap.GetTileIndex(1 , 0);
	}

	if(AIMap.GetTileY(start_tile) <= AIMap.GetTileY(end_tile)){
		end_tile += AIMap.GetTileIndex(0 , 1);
	}else{
		start_tile += AIMap.GetTileIndex(0 , 1);
	}

	if(AITile.GetCornerHeight(start_tile , AITile.CORNER_N) == 0){
		return false;
	}

	/* Check if is already flat. */
	{
		local ex = AIMap.GetTileX(end_tile);
		local ey = AIMap.GetTileY(end_tile);
		local sx = AIMap.GetTileX(start_tile);
		local sy = AIMap.GetTileY(start_tile);
		local initial_tile , area_w , area_h;
		local exit = false;
		local start_tile_height = AITile.GetCornerHeight(start_tile , AITile.CORNER_N);

		if(sx > ex){
			local aux = sx;
			sx = ex;
			ex = aux;
		}

		if(sy > ey){
			local aux = sy;
			sy = ey;
			ey = aux;
		}


		initial_tile = AIMap.GetTileIndex(sx , sy);
		area_w = ex - sx + 1;
		area_h = ey - sy + 1;

		for(local w = 0 ; w < area_w && !exit ; w++){
			for(local h = 0 ; h < area_h && !exit ; h++){
				local tile = initial_tile + AIMap.GetTileIndex(w , h);
				if(start_tile_height != AITile.GetCornerHeight(tile , AITile.CORNER_N)) exit = true;
			}
		}

		if(!exit) return true;
	}

	return AITile.LevelTiles(start_tile , end_tile);
}


/***********************CHOO CHOO****************************/
/**
 * Add a rectangular area to an AITileList containing tiles that are within /radius/
 * tiles from the center tile, taking the edges of the map into account.
 */  
function SafeAddRectangle(list, tile, radius) {
	local x1 = max(0, AIMap.GetTileX(tile) - radius);
	local y1 = max(0, AIMap.GetTileY(tile) - radius);
	
	local x2 = min(AIMap.GetMapSizeX() - 2, AIMap.GetTileX(tile) + radius);
	local y2 = min(AIMap.GetMapSizeY() - 2, AIMap.GetTileY(tile) + radius);
	
	list.AddRectangle(AIMap.GetTileIndex(x1, y1),AIMap.GetTileIndex(x2, y2)); 
}

/**
 * Return the closest integer equal to or greater than x.
 */
function Ceiling(x) {
	if (x.tointeger().tofloat() == x) return x.tointeger();
	return x.tointeger() + 1;
}

function Floor(x) {
	if (x.tointeger().tofloat() == x) return x.tointeger();
		return x.tointeger();
}