--------------------------------
-- Rémi Cura, 2016
-- projet geohistorical data
-- 
--------------------------------
-- import and normalise of current data
-- from APUR : on Paris neighboorhood
--------------------------------



	CREATE SCHEMA IF NOT EXISTS apur_paris;
	SET search_path to apur_paris, historical_geocoding, geohistorical_object, public; 



-- importing the APUR sHape file
	-- /usr/lib/postgresql/9.5/bin/shp2pgsql -d -I /media/sf_RemiCura/DATA/Donnees_IGN/bd_adresse/adresse.shp ign_paris.ign_bdadresse_src  >> /tmp/tmp_ign.sql ;
	-- psql -d geocodage_historique -f /tmp/tmp_ign.sql  ;

