require("log_manager.nut");
require("constants.nut");
require("helper.nut");
require("obects/town.nut");
require("obects/station.nut");
require("RouteChooser.nut");

class Looper {
};

function Looper::Loop() {

	local BUS_UPDATE = 2;
	local BUILD_ROUTE = 1;
	local MANAGE_FUNDS = 1;
	
	//first divide map into small regions
	local towns = AITownList();
	RoutePlanner.getBaseRegions(towns);
	
	//the object that will spit out routes:
	local route_chooser = RouteChooser(base_regions);
	local i = 0;
	//we have a counter to decide how often to do tasks
	local counter = 0;
	local stored_route = null;
	while(true) {
		LogManager.Log("Main Loop",4);
		
		counter++;
		
		if(counter % MANAGE_FUNDS == 0) {
			local balance = AICompany.GetBankBalance(AICompany.ResolveCompanyID(AICompany.COMPANY_SELF));
			while(balance > 80000) {
				AICompany.SetLoanAmount(AICompany.GetLoanAmount() - AICompany.GetLoanInterval());
				balance = AICompany.GetBankBalance(AICompany.ResolveCompanyID(AICompany.COMPANY_SELF));
			}
			while(balance < 50000) {
				AICompany.SetLoanAmount(AICompany.GetLoanAmount() + AICompany.GetLoanInterval());
				balance = AICompany.GetBankBalance(AICompany.ResolveCompanyID(AICompany.COMPANY_SELF));
			}
		}
				
		if(counter % BUS_UPDATE == 0) {
			foreach(town in added_towns) {
				//ZooElite.AdjustBusesInTown(town);
			}
		}
		
		if(counter % BUILD_ROUTE == 0) {
			local route;
			
			if(stored_route == null) {
				route = route_chooser.getNextRoute();
			}
			else {
				route = stored_route;
				stored_route == null;
			}
			
			//we shouldn't build if we're too poor
			if(false) {//AICompany.GetBankBalance(AICompany.COMPANY_SELF)) {
				/*LogManager.Log("need to wait for more money", 4);
				this.Sleep(500);
				stored_route = route;
				continue;*/
			}
			
			//go ahead and build
			else {
				if(route == null) {
					LogManager.Log("Wow! Endgame.", 4);
					return 0;
				}
				else {
				LogManager.Log("About to start actual route construction", 4);
						if(base_regions[route[0]][3] == 0) {
							base_regions[route[0]][2] = ZooElite.BuildBaseStation(base_regions[route[0]][1], base_regions[route[0]][0], 0);
							base_regions[route[0]][3] = 1;
						}
						
						if(base_regions[route[1]][3] == 0) {
							base_regions[route[1]][2] = ZooElite.BuildBaseStation(base_regions[route[1]][1], base_regions[route[1]][0], 0);
							base_regions[route[1]][3] = 1;
						}
						
						local new_route = false;
						
						if(base_regions[route[0]][2] != false && base_regions[route[1]][2] != false) {
							local balance = AICompany.GetBankBalance(AICompany.ResolveCompanyID(AICompany.COMPANY_SELF));
							LogManager.Log("Before tracking, balance is: " + balance, 4);
							while(balance < 50000) {
								LogManager.Log("Cash Low", 4);
								if(AICompany.GetLoanAmount() + AICompany.GetLoanInterval() <= AICompany.GetMaxLoanAmount()) {
									AICompany.SetLoanAmount(AICompany.GetLoanAmount() + AICompany.GetLoanInterval());
									//loaned++;
								}
								else {
									ZooElite.Sleep(500);
									LogManager.Log("Wait for cash to build track", 4);
								}
								balance = AICompany.GetBankBalance(AICompany.ResolveCompanyID(AICompany.COMPANY_SELF));
							}
						
							new_route = ZooElite.ConnectStations(base_regions[route[0]][2], base_regions[route[1]][2], 0, 0);
						}
						else {   //one of the base stations failed so we aren't going to build the route
							route_chooser.unGetRoute();
							LogManager.Log("Backtracked due to bus failure", 4);
							continue;
						}
						
						if(base_regions[route[0]][4] == 0) {
							ZooElite.ConnectBaseRegion(base_regions[route[0]]);
							base_regions[route[0]][4] = 1;
						}
						if(base_regions[route[1]][4] == 0) {
							ZooElite.ConnectBaseRegion(base_regions[route[1]]);
							base_regions[route[1]][4] = 1;
						}
						
						if(new_route) {
							local balance = AICompany.GetBankBalance(AICompany.ResolveCompanyID(AICompany.COMPANY_SELF));
							while(balance < 70000) {
								LogManager.Log("Cash Low for train", 4);
								if(AICompany.GetLoanAmount() + AICompany.GetLoanInterval() <= AICompany.GetMaxLoanAmount()) {
									AICompany.SetLoanAmount(AICompany.GetLoanAmount() + AICompany.GetLoanInterval());
									//loaned++;
								}
								else {
									ZooElite.Sleep(500);
									LogManager.Log("Wait for cash to build new train", 4);
								}
								balance = AICompany.GetBankBalance(AICompany.ResolveCompanyID(AICompany.COMPANY_SELF));
							}
							new_route.balanceRailService();
						}
		
					}
			}
		//END new route building
		}
				
	}
}