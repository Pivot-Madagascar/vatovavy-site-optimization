# Format Residential Zones
# Project:
# Authors:

# Michelle V Evans
# Github: mvevans89
# Email: mv.evans.phd@gmail.com

# Script originated July 2025

# Description of script and instructions ###############

#' We need the residential zones formatted to include the number of buildings and 
#' be points that we can use along the OSRM routing network.
#' 
#' Note that loading this data and processing it requires at least 16 GB RAM.


# Packages and Options ###############################

options(stringsAsFactors = FALSE, scipen = 999)

library(sf)
library(terra)

library(dplyr)

# Load Data #########################################

catchments <- st_read("output/catchmentNSV.gpkg")
res_zones <- st_read("data/nsv/zoneresNV.gpkg")
buildings <- st_read("data/nsv/batimentNV.gpkg")


# Count buildings in each residential zone #########
#use terra objects as they are much faster

res_terra <- vect(res_zones)
build_terra <- vect(buildings)

intersect_matrix <- relate(res_terra, build_terra, relation = "intersects")
building_count <- rowSums(intersect_matrix)
#drop intersect_matrix to help with RAM
rm(intersect_matrix)
gc()

# Get centroid of each residential zone and combine with building counts #####################

res_zones$buildings <- building_count

res_centroid <- res_zones |>
  #only consider residential zones with more than 4 buildings
  filter(buildings>4) |>
  select(full_id, osm_id, num_buildings = buildings) |>
  st_centroid() |>
  #get commmune/fokontany of each
  st_join(catchments) |>
  mutate(comm_fkt = paste(toupper(commune), toupper(fokontany), sep = "_")) |>
  #assign centroid to one fokontany if it touches multiple
  group_by(full_id) |>
  slice(1) |>
  ungroup() 

# Save ###############################################################

st_write(res_centroid, "output/res_centroidNSV.gpkg", append = FALSE)
