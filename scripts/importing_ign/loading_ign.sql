--------------------------------
-- Rémi Cura, 2016
-- projet geohistorical data
-- 
--------------------------------
-- import and normalise of current data
-- BDAdress for adress number, BDTopo for street name
--------------------------------

    CREATE SCHEMA IF NOT EXISTS ign_paris;
    SET search_path to ign_paris, historical_geocoding, geohistorical_object, public; 


-- importing the two files
	