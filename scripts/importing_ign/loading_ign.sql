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
	-- /usr/lib/postgresql/9.5/bin/shp2pgsql -d -I /media/sf_RemiCura/DATA/Donnees_IGN/bd_adresse/adresse.shp ign_paris.ign_bdadresse_src  >> /tmp/tmp_ign.sql ;
	-- psql -d geocodage_historique -f /tmp/tmp_ign.sql  ;

	-- /usr/lib/postgresql/9.5/bin/shp2pgsql -d -I /media/sf_RemiCura/DATA/Donnees_IGN/bd_adresse/troncon_de_route.shp ign_paris.ign_bdadresse_axis_src  >> /tmp/tmp_ign2.sql ;
	-- psql -d geocodage_historique -f /tmp/tmp_ign2.sql  ;

	-- /usr/lib/postgresql/9.5/bin/shp2pgsql -d -W "LATIN1" -I /media/sf_RemiCura/DATA/Donnees_IGN/geofla/GEOFLA/1_DONNEES_LIVRAISON_2014-12-00066/GEOFLA_2-0_SHP_LAMB93_FR-ED141/COMMUNE/COMMUNE.SHP ign_paris.ign_commune_src  >> /tmp/tmp_ign3.sql ;
	-- psql -d geocodage_historique -f /tmp/tmp_ign3.sql  ;
	
	ALTER TABLE ign_bdadresse_src ALTER COLUMN geom TYPE geometry(point,2154) USING ST_SetSRID(geom,2154)  ; 
	ALTER TABLE ign_bdadresse_axis_src ALTER COLUMN geom TYPE geometry(MultilinestringZ,2154) USING ST_SetSRID(ST_Force3D(geom),2154)  ; 
	ALTER TABLE ign_commune_src  ALTER COLUMN geom TYPE geometry(Multipolygon,2154) USING ST_SetSRID( geom, 2154)  ; 

 
	
	SELECT *
	FROM ign_bdadresse_src
	LIMIT 1  ; 

	SELECT * 
	FROM ign_bdadresse_axis_src
	LIMIT 1  ; 

	SELECT *
	FROM ign_commune_src
	LIMIT 1  ; 

	-- the import is too large, we need to remove the road and number that are not within paris:
		 
		--remove road axis that are not in paris 
		--remove number that are not in paris
 
		DELETE FROM  ign_bdadresse_axis_src
		WHERE code_posta NOT ILIKE '75%'  ; 

		DELETE FROM  ign_bdadresse_src
		WHERE code_posta NOT ILIKE '75%'  ; 
  

-- add relevant entry into geohistorical_object schema : `historical_source` and `numerical_origin_process`

 
		-- DELETE FROM  geohistorical_object.historical_source   WHERE short_name ILIKE '%ign_paris%' ; 
		INSERT INTO  geohistorical_object.historical_source  VALUES
		('ign_paris'
			, 'Produit BDAdresse et BDtopo fourni par l IGN, extrait de 2016 par l interface web'
			, 'La BDtopo fourni des axes relativement fiables sur toute la france, les numérotations sont en revanche souvent placé automatiquement, d ou un manque de qualité parfois. Les numéros sont à l adresse'
		, sfti_makesfti(2006,2007, 2012,2013)
		,  '{"default": 1, "road_axis":1, "building":1, "number":4}'::json 
		) ; 

		INSERT INTO  geohistorical_object.historical_source  VALUES
		('ign_commune_geofla'
			, 'Produit par l IGN, ,recupere sur le site en 2013'
			, 'ce fichier fourni les limites officiel des communes, et une correspondance avec leur code postal, cela dit l orthographe des communes est problematique, car les noms ont été posttraité'
		, sfti_makesfti(2006,2007, 2012,2013)
		,  '{"default": 30, "town":30}'::json 
		) ; 
	 
		INSERT INTO geohistorical_object.numerical_origin_process VALUES
		('ign_paris_axis'
			, 'les axes de la bdtopo sont fait par mise à jour et photo interpretation. La precision 3D est plus faible que la précision plani'
			, 'Export web de la bdtopo en 2016, sur la plateforme pour les adresses (tous les champs de la bdtopo ne sont pas là) '
			, sfti_makesfti(2010, 2010, 2016, 2016)  -- date of data creation
			, '{"default": 2, "road_axis":2}'::json  ) 
		,
		('ign_paris_number'
			, 'Les numerotations de la BDAdresse export 2016 sont générés automatiquement par interpolations linéaire, puis corrigés pour etre placé à la plaqsue la plupart du temps. '
			, 'Les numérotations ne sont pas toujours extremement fiables, il s agit d une export par le web de 2016'
			, sfti_makesfti(2010, 2010, 2016, 2016)  -- date of data creation
			, '{"default": 1, "road_axis":3, "building":0.5, "number":1.5}'::json) --precision

		, 
		('ign_france_town'
			, 'limite des communes avec des noms posttraite un peu dur à lire, ainsi que code postal '
			, 'il s agit dun export web de 2013'
			, sfti_makesfti(2012, 2012, 2013, 2013)  -- date of data creation
			,  '{"default": 30, "town":30}'::json 
			)
		 ; 
 
 
-- creating the geocoding tables : 
	DROP TABLE IF EXISTS ign_paris_axis CASCADE; 
	CREATE TABLE ign_paris_axis(
		gid serial primary key REFERENCES ign_bdadresse_axis_src(gid)
		, clef_bdtopo text UNIQUE
	) INHERITS (rough_localisation) ;  
	TRUNCATE ign_paris_axis CASCADE ; 

	DROP TABLE IF EXISTS ign_france_town CASCADE; 
	CREATE TABLE ign_france_town(
		gid serial primary key REFERENCES ign_commune_src(gid) 
	) INHERITS (rough_localisation) ;  
	TRUNCATE ign_france_town CASCADE ; 

	DROP TABLE IF EXISTS ign_paris_number ; 
	CREATE TABLE ign_paris_number(
		gid serial primary key  REFERENCES ign_bdadresse_src(gid) 
		, clef_bdtopo text REFERENCES ign_paris_axis(clef_bdtopo ) 
	) INHERITS (precise_localisation) ; 
	TRUNCATE ign_paris_number CASCADE ; 
	

	DROP TABLE IF EXISTS ign_paris_alias ;
	CREATE TABLE ign_paris_alias (
	) INHERITS (normalised_name_alias) ;

 
	-- register this new tables
		 SELECT enable_disable_geohistorical_object(  'ign_paris', 'ign_paris_axis'::regclass, true)	 
			, enable_disable_geohistorical_object(  'ign_paris', 'ign_france_town'::regclass, true)	 
			, enable_disable_geohistorical_object(  'ign_paris', 'ign_paris_number'::regclass, true)
			, enable_disable_geohistorical_object(  'ign_paris', 'ign_paris_alias'::regclass, true) ;

	--index whats necessary
		-- creating indexes 
		CREATE INDEX ON ign_paris_axis USING GIN (normalised_name gin_trgm_ops) ;  
		CREATE INDEX ON ign_paris_axis USING GIST(geom) ;
		CREATE INDEX ON ign_paris_axis USING GIST(CAST (specific_fuzzy_date AS geometry)) ;
		CREATE INDEX ON ign_paris_axis (historical_source) ;
		CREATE INDEX ON ign_paris_axis (numerical_origin_process) ; 
		CREATE INDEX ON ign_paris_axis (clef_bdtopo) ; 

		CREATE INDEX ON ign_france_town USING GIN (normalised_name gin_trgm_ops) ;  
		CREATE INDEX ON ign_france_town USING GIST(geom) ;
		CREATE INDEX ON ign_france_town USING GIST(CAST (specific_fuzzy_date AS geometry)) ;
		CREATE INDEX ON ign_france_town (historical_source) ;
		CREATE INDEX ON ign_france_town (numerical_origin_process) ;  
 

		
		CREATE INDEX ON ign_paris_number USING GIN (normalised_name gin_trgm_ops) ;  
		CREATE INDEX ON ign_paris_number USING GIST(geom) ;
		CREATE INDEX ON ign_paris_number USING GIST(CAST (specific_fuzzy_date AS geometry)) ;
		CREATE INDEX ON ign_paris_number (historical_source) ;
		CREATE INDEX ON ign_paris_number (numerical_origin_process) ; 
		CREATE INDEX ON ign_paris_number USING GIN (associated_normalised_rough_name gin_trgm_ops) ; 
		CREATE INDEX ON ign_paris_number (clef_bdtopo) ; 
 

		CREATE INDEX ON ign_paris_alias USING GIN (short_historical_source_name_1 gin_trgm_ops) ;
		CREATE INDEX ON ign_paris_alias USING GIN (short_historical_source_name_2 gin_trgm_ops) ; 

-- filling the town table : 
	SELECT historical_name, normalised_name, geom, specific_fuzzy_date, specific_spatial_precision, historical_source, numerical_origin_process, gid
	FROM ign_france_town
	LIMIT 1  ; 

	TRUNCATE ign_france_town ; 
	INSERT INTO ign_france_town
		SELECT nom_com
			, 'commune '|| clean_text(replace(nom_com, '-', ' ')) 
			, geom
			, NULL
			, NULL
			, 'ign_commune_geofla'
			,'ign_france_town'
			,gid
	 FROM ign_commune_src  ;  
	 

-- preparing to fill the axis table
	--first road name contain shortening, which is annoying for normalised name
	--checking the list of shortening used in the road name of 

	
	SELECT  nom_rue_ga AS nr_g, nom_rue_dr AS nr_d, cleabs, code_posta As code_postal, daterec, geom 
	FROM ign_bdadresse_axis_src
	WHERE nom_rue_ga !=  nom_rue_dr;  

	--because road name on left and on right side may not be the same, 
