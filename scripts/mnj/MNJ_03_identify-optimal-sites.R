# Identify Optimal Locations
# Project:
# Authors:

# Michelle V Evans
# Github: mvevans89
# Email: mv.evans.phd@gmail.com

# Script originated July 2025

# Description of script and instructions ###############

#' For each catchment, create a ranked list of the top 5 locations for a 
#' community health site based on teh average distance to residential buildings
#' in the catchment


# Packages and Options ###############################

options(stringsAsFactors = FALSE, scipen = 999)


library(sf)
library(osrm)

library(tidyr)

library(dplyr)

# Set Up OSRM Backend ################################

#' follow the instructions in the README.md to set up the OSRM backend
#' then run the following via CLI/Terminal to start the docker server
#' cd osrm
#' docker run -t -i -p 5000:5000 -v "${PWD}:/data" osrm/osrm-backend osrm-routed --algorithm mld --max-table-size 1000000 /data/osm_mapping_pivot.osrm 

options(osrm.server = "http://0.0.0.0:5000/") #use local server

# Load Data ##########################################

villages <- st_read("output/res_centroidMNJ.gpkg")  #UPDATE######
villages <- villages |>
  mutate(lat = st_coordinates(villages)[,2],
         lon = st_coordinates(villages)[,1]) |>
  select(comm_fkt, name = full_id, lon, lat, num_buildings) |>
  #remove duplicates (also done in script 2)
  group_by(name) |>
  slice(1) |>
  ungroup() |>
  st_set_geometry(NULL)

# Calculate Distance #################################

dist_pairs <- select(villages, comm_fkt,name, lon, lat)

fkt_unique <- unique(dist_pairs$comm_fkt)

system.time({
  distance_all <- list()
  for(i in 1:length(fkt_unique)){
    this_fkt <- fkt_unique[i]
    print(paste("fokontany", i, "-", Sys.time()))
    this_dist <- filter(dist_pairs, comm_fkt == this_fkt)
    
    if(nrow(this_dist)<2){
      pair_distance <- data.frame(vill1 = this_dist$name,
                                  vill2 = this_dist$name,
                                  distance = 0) |>
        left_join(select(villages, comm_fkt1 = comm_fkt, name), by = c("vill1" = "name")) |>
        left_join(select(villages, comm_fkt2 = comm_fkt, name, bati2 = num_buildings), 
                  by = c("vill2" = "name"))
      
      distance_all[[i]] <- pair_distance
      next
    }
    
    distances <- osrmTable(loc = this_dist[,c("lon", "lat")],
                           measure = "distance")
    
    village_distance <- as.data.frame(distances$distances)
    colnames(village_distance)<- this_dist$name
    village_distance$vill1 <- this_dist$name
    
    pair_distance <- village_distance  |>
      tidyr::pivot_longer(cols = !vill1, names_to = "vill2", values_to = "distance") |>
      left_join(select(villages, comm_fkt1 = comm_fkt, name), by = c("vill1" = "name")) |>
      left_join(select(villages, comm_fkt2 = comm_fkt, name, bati2 = num_buildings), 
                by = c("vill2" = "name"))
    
    distance_all[[i]] <- pair_distance
  }
  
})


# Rank by lowest dispersal #########################

pair_distance <- bind_rows(distance_all)

dispersal <- pair_distance |>
  summarise(dist_wt = weighted.mean(distance, w = bati2),
            .by = c("vill1", "comm_fkt1"))

optimal_sites <- dispersal |>
  rename(comm_fkt = comm_fkt1) |>
  group_by(comm_fkt) |>
  arrange(dist_wt) |>
  slice(1:5) |>
  mutate(distance_rank = 1:n()) |>
  #join with coordinates
  left_join(select(villages, vill1 = name, lat, lon, num_buildings), by = "vill1") |>
  rename(full_id = vill1) |>
  st_as_sf(coords = c("lon", "lat"), crs = 4326, remove = FALSE)

#save as csv and gpkg
write.csv(optimal_sites |> st_set_geometry(NULL), "output/optimal_sitesMNJ.csv", row.names = FALSE)
st_write(optimal_sites, "output/optimal_sitesMNJ.gpkg", append = FALSE)
