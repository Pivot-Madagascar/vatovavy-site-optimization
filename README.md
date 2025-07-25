# Vatovavy Site Optimisation

This repo contains the code needed to run the Community Health Site optimization algorithm developed in Evans et al. (YEAR) for Ifanadiana district and run it for the two new districts that Pivot covers in Vatovavy (Nosy Varika and Mananjary).

For each district, it:

1. Creates estimated "catchments" of community health sites equivalent to Voronoi polygons around the Chef Lieu de Fokontany. This is necessary because we do not have polygons that correspond to the updated 2025 fokontany boundaries, and these voronoi polygons then approximate those fokontany boundaries.
2. Combines the data on residential zones and buildings to estimate the number of buildings for each residential zone.
3. Estimates the distance between each residential zone in a fokontany to identify that which is most central to the other residential zones
2. Creates a ranked list of the top 5 options for a community health site in each catchment (e.g. fokontany) based on the distance to building within residential zones in that catchment along the transportation network

# Installation

## Requirements

- R > v. 4.4
- `docker`


## R Packages

Run the following script to install the required R packages.

```
lapply(c("sf", "terra", "dplyr", "osrm", "tidyr), install.packages)
```

## OSRM Backend

We use the osrm-backend found here: https://github.com/Project-OSRM/osrm-backend. Following recommendations, we use the docker version. To set up the backend server, place the `pbf` file of OSM data into a directory called `osrm`. In the example below, the file is called `osm_mapping_pivot.pbf`. Then run the following code to extract and create the routing files needed. This only needs to be done one time.

```
#start docker from osrm directory
cd osrm
#run once, creates the files needed
docker run -t -v "${PWD}:/data" osrm/osrm-backend osrm-extract -p /opt/foot.lua /data/osm_mapping_pivot.pbf
docker run -t -v "${PWD}:/data" osrm/osrm-backend osrm-partition /data/osm_mapping_pivot.osrm  
docker run -t -v "${PWD}:/data" osrm/osrm-backend osrm-customize /data/osm_mapping_pivot.osrm 
```

Once the files have been extracted, you can use the following script to start up the server:

```
#run to start server on port 5000
docker run -t -i -p 5000:5000 -v "${PWD}:/data" osrm/osrm-backend osrm-routed --algorithm mld --max-table-size 10000 /data/osm_mapping_pivot.osrm 
```

This should return the IP address and port for the server, which you will need to configure the `osrm.server` in your R script `03`. Usually the default is one of `localhost:5000`, `0.0.0.0:5000`, or `127.0.0.1:5000`.

## Extract spatial data

The other supporting spatial data is contained in two compressed files: `data/mnj.tar.gz` and `data/nsv.tar.gz`. Unzip these files into `data/mnj` and `data/nsv` respsectively. These are uploaded compressed due to github LSF restrictions.


## Run the analysis

After starting the OSRM backend server (see above), you can run the R scripts in order for each district. It will create three files for each district, saved in the `output` folder:

- `catchment.gpkg`: A geopackage of the catchment polygons that are serving as a proxy for fokontany
- `res_centroid.gpkg`: A geopackage containing the centroid of each residential area with more than 4 buildings, including the number of buildings and fokontany
- `optimal_sites.gpkg`: A geopackage and csv file of the optimal community health sites by catchment 

The optimal sites files contain what you will need for the Shiny application. Each row corresponds to a potential site. The columns are:

| variable      | description                                                                                                                                              |
|---------------|----------------------------------------------------------------------------------------------------------------------------------------------------------|
| full_id       | ID of residential zone from OSM                                                                                                                          |
| comm_fkt      | the name of the commune and fokontany, seperated by `_`                                                                                                  |
| dist_wt       | the average distance (in m) between each household and the potential site                                                                                |
| distance_rank | the ranking of that site within the fokontany according to its average distance (1 = closest to households, 5 = furthest)                                |
| lat           | the latitude of the residential zone corresponding to the potential site                                                                                 |
| lon           | the longitude of the residential zone corresponding to the potential site                                                                                |
| num_buildings | the number of buildings within that residential zone. This should be used in combination with the distance to identify the best site for that fokontany. |