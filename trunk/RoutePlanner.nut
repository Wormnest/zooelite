//TODO: measure by approx route distance/cost rather than actual distance (quick algorithms for finding obstructions?)
//TODO: buildability measure of tile
//NOTE: check out test mode

class RoutePlanner	{
};

//finds regions first by clustering and then by other adjustment functions
function RoutePlanner::getRegionalStations() {

	local towns = AITownList();
	
	//this gets the original raw region locations
	local regions = RoutePlanner.aggCluster(towns);
	
	//now we get the list of regional routes - each route is defined by a pair of regions
	local regionalRoutes = RoutePlanner.getRegionalRoutes(regions);
	
	
	
	//mark the regions so we know whats going on
	for(local i = 0; i < regions[0].len(); i += 1) {
		Sign(regions[0][i], "Region " + i);
	}
	
	//now we balance the region centers towards other nearby regions
	regions = RoutePlanner.regionBalance(regions, regionalRoutes);
	//now we possibly move regions to towns
	regions = RoutePlanner.adjustRegions(regions);
	
	for(local i = 0; i < regions[0].len(); i += 1) {
		Sign(regions[0][i], "REBAL " + i);
	}
	
	//now mark routes just to get a sense of stuff
		for(local j = 0; j < regionalRoutes.len(); j += 1) {
		local route = regionalRoutes[j];
		local Yinc =  (AIMap.GetTileY(regions[0][route[0]]) - AIMap.GetTileY(regions[0][route[1]]))/10;
		//LogManager.Log("Yinc: " + Yinc,4);
		local Xinc =  (AIMap.GetTileX(regions[0][route[0]]) - AIMap.GetTileX(regions[0][route[1]]))/10;
		local curY = AIMap.GetTileY(regions[0][route[1]]);
		local curX = AIMap.GetTileX(regions[0][route[1]]);
		for(local i = 0; i < 11; i += 1) {
			Sign(AIMap.GetTileIndex(curX, curY), "R" + j);
			curY += Yinc;
			curX += Xinc;
		}
	}
	
	
	return regions;
	
}

//finds regions using a v means clustering algorithm
//note: no longer used
//TODO: make useful by moving towns to regions that are easiest to get to rather than by just doing distance
function RoutePlanner::vMeansCluster(towns) {
	local regionCount = towns.Count()/5;
	LogManager.Log("Creating: " + regionCount + " regions" , 4);
	
	local regions = RoutePlanner.aggCluster(towns);
	local regionCenters = regions[0];
	local bucketList;
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
	
		bucketList = array(regionCount, null);
	
		//initialize buckets
		for(local i = 0; i < regionCount; i += 1) {
			bucketList[i] = AIList();
		}
	
		//assign each town to closest region
		foreach(town, townIndex in towns) {
			local currentAssignment = 0;
			local minDistance = AITown.GetDistanceSquareToTile(town, regionCenters[currentAssignment]);
		
			//check each region to see if we should assign to it
			for(local i = 1; i < regionCount; i += 1) {
				local newDistance = AITown.GetDistanceSquareToTile(town, regionCenters[i]);
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
			regionCenters[i] = AIMap.GetTileIndex(xAvg, yAvg);
		}
	}
	
	regions = [regionCenters, bucketList];
	return regions;
}


//finds regions using an agglomerated clustering algorithm
//TODO: speed up algorithm for larger town counts - need to aggregate multiple regions on each pass
function RoutePlanner::aggCluster(towns) {

	//will hold region's locations (centers and towns in each region
	local regions;
	
	//will hold centers of regions
	local regionCenters = array(towns.Count());
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
		regionCenters[i] = AITown.GetLocation(town);
		i += 1;
	}

	//run through agglomeration a certain number of times
	for(local j = 0; j < finalNumRegions; j += 1) {

		//firstwe figure out which 2 regions to combine
		local aggRegion1 = 0;
		local aggRegion2 = 1;
		local minDistance = AIMap.DistanceSquare(regionCenters[aggRegion1], regionCenters[aggRegion2]);
		for(local r = 0; r < regionCenters.len(); r += 1)	{
			for(local c = 0; c < regionCenters.len(); c += 1) {
				
				if(r != c) {
					local newDistance = AIMap.DistanceSquare(regionCenters[r], regionCenters[c]);
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
		
		//add regions to bucketList with towns from Region1 and Region2 going into the same bucket
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
		
		//now recalculate the region centers
		regionCenters = array(bucketList.len(), null);
		
		for(local i = 0; i < regionCenters.len(); i += 1) {
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
		
			//LogManager.Log("region " + i + "now at center: " + xAvg + ", " + yAvg, 4);
			//set region to average x and y value:
			regionCenters[i] = AIMap.GetTileIndex(xAvg, yAvg);
		}
	}
	
	//no return buckets and centers
	regions = [regionCenters, bucketList];
	return regions;
}

//draws regions closer to nearby regions
function RoutePlanner::regionBalance(regions, regionalRoutes) {

	
	local newRegions = [array(regions[0].len(), null), regions[1]];
	for(local i = 0; i < regions[0].len(); i += 1) {
		local region = regions[0][i];
		local connectedRegions = [];
		
		foreach(route in regionalRoutes) {
			if(route[0] == i) {
				connectedRegions.append(route[1]);
			}
			if(route[1] == i) {
				connectedRegions.append(route[0]);
			}
		}
		LogManager.Log("region " + i + " has " + connectedRegions.len() + " connected regions", 4);
		local xSum = 0;
		local ySum = 0;
		
		xSum += 5*AIMap.GetTileX(region)/6;
		ySum += 5*AIMap.GetTileY(region)/6;
		foreach(connectedRegion in connectedRegions) {
			xSum += AIMap.GetTileX(regions[0][connectedRegion])/(6*connectedRegions.len());
			ySum += AIMap.GetTileY(regions[0][connectedRegion])/(6*connectedRegions.len());
		}
		newRegions[0][i] = AIMap.GetTileIndex(xSum, ySum);
		LogManager.Log("region " + i + " is now at center: " + xSum + ", " + ySum, 4);
	}
	
	return newRegions;
}

//this will move a region to a relatively near by city if that is more efficient
function RoutePlanner::adjustRegions(regions) {

	local newRegions = [array(regions[0].len(), null), regions[1]];
	local regionCenters = regions[0];
	for(local i = 0; i < regionCenters.len(); i += 1) {
		local region = regionCenters[i];
		newRegions[0][i] = region;
		//get the average diameter of the region
		local diameter = 0;
		local townCount = 0;
		foreach(town, townid in regions[1][i]) {
			diameter += AITown.GetDistanceSquareToTile(town, region);
			townCount += 1;
		}
		
		local threshold = diameter / (townCount*5);
		
		//now check towns. If one is very close to the region move the region center to the town
		foreach(town, townid in regions[1][i]) {
			if(AITown.GetDistanceSquareToTile(town, region) < threshold) {
				newRegions[0][i] = AITown.GetLocation(town);
				threshold = AITown.GetDistanceSquareToTile(town, region);
			}
		}
	}
	
	return newRegions;
}

function RoutePlanner::getRegionalRoutes(regions) {
	//for each region pair - measure approx. cost (distance?, test mode? water check and shit?)
	//run kruskal's or similar algoritm
	
	//list of all possible regional routes
	local possibleRoutes = array(regions[0].len()*(regions[0].len()-1)/2, null);
	//LogManager.Log("posroutes len: " + possibleRoutes.len(), 4);
	
	for(local i = 0; i < possibleRoutes.len(); i += 1) {
		possibleRoutes[i] = array(3, null);
	}
	
						
	local c = 0;
	for(local i = 0; i < regions[0].len(); i += 1) {
		for(local j = i + 1; j < regions[0].len(); j += 1) {
			possibleRoutes[c][0] = i;
			possibleRoutes[c][1] = j;
			possibleRoutes[c][2] = AIMap.DistanceSquare(regions[0][i], regions[0][j]);
			c += 1;
		}
	}
	
	//sort to have shortest routes
	possibleRoutes.sort(route_compare);
	for(local i = 0; i < possibleRoutes.len(); i += 1) {
		LogManager.Log("possible route lenth: " + possibleRoutes[i][2] + " from " + possibleRoutes[i][0] + " to " +possibleRoutes[i][1], 4);
	}
	
	//now run algorithm.
	local regionalRoutes = [];
	local clusters = array(regions[0].len(), null);
	for(local i = 0; i < clusters.len(); i += 1) {
		clusters[i] = i;
	}
	for(local i = 0; i < possibleRoutes.len(); i += 1) {
		if(clusters[possibleRoutes[i][0]] != clusters[possibleRoutes[i][1]]) {
			regionalRoutes.append(possibleRoutes[i]);
			local newClusterNum = clusters[possibleRoutes[i][1]];
			local oldClusterNum = clusters[possibleRoutes[i][0]];
			for(local j = 0; j < clusters.len(); j += 1) {
				if(clusters[j] == oldClusterNum) {
					clusters[j] = newClusterNum;
				}
			}
		}
		/*foreach(cluster in clusters) {
			LogManager.Log("cluster: " + cluster, 4);
		}
			LogManager.Log("YYYYYYYYYYYYYYYYYYYYY", 4);*/
	}
	
	foreach(route in regionalRoutes) {
		LogManager.Log("route from: " + route[0] + " to " + route[1] + " with length: " + route[2], 4);
	}
	
	/*for(local j = 0; j < regionalRoutes.len(); j += 1) {
		local route = regionalRoutes[j];
		local Yinc =  (AIMap.GetTileY(regions[0][route[0]]) - AIMap.GetTileY(regions[0][route[1]]))/10;
		//LogManager.Log("Yinc: " + Yinc,4);
		local Xinc =  (AIMap.GetTileX(regions[0][route[0]]) - AIMap.GetTileX(regions[0][route[1]]))/10;
		local curY = AIMap.GetTileY(regions[0][route[1]]);
		local curX = AIMap.GetTileX(regions[0][route[1]]);
		for(local i = 0; i < 11; i += 1) {
			Sign(AIMap.GetTileIndex(curX, curY), "R" + j);
			curY += Yinc;
			curX += Xinc;
		}
	}*/
	
	return regionalRoutes;
}

function route_compare(a,b)
{
if(a[2]>b[2]) return 1;
else if(a[2]<b[2]) return -1;
return 0;
}


