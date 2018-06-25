/**
* Name: Environment of the BDI Bushfires simulation
*
* Author: Pierre Blarre
* 
* Based on a previous model without BDI architecture by : Sofiane Sillali, Thomas Artigue, Pierre Blarre
* 
* Description: 
* Bushfires simulation based on the Australian Black Saturday
* Fire starting points, Plots (that spread fire), Buildings, Roads, City Exits, Firewatch twers, Waterways (not currently used)
* 
* Tags : Bushfires, BDI, Cognitive Biases, Behavior Profiles
*/

model Bushfires_BDI_Cognitive_Biases
import "main.gaml"

//The fire specie is only the fire starting point that spreads to neighboring plots
species fire
{
	rgb color <- # yellow;
	float size <- 10.00;
	plot my_plot;
	point choosed_location <- nil;

	init
	{
		if (choosed_location = nil) { my_plot <- one_of(plot where (each.color = # green)); } //choose a random "nature" plot
		else { my_plot <- plot closest_to choosed_location; } //choose the closest plot from chosen location

		location <- my_plot.location;

		// Starts burning neighboring plots with a burning_probability probability
		list<plot> neighbors_plot <- my_plot.neighbors where (each.flammable = true);
		loop neighbors over: neighbors_plot
		{
			neighbors.burning <- flip(burning_probability);
		}
	}

	aspect base { draw triangle(size) color: color depth: 5 # m; }
}

//Extending Grid Species : Plots are used to spread the fire and people's detection. They are also used to create the dammage to people and buildings
grid plot height: grid_size width: grid_size neighbors: 8 use_regular_agents: false use_individual_shapes: false
{
	int id <- 1;
	rgb color <- # white;
	int burning_capacity <- rnd(100, 150); //The plot's' energy. Stops burning when reaching 0 
	
	bool flammable <- false;
	bool burning <- false;
	
	float flame_tilt <- wind + rnd(0.2);
	float heat <- 0.0;
	
	bool is_road <- false;
	bool is_building <- false;

	init
	{
		ids <- ids + 1;
		id <- ids;
		flammable <- true;
		color <- blend(# green, # maroon, 100 / burning_capacity);

		// Gray for roads
		if (!empty(roads_shapefile overlapping (self)))
		{
			flammable <- true;
			is_road <- true;
			color <- # grey;
		}

		////Waterways are currently not used
		//if (!empty( waterway_shapefile overlapping(self))  ){
		//	flammable <- false;
		//	color <- #blue;
		//}

		// Lightgray for buildings
		if (!empty(buildings_shapefile overlapping (self)))
		{
			flammable <- true;
			color <- # lightgrey;
			is_building <- true;
		}
	}
	
	// When burning, it will hurt people and damage buildings around
	reflex burn when: burning
	{
//		color <- rgb(1 among [# orange, # red]); // Fire animation
		color <- # red; // Simple color for less resource

		//act only every burning_speed cycle to influence burning speed
		if ((cycle + id) mod burning_speed = 0)
		{
			// Build a list of people at plot's hurting distance
			list<plot> plot_at_hurting_distance <- self neighbors_at hurting_distance;
			list<people> victims;
			loop pl over: plot_at_hurting_distance
			{
				victims <- victims + every_resident_alive inside pl where (!each.in_safe_place);
				victims <- victims + firefighters inside pl where (each.alive);
				victims <- victims + policemen inside pl where (each.alive) where (!each.in_safe_place);
			}

			//Hurt people
			loop victim over: victims
			{
				ask victim
				{
					on_alert <- true;
					do color; //change color
				}
				
				// Burn : - 30 energy  at distance 1,  -15 at 2,  -10 at 3
				victim.energy <- victim.energy - int(30 / max([1, victim distance_to self]));
				
				if (victim.energy <= 0) {  // no more energy, person's dead
					if(show_residents_messages and victim.alive) { ask victim { do status("I'm dead :-("); } } //little to trick to display the message only once
					victim.alive <- false;
				}
				else if (string(victim) contains "resident") { victim.speed <- victim.speed - rnd(0, 0.3); } // slow down hurt people
			}

			// Dammage buildings
			list<building> bldins <- building overlapping (self) where (each.damage < 255 and each.bunker = false);
			loop bld over: bldins
			{
				float damage <-  min([1, bld.resistance / 300]);
				bld.damage <- bld.damage + rnd(1.0, 1.5) - damage;
			}

			// Fire spread
			list<plot> neighbors_plot <- neighbors where (!each.burning and each.burning_capacity > 0); //get non burning neighboring plots
			loop neighbor over: neighbors_plot
			{
				if (neighbor.flammable)
				{
					float combust_limmit <- is_road ? 5.0 : (is_building ? 2.5 : 1.0); //get neighbor's heat value
					if (neighbor.heat < combust_limmit) // If low heat, it will increases reagrding the flames tilt
					{
						flame_tilt <- wind + rnd(0.2);
						neighbor.heat <- neighbor.heat + ((drought * 0.2) + 0.1 * flame_tilt);
					}

					// if heat > 1, the plot starts burning
					if (neighbor.heat >= combust_limmit)
					{
						neighbor.burning <- true;
					}
				}
			}

			// Combustion of fire
			burning_capacity <- burning_capacity - rnd(3, 7);
			if (burning_capacity < 0)
			{
				burning <- false;
				color <- is_road ? rgb(5, 1, 1) : # maroon;
			}

		}
	}
}

//TODO : create sub-species like house, shelters, etc. instead of using variables
species building schedules: [] frequency: 0
{
	bool bunker <- false;
	bool fire_station <- false;
	bool police_station <- false;

	int resistance <- rnd(100, 200);
	float damage <- 0.0;

	float height <- simple_buildings ? 5 # m + rnd(10) # m : 10 # m + rnd(30) # m;
	
	string texture <- "../assets/images/bd_text.png";
	string roof_texture <- "../assets/images/bd_roof.png";
	string bunker_texture <- "../assets/images/bunker_txt.png";

	aspect base
	{
		if(!simple_buildings)
		{
			// graded gray, turning to black as the building burns
			draw shape texture: bunker ? [bunker_texture, bunker_texture] : [roof_texture, texture] color: bunker ? # yellow : (fire_station ? # red : (police_station ? blend(# black, #
			blue, damage / resistance) : ((resistance > 230 and damage = 0.0) ? blend(# black, # magenta, damage / resistance) : blend(# black, # white, damage / resistance)))) border: #
			black depth: height;
		}
		else
		{
			//A more simple shape for using less ressource
			draw circle(5 # m) color: bunker ? # yellow 
				: (fire_station ? # red 
				: (police_station ? blend(# black, #blue, damage / resistance) 
				: ((resistance > 230 and damage = 0.0) ? blend(# black, # magenta, damage / resistance) 
				: blend(# black, # gray, damage / resistance) ) ) ) 
			border: #black depth: height;
		}
		
	}
}

species road
{
	int id <- 1;
	rgb color <- # darkgrey;
	bool is_practicable <- true;
	geometry display_shape <- shape + 2.0;
	init
	{
		ids <- ids + 1;
		id <- ids;
	}

	aspect base { draw shape color: color width: 4.0; }

	reflex refresh_road when: ((cycle + id) mod 20 = 0)
	{
		is_practicable <- empty(plot overlapping (self) where each.burning); //usable when no plots on the road is burning
		color <- is_practicable ? # grey : # red;
		road_network_practicable <- as_edge_graph(road where each.is_practicable); //show unusable roads
	}

}

//escape routes / shelters
species city_exit
{
	int nb_escaped_through_me <- 0 update: length((every_resident_alive) at_distance 30 # m where (each.alive and each.in_safe_place));
	init
	{
		nb_exit <- nb_exit + 1;
	}

	aspect base
	{
		draw circle(30 # m) color: # white depth: 1 # m border: # black;
		draw string(nb_escaped_through_me) color: # black size: 50 at: point(self.location.x - 1, self.location.y - 2, self.location.z + 5) depth: 2 # m;
	}
}

//Thre firewatch tower can be placed on the map in strategic places in order to detect fires and alert emergency services earlier
species firewatch skills: [fipa]
{
	bool warningSent <- false;
	string roof_texture <- "../images/bd_roof.png";
	plot my_plot;
	point choosed_location <- nil;

	aspect base
	{
		draw circle(100) texture: [roof_texture] depth: 1 # m border: # black;
		draw square(10) color: warningSent ? # orange : # white depth: 40 # m;
	}

	init
	{
		if (choosed_location = nil) { my_plot <- one_of(plot where (each.color = # green)); } 
		else { my_plot <- plot closest_to choosed_location; }
		location <- my_plot.location;
	}

	// Watch for burning plots every 20 cycles
	reflex watch when: cycle mod 20 = 0
	{
		list<plot> plot_is_fire <- plot where each.burning at_distance 100;

		if (length(plot_is_fire) != 0 and !warningSent) //fire detected and no warning sent
		{
			if (!empty(firefighters)) //there's some available (alive) firefighter
			{
				do start_conversation(to: firefighters where each.alive, protocol: 'fipa-propose', performative: 'propose', contents: ['Il y a un feu!']);
			}
			warningSent <- true;
		}

		if (length(firefighters where each.on_alert) < 1) //we make sure warning isn't sent if no firefighter is on alert
		{
			warningSent <- false;
		}

	}
}

// Currently unused. It could be set to test natural barriers or water sources for firefighters
species waterway schedules: [] frequency: 0 {
	rgb color <- #blue;
	aspect base {
		draw shape color: color;
	}
}
