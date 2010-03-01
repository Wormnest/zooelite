//Constants

const SAFETY_MARGIN = 2500;	// extra money to keep around for bankrupcy checks
const STATION_REUSE_DISTANCE_FROM_TOWN = 30; //Maximum distance from any given city a station must be to be reused
const RAIL_STATION_PLATFORM_LENGTH = 6; //Shouldn't it just be constant? Of course.
const RAILSTATION_IN_DIRECTION_OF_FLEX = 6; //When finding rail placements, this is how much deviation it will allow the station to be NOT in the direction of the dest tile from the seed_tile.
const RAIL_STATION_SEARCH_DISTANCE_WEIGHT = 4; //Larger give more weight to distance from search tile
const RAIL_STATION_SEARCH_CARGO_WEIGHT = 2; //Larger gives more weight to the station being close to passengers
const BUS_RADIUS_MULTIPLIER = 1.4; //Multiplier * sqrrt of houses in town gives search radius. Raise to allow more deviation from a square configuration, but longer search times
const CITY_BUS_CAPACITY_THRESHOLD = 0.6; //If the transported cargo falls under this percent of production, more busses will be created
const CITY_BUS_CAPACITY_TARGET = 0.8; //Should be higher than threshold...target pct to rebalance to when checking busses