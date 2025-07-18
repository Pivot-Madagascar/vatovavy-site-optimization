# Create Voronoi Polygons (NSV)
# Project:
# Authors:

# Michelle V Evans
# Github: mvevans89
# Email: mv.evans.phd@gmail.com

# Script originated July 2025

# Description of script and instructions ###############

#' This script creates voronoi polygons with chef lieu de fokontany 
#' as the centroid. These polygons are meant to represent catchments for 
#' community health workers, as we don't have up to date polygons for the fokontany.
#' 
#' Follows instructions from here: https://github.com/andybega/r-misc/blob/master/spatial/marked-points-to-polygons.R

# Packages and Options ###############################

options(stringsAsFactors = FALSE, scipen = 999)

library(sf)

library(dplyr)

# Load Data #############################################

district_boundary <- st_read("data/vatovavy_districts.gpkg") |>
  filter(ADM2_EN == "Nosy-Varika") |>
  st_transform(29702)
chef_pts <- st_read("data/nsv/cheflieuNV.gpkg") |>
  st_transform(29702)

# Create voronoi polygons ###############################

envelope <- st_union(district_boundary)

voronoi_list <- chef_pts |>
  st_geometry() |>
  st_union() |>
  st_voronoi(envelope =envelope) |>
  st_cast()

voronoi_tiles <- voronoi_list |>
  data.frame() |>
  st_as_sf() |>
  st_join(chef_pts) |>
  st_intersection(envelope) |>
  st_cast() |>
  select(-X, -Y) |>
  st_transform(4326)

plot(voronoi_tiles)

st_write(voronoi_tiles, "output/catchmentNSV.gpkg")
