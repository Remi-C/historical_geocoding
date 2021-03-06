﻿--------------------------------
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
	-- /usr/lib/postgresql/9.5/bin/shp2pgsql -d -I /media/sf_RemiCura/DATA/EHESS/GIS_maurizio/PARCELLAIRE_APUR_TOTAL/Quartiers_apur.shp apur_paris.apur_quartier_paris_src  >> /tmp/tmp_apur.sql ;
	-- psql -d geocodage_historique -f /tmp/tmp_apur.sql  ;
	ALTER TABLE apur_quartier_paris_src ALTER COLUMN GEOM TYPE geometry(multipolygon,2154) USING ST_Transform(ST_SetSRID(geom,932001),2154) ; 

	SELECT *
	FROM apur_quartier_paris_src ;


-- adding the relevant information in geohistorical_object : 
	INSERT INTO  geohistorical_object.historical_source  VALUES
			('apur_paris_quartier'
				, 'fichier de l Agence Parisienne de L Urbanisme decrivant les quartiers de Paris, recupere chez Maurizio'
				, ' Pas de detail sur ces donnees, les qualites sont donc à prendre avec des pincettes'
			, sfti_makesfti(2000, 2001, 2009, 2010)
			,  '{"default":1, "quartier":100}'::json 
			) ; 

			INSERT INTO geohistorical_object.numerical_origin_process VALUES
			('apur_paris_quartier_process'
				, 'fichier de l Agence Parisienne de L Urbanisme decrivant les quartiers de Paris, recupere chez Maurizio, processus de production inconnu'
				, 'processus de production inconnu '
				, sfti_makesfti(2000, 2001, 2009, 2010)
				,  '{"default":1, "quartier":100}'::json 
			) ;

-- creating tables
	
	DROP TABLE IF EXISTS apur_paris_quartier CASCADE; 
	CREATE TABLE apur_paris_quartier(
		gid serial primary key REFERENCES apur_quartier_paris_src(gid)
	) INHERITS (rough_localisation) ;  
	TRUNCATE apur_paris_quartier CASCADE ; 

	-- register this new tables
		 SELECT enable_disable_geohistorical_object(  'apur_paris', 'apur_paris_quartier'::regclass, true) ; 


		 CREATE INDEX ON apur_paris_quartier USING GIN (normalised_name gin_trgm_ops) ;  
		CREATE INDEX ON apur_paris_quartier USING GIST(geom) ;
		CREATE INDEX ON apur_paris_quartier USING GIST(CAST (specific_fuzzy_date AS geometry)) ;
		CREATE INDEX ON apur_paris_quartier (historical_source) ;
		CREATE INDEX ON apur_paris_quartier (numerical_origin_process) ; 

	-- inserting into this table
	TRUNCATE apur_paris_quartier ; 
	INSERT INTO apur_paris_quartier
	SELECT  
		l_qu
		, 'quartier '|| clean_text(l_qu)
		,geom
		, NULL
		, radius
		,'apur_paris_quartier'
		,'apur_paris_quartier_process'
		,gid 
	FROM apur_quartier_paris_src
		, ST_MinimumBoundingRadius(geom) as f ;  

		SELECT DISTINCT historical_source, numerical_origin_process
		FROM rough_localisation ; 

		