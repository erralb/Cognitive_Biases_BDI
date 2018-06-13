/**
* Name: CognitiveBiasesBDI
* Author: Pierre Blarre
* Description: Introducing cognitive biases implementation into BDI agents
* 
* "CB" in comments = Cognitive Biases
* 
* ============
* Species description
* ============
* People : General specie that includes residents, firefighters and police
* 
* ============
* 
* Firefighters : 
* General desire : Patrol = initial intention
* Default Plan : Wanders around (patrol)
* When : Perceives a fire = send alert +  new belief (there is a fire) + new desire (I want the fire out) - existing desire (patrol on hold) + new intention (put out the fire)
* Intention "Put the fire out" : plans in 2 steps : go to fire, put water on it
* 
* ============
* 
* Tags: Cognitive biases, simple_bdi, perception, rule, plan, predicate
*/

model CognitiveBiasesBDI


global 
{
	//Environment related

	int starting_hour <- 5; //heure de départ de la simulation
	int current_hour <- 0 update: (starting_hour + (cycle / 60)) mod 24; //heure actuelle
	int current_min <- 0 update: (cycle) mod 60; // minutes actuelles
	bool is_night <- true update: current_hour < 7 or current_hour > 20; //jour / nuit
	string current_time update: string(current_hour) + "h" + string(current_min); //temps actuel
	float wind <- 0.2; //force du vent
	float drought <- 0.3; //niveau de secheresse
	float hurting_distance <- 2.0 # m;
	float field_of_view <- 15.0 # m;
	int nb_residents <- 100;
	int nb_fireman <- 5;
	int nb_bunker <- 0;
	int nb_exit <- 0;
	int nb_fire_station <- 1;
	int nb_police_station <- 1;
	int nb_policeman <- 2;
	int nb_fire_starter <- 0;
	int nb_residents_w_answered_1st_call <- 0;
	int fire_size <- 1 update: length(plot where (each.burning = true));
	int fire_uncontrollable <- 600;
	bool result_saved <- false;
	bool do_pause <- false;
	string simulation_name <- "Simulation 1";

	// Intentions
	string run_away <- "Fuire";
	string defend <- "Défendre";
	string protect <- "Protéger";
	string ask_for_help <- "Venez m'aider";

	// Croyances
	string no_danger <- "Pas de danger immédiat";
	string potential_danger <- "Danger potentiel";
	string immediate_danger <- "Danger immédiat";

	// Init variables especes
	int nb_isolated_and_vulnerable <- 5;
	int nb_unaware_reactors <- 5;
	int nb_threat_avoiders <- 30;
	int nb_threat_monitors <- 30;
	int nb_can_do_defenders <- 10;
	int nb_considered_defenders <- 10;
	int nb_livelihood_defenders <- 10;

	// Bouton Application
	bool personalized_msg <- false;
	bool trained_population <- false;
	bool tactical_fireman <- false;
	float burned_distance <- 10.0 # m;
	file bounds_shapefile <- file("../includes/bounds.shp");
	file buildings_shapefile <- file("../includes/building.shp");
	file roads_shapefile <- file("../includes/road.shp");
	//	file waterway_shapefile <- file("../includes/waterway.shp");
	geometry shape <- envelope(envelope(buildings_shapefile) + envelope(roads_shapefile) + envelope(bounds_shapefile));
	graph the_graph;
	int ids <- 1;
	bool evacution_city_reported <- false;
	list<resident> every_resident <- nil update: isolated_and_vulnerable union unaware_reactors union threat_avoiders union threat_monitors union can_do_defenders union
	considered_defenders union livelihood_defenders;
	list<resident> every_resident_alive <- nil update: every_resident where each.alive;
	list<people> every_people_alive <- nil update: every_resident_alive + (fireman + policeman) where each.alive;
	graph road_network;
	graph road_network_practicable;
	int grid_size <- 150;
	
	
	
	//Simulation variables
	bool result_saved <- false;
	bool do_pause <- false;
	string simulation_name <- "Simulation 1";
	
	
	
	int displatTextSize <-4;
	init 
	{
		create fireArea number:20;
		create waterArea number:1;
		create helicopter number: nb_helicopters;
	}
	
	reflex stop when: length(fireArea) = 0 
	{
		do pause;
	}
}



//give the simple_bdi architecture to the firefighter helicopter agents
species helicopter skills: [moving] control: simple_bdi
{	
	
	//Here are the variables used by a helicopter. We define the predicates that will be used later.
	rgb color <- rnd_color(150);
	float waterValue;
	grille maCellule <- one_of(grille);
	predicate patrol_desire <- new_predicate("patrol");
	predicate water_predicate <- new_predicate("has water",true);
	predicate no_water_predicate <- new_predicate("has water", false) ;

	//Definition of the variables featured in the BDI architecture.
	float plan_persistence <- 1.0; 
	float intention_persistence <- 1.0;
	bool probabilistic_choice <- false;
	
	//Initialisation of the agent. At the begining, the agent just has the desire to patrol.
	init {
		waterValue <-2.0;
		location<-maCellule.location;
		do add_desire(patrol_desire );
	}
	
	//This perceive is used to update the beliefs concerning the intern variable of the agent (the amount of water it has).
	perceive target:self {
		if(waterValue>0){
			do add_belief(water_predicate);
			do remove_belief(no_water_predicate);
		}
		if(waterValue<=0){
			do add_belief(no_water_predicate);
			do remove_belief(water_predicate);
		}
	}
	
	//The helicopter perceive the fires at a certain distance. It just record the location of the fire it obsrves. When it sees a fire, it stops it's intention of patroling.
	perceive target:fireArea in: 15{
		focus fireLocation var:location strength:10.0;
		ask myself{
			do remove_intention(patrol_desire, true);
		}
	}
	
	//The rules are used to create a desire from a belief. We can specify the priority of the desire with a statement priority.
	rule belief: new_predicate("fireLocation") new_desire: get_predicate(get_belief_with_name("fireLocation"));
	rule belief: no_water_predicate new_desire: water_predicate strength: 10.0;
	
	//The plan to do when the intention is to patrol.
	plan patrolling intention:patrol_desire{
		do wander amplitude: 30 speed: 2.0;
	}
	 
	//The plan that is executed when the agent got the intention of extinguish a fire.
	plan stopFire intention: new_predicate("fireLocation") priority:5{
		point target_fire <- point(get_predicate(get_current_intention()).values["location_value"] );
		if(waterValue>0){
			if (self distance_to target_fire <= 1) {
				fireArea current_fire <- fireArea first_with (each.location = target_fire);
				if (current_fire != nil) {
					 waterValue <- waterValue - 1.0;
					 current_fire.size <-  current_fire.size - 1;
					 if ( current_fire.size <= 0) {
						ask  current_fire {do die;}
						do remove_belief(get_predicate(get_current_intention()));
						do remove_intention(get_predicate(get_current_intention()), true);
						do add_desire(patrol_desire,1.0);
					}
				} else {
					do remove_belief(get_predicate(get_current_intention()));
					do remove_intention(get_predicate(get_current_intention()), true);
					do add_desire(patrol_desire,1.0);
				}
			} else {
				do goto(target: target_fire);
			}
		} else {
			do add_subintention(get_predicate(get_current_intention()),water_predicate,true);
			do current_intention_on_hold();
		}
	}  
	
	//The plan to take water when the agent get the desire of water.
    plan gotoTakeWater intention: water_predicate priority:2 {
    	waterArea wa <- first(waterArea);
    	list<grille> voisins <-  (grille(location) neighbors_at (1)) + grille(location);
			path cheminSuivi <- self goto(target: wa);
    	if (self distance_to wa <= 1) {
    		waterValue <- waterValue + 2.0;
		}
    }

	aspect base {
		draw triangle(2) color:color rotate: 90 + heading;	
		draw circle(15) color: color ;	
	}
	
	aspect bdi {
		draw triangle(2) color:color rotate: 90 + heading;	
		draw circle(15) color: color empty: true;
		draw ("B:" + length(belief_base) + ":" + belief_base) color:#black size:displatTextSize; 
		draw ("D:" + length(desire_base) + ":" + desire_base) color:#black size:displatTextSize at:{location.x,location.y+displatTextSize}; 
		draw ("I:" + length(intention_base) + ":" + intention_base) color:#black size:displatTextSize at:{location.x,location.y+2*displatTextSize}; 
		draw ("curIntention:" + get_current_intention()) color:#black size:displatTextSize at:{location.x,location.y+3*displatTextSize}; 	
	}
}

species fireArea{
	float size <-1.0;
	
	init{
		grille place <- one_of(grille);
		location <- place.location;
	}
	
	aspect base {
	  draw circle(size) color: #red;
	}
}

species waterArea{
	init {
		grille place <- one_of(grille);
		location <- place.location;
	}
	aspect base {
	  draw square(5) color: #blue;		
	}
}

grid grille width: 25 height: 25 neighbors:4 {
	rgb color <- #palegreen;
}


experiment fight_fire type: gui {
	output {					
		display view1 { 
			grid grille lines: #black;
			species fireArea aspect:base;
			species waterArea aspect:base;
			species helicopter aspect: bdi;
		}
	}

}