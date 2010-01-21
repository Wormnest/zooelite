class RoutePlanner	{
};

function RoutePlanner::getRegionalStations() {

	//figure out how many regions we want
	local towns = AITownList();
	local regionCount = towns.Count()/4;
	LogManager.Log("Creating: " + regionCount + " regions" , 4);
	
	local regions = array(regionCount, null);
	
	//assign regions to centers of 6 first towns
	//locations will then change by the k-means algorithm
	local tempRegion = AITown.GetLocation(towns.Begin());
	for(local i = 0; i < regionCount; i += 1) {
		regions[i] = tempRegion;
		tempRegion = AITown.GetLocation(towns.Next());
	}

	//run through the algorithm a specified number of times to refine regions
	for(local i = 0; i < 1; i+= 20) {
		regions = RoutePlanner.updateRegions(regions);
	}
	
	//mark the regions so we know whats going on
	for(local i = 0; i < regionCount; i += 1) {
		Sign(regions[i], "Region " + i);
	}
	return regions;
	
}

function RoutePlanner::updateRegions(regions) {

	local numRegions = regions.len();
	LogManager.Log("numRegions is: " + numRegions, 4);
	local towns = AITownList();
	
	local bucketList = array(numRegions, null);
	
	//initialize buckets
	for(local i = 0; i < numRegions; i += 1) {
		bucketList[i] = AIList();
	}
	
	//assign each town to closest region
	foreach(town, townIndex in towns) {
		local currentAssignment = 0;
		local minDistance = AITown.GetDistanceSquareToTile(town, regions[currentAssignment]);
		
		//check each region to see if we should assign to it
		for(local i = 1; i < numRegions; i += 1) {
			local newDistance = AITown.GetDistanceSquareToTile(town, regions[i]);
			//if there is a closer region update the assignment
			if(newDistance < minDistance) {
				minDistance = newDistance;
				currentAssignment = i;
				
			}
		}
		
		//actually place town in correct bucket
		//TODO: figure out this sloppy key/value shit
		bucketList[currentAssignment].AddItem(town, town);
		
		LogManager.Log("bucketList " + currentAssignment + "was just added to with town  " + town,4);
		//LogManager.Log("bucketList last element: " + bucketList[0].tostring(), 4);
	}
	
	//now update centers of regions
	for(local i = 0; i < numRegions; i += 1) {
		local xSum = 0;
		local ySum = 0;
		local numTowns = 0;

		//sum x and y coordinates of all towns in region
		foreach(town in bucketList[i]) {
			xSum += AIMap.GetTileX(AITown.GetLocation(town));
			ySum += AIMap.GetTileY(AITown.GetLocation(town));
			numTowns += 1;
		}
		
		//averages
		local xAvg = xSum / numTowns;
		local yAvg = ySum / numTowns;
		LogManager.Log("region " + i + " has " + numTowns + " towns", 4);
		LogManager.Log("region " + i + " has " + xSum + " xSum", 4);
		LogManager.Log("region " + i + " has " + ySum + " ySum", 4);
		
		LogManager.Log("region " + i + "now at center: " + xAvg + ", " + yAvg, 4);
		//set region to average x and y value:
		regions[i] = AIMap.GetTileIndex(xAvg, yAvg);
	}
	
	return regions;
}
