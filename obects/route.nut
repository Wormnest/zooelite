class Route {

	rail_station_id1 = null;
	rail_station_id2 = null;
	to2_depot_tile = null;
	to1_depot_tile = null;

	constructor(r_id1, r_id2, d_t1, d_t2) {
		this.rail_station_id1 = r_id1;
		this.rail_station_id2 = r_id2;	
		this.to2_depot_tile = d_t1;
		this.to1_depot_tile = d_t2;
	}
} 
