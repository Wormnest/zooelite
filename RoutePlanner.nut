class RoutePlanner	{
};

function RoutePlanner::getRegionalStations() {

	local towns = AITownList();
	local regions = RoutePlanner.aggCluster(towns);
	
	//mark the regions so we know whats going on
	for(local i = 0; i < regions.len(); i += 1) {
		Sign(regions[i], "Region " + i);
	}
	
	regions = RoutePlanner.centerBalance(regions);
	
	for(local i = 0; i < regions.len(); i += 1) {
		Sign(regions[i], "REBAL " + i);
	}
	return regions;
	
}

function RoutePlanner::vMeansCluster(towns) {
	local regionCount = towns.Count()/5;
	LogManager.Log("Creating: " + regionCount + " regions" , 4);
	
	local regions = RoutePlanner.aggCluster(towns);
	/*local regions = array(regionCount, null);
	
	//assign regions to centers of 6 first towns
	//locations will then change by the k-means algorithm
	local tempRegion = AITown.GetLocation(towns.Begin());
	for(local i = 0; i < regionCount; i += 1) {
		regions[i] = tempRegion;
		tempRegion = AITown.GetLocation(towns.Next());
	} */

	//run through the algorithm a specified number of times to refine regions
	for(local i = 0; i < 1; i+= 20) {

		local towns = AITownList();
	
		local bucketList = array(regionCount, null);
	
		//initialize buckets
		for(local i = 0; i < regionCount; i += 1) {
			bucketList[i] = AIList();
		}
	
		//assign each town to closest region
		foreach(town, townIndex in towns) {
			local currentAssignment = 0;
			local minDistance = AITown.GetDistanceSquareToTile(town, regions[currentAssignment]);
		
			//check each region to see if we should assign to it
			for(local i = 1; i < regionCount; i += 1) {
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
		for(local i = 0; i < regionCount; i += 1) {
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
	}
	
	return regions;
}




function RoutePlanner::aggCluster(towns) {

	//will hold region's locations
	local regions;
	//will hold actual towns in region
	LogManager.Log("the number of towns is: " + towns.Count(), 4);
	local finalNumRegions = towns.Count()*4/5;
	//LogManager.Log("the number of recursions will be: " + finalNumRegions, 4);
	local bucketList = array(towns.Count(), null);
	
	//initialize buckets
	for(local i = 0; i < towns.Count(); i += 1) {
		bucketList[i] = AIList();
	}

	//initially, each town is a region
	local i = 0; //regionID
	foreach(town, townIndex in towns) {
		bucketList[i].AddItem(town, town);
		i += 1;
	}

	//run through agglomeration a certain number of times
	for(local j = 0; j < finalNumRegions; j += 1) {

		//array to hold locations of regions
		regions = array(bucketList.len(), null);
		
		//first calculate locations of regions:
		for(local i = 0; i < regions.len(); i += 1) {
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
			//LogManager.Log("region " + i + " has " + numTowns + " towns", 4);
			//LogManager.Log("region " + i + " has " + xSum + " xSum", 4);
			//LogManager.Log("region " + i + " has " + ySum + " ySum", 4);
		
			LogManager.Log("region " + i + "now at center: " + xAvg + ", " + yAvg, 4);
			//set region to average x and y value:
			regions[i] = AIMap.GetTileIndex(xAvg, yAvg);
		}

		//now we figure out which 2 regions to combine
		local aggRegion1 = 0;
		local aggRegion2 = 1;
		local minDistance = AIMap.DistanceSquare(regions[aggRegion1], regions[aggRegion2]);
		for(local r = 0; r < regions.len(); r += 1)	{
			for(local c = 0; c < regions.len(); c += 1) {
				
				if(r != c) {
					local newDistance = AIMap.DistanceSquare(regions[r], regions[c]);
					if(newDistance < minDistance) {
						minDistance = newDistance;
						aggRegion1 = r;
						aggRegion2 = c;
					}	
				}
			}	
		}
	
		LogManager.Log("the regions to aggregate are: " + aggRegion1 + " , " + aggRegion2, 4);
	
		//now we need to actually aggregate these regions:
		//we will copy everything into a new bucketlist with 1 less element
		local newBucketList = array(bucketList.len() - 1, null);
		//initialize buckets
		for(local i = 0; i < newBucketList.len(); i += 1) {
			newBucketList[i] = AIList();
		}
		
		
		local j = 1;
		for(local i = 0; i < bucketList.len(); i += 1) {
			if(i == aggRegion1 || i == aggRegion2) {
				foreach(town in bucketList[i]) {
					newBucketList[0].AddItem(town, town);
				}
			}
			else {
				foreach(town in bucketList[i]) {
					newBucketList[j].AddItem(town, town);
				}
				j += 1;
			}
		}
		
		bucketList = newBucketList;
	}
	
	return regions;
}


function RoutePlanner::centerBalance(regions) {

	local numOtherRegions = regions.len() - 1;
	local newRegions = array(regions.len(), null);
	for(local i = 0; i < regions.len(); i += 1) {
		local region = regions[i];
		LogManager.Log("region " + i + " has tile id: " + regions[i], 4);
		local xSum = 0;
		local ySum = 0;
		
		//balance region towards the center
		for(local j = 0; j < regions.len(); j += 1) {
			local otherRegion = regions[j];
			if(otherRegion == region) {
				xSum += 4*AIMap.GetTileX(otherRegion)/5;
				ySum += 4*AIMap.GetTileY(otherRegion)/5;
			}
			else {
				xSum += AIMap.GetTileX(otherRegion)/(5*numOtherRegions);
				ySum += AIMap.GetTileY(otherRegion)/(5*numOtherRegions);
			}
		}
		newRegions[i] = AIMap.GetTileIndex(xSum, ySum);
		LogManager.Log("region " + i + " is now at center: " + xSum + ", " + ySum, 4);
	}
	
	return newRegions;
}

