--------------------------------
-- Rémi Cura, 2016
-- projet geohistorical data
-- 
--------------------------------
-- import et normalisation du plan de Paris de Poubelle de Benoit
-- poubelle_TEMPORAIRE, 10/12/2014
--------------------------------

-- preparer la base de données
  --creer extensions
  CREATE EXTENSION IF NOT EXISTS postgis ; 

	-- le referentiel a utiliser est le lambert 93 : EPSG:2154
	SELECT *
	FROM spatial_ref_sys 
	WHERE srid = 2154 ; 
	
  --importer les srid de l'ign
  -- creer schema pour chargement des données
    CREATE SCHEMA IF NOT EXISTS poubelle_paris;
  -- onc hange le path psql pour ne pas avoir à repeter le schema 
    SET search_path to poubelle_paris, historical_geocoding, geohistorical_object, public; 

  --charger les données dans la base avec shp2pgsql
    -- /usr/lib/postgresql/9.5/bin/shp2pgsql -d -I /media/sf_RemiCura/DATA/Donnees_belleepoque/reseau_routier_benoit_20160701/poubelle_TEMPORAIRE.shp poubelle_paris.poubelle_src  > /tmp/tmp_poublelle.sql ;
    --  psql -d geocodage_historique -f /tmp/tmp_poublelle.sql ;
  -- la table poubelle_src est maintenant remplie
    --verification dans QGIS
    -- les données ne contiennent pas d'accent et sont déjà en majuscule...

	   SELECT *
	   FROM poubelle_src
	   LIMIT 1 ;
    --creation d'une vue pour voir les endroits problématiques
      --vue sur les rue homonymes 
        DROP VIEW IF EXISTS poubelle_compte_homonyme  ; 
        CREATE VIEW poubelle_compte_homonyme AS 
		  SELECT gid, nom_1888, count(*) over(partition by nom_1888) AS nbr_troncons, geom::geometry(multilinestring,2154)
		  FROM poubelle_src
		  ORDER BY nom_1888 ASC ;
      --vue sur les noms non rempli (NULL)    
        DROP VIEW IF EXISTS poubelle_compte_nom_null  ; 
        CREATE VIEW poubelle_compte_nom_null AS 
		SELECT gid, nom_1888, geom::geometry(multilinestring,2154)
		FROM poubelle_src
		WHERE nom_1888 IS NULL ; 

        --UTILISER outils_geocodage.numerotation2float()
  
      --vue sur les rue dont les numéros d'adresses contiennent un 0 (signe d'inconnaissance) ou un NULL (signe d'un probleme)
		SELECT *
		FROM poubelle_src , outils_geocodage.numerotation2float(adr_fg88) AS fg, outils_geocodage.numerotation2float(adr_fd88) AS fd
			, outils_geocodage.numerotation2float(adr_dg88) AS dg, outils_geocodage.numerotation2float(adr_dd88) AS dd ; 
		-- WHERE adr_fg88::int = 0 OR adr_fg88::int IS NULL OR adr_fd88::int = 0 OR adr_fd88::int IS NULL OR adr_dg88::int = 0 OR adr_dg88::int IS NULL OR adr_dd88::int = 0 OR adr_dd88::int IS NULL
      --vue verification que les numerotations gauche et droites sont bien croissantes
        SELECT *
        FROM poubelle_src 
        WHERE adr_fg88 < adr_dg88 AND adr_fd88 > adr_dd88 OR adr_fg88 > adr_dg88 AND adr_fd88 < adr_dd88
        LIMIT 10 	; 
    

	WITH tous_les_numeros AS ( 
	   SELECT gid, adr_dg88  AS numerotation FROM poubelle_src UNION ALL
	   SELECT gid, adr_dd88 FROM poubelle_src UNION ALL
	   SELECT gid, adr_fg88 FROM poubelle_src UNION ALL
	   SELECT gid, adr_fd88 FROM poubelle_src  
	  )
-- 	  SELECT  suffixe, count(*)
-- 	  FROM tous_les_numeros, outils_geocodage.normaliser_numerotation(numerotation)
-- 	  WHERE suffixe is not null
-- 	  group by suffixe
-- 	  ORDER BY suffixe ASC
	  
	  SELECT  numerotation, count(*) as n_occurence 
		, norm.*
		, outils_geocodage.numerotation2float(numerotation)
	  FROM tous_les_numeros, outils_geocodage.normaliser_numerotation(numerotation) as norm
	  GROUP BY numerotation, norm.numero, norm.suffixe
	  ORDER BY n_occurence DESC, numerotation;  





-- add relevant entry into geohistorical_object schema : `historical_source` and `numerical_origin_process`

	/*  
 
		INSERT INTO  geohistorical_object.historical_source  VALUES
		('poubelle_municipal_paris'
			, 'Atlas municipal des vingt arrondissements de la ville de Paris. 
Dressé sous la direction de M. Alphand inspecteur général des  ponts et chaussées, par les soins de M.L Fauve, géomètre en chef, avec le concours des géomètres du plan de Paris (Alphand et Fauve, 1888) réalisé sous la direction du préfet Eugène Poubelle.'
			, 'Pour tracer ce plan, Haussmann indique dans ses mémoires (Haussmann, 1893)
qu’une nouvelle triangulation complète de Paris a été effectuée entre 1856 et 1857,
sous la direction d’Eugène Deschamps 18. Ainsi, ce plan constituerait la première triangulation
complète effectuée depuis l’atlas de Verniquet, du moins si l’on conserve
l’hypothèse d’une triangulation seulement partielle pour Jacoubet. Haussmann, affirmant
qu’aucun grand plan de Paris n’existait lors de son arrivée à la préfecture
renouvelle ainsi totalement les outils de l’administration. Il n’est cependant pas certain
que les choses aient été si simples et la tendance du préfet à se placer en fondateur
de la cartographie officielle en omettant volontairement des projets antérieurs a
déjà été pointée par Pierre Casselle (Casselle, 2000) (C’était alors la commission des
embellissements du Comte Siméon qui était ignorée et son rôle auprès de l’empereur
minimisé). En effet, le frontispice d’une édition réduite au 1/10.000e conservée à la
Bibliothèque Nationale de France (Deschamps et al., 1871) indique que le grand plan
en 21 feuilles dressé à l’échelle de 1/5000 résume les travaux des géomètres du Plan...'
		, sfti_makesfti(1887, 1888, 1888, 1889)
		,  '{"default": 4, "road_axis":2.5, "building":1, "number":2}'::json 
		) ; 
	*/

	/*
		INSERT INTO geohistorical_object.numerical_origin_process VALUES
		('poubelle_paris_axis'
			, 'The axis were manually created by people from geohistorical data project, and ufrther corrected/validated by Benoit Combes'
			, 'details on data : rules of creation, validation process, known limitations, etc. 
				Initially, the axis name used abbreviation : "PL" for "place", etc. The abbrebeviation were expanded to initial meaning by Rémi Cura '
			, sfti_makesfti(2007, 2007, 2016, 2016)  -- date of data creation
			, '{"default": 1, "road_axis":3, "building":0.5, "number":1.5}'::json) --precision
		, ('poubelle_paris_number'
			, 'mix of manual and automatic creation for numbers of poubelle, which are not explicitely present in the original map.'
			, 'Poubelle only contains numbers at the beginning and end of ways. mThis numbers were manually added by people from Geohistorical data project, but many are still missing.
			Therefore Rémi Cura wrote methods to complete the missing data as best as we can and generate numbers position by linear interpolation.
			The number were placed at a given distance of axis. 
			details on data : rules of creation, validation process, known limitations, etc. '
			, sfti_makesfti(2012, 2012, 2016, 2016)  -- date of data creation
			, '{"default": 1, "road_axis":3, "building":0.5, "number":1.5, "number_semantic":0.9}'::json) --precision
	*/	

	

--analysis of poubelle road axis name : 
	-- what kind of shortening are used in 'type_voie'
	
	SELECT type_voie, count(*) as c , max(nom_1888)
	FROM poubelle_src
	GROUP BY type_voie
	ORDER BY type_voie; 

	WITH first_word AS (
		SELECT substring(nom_1888, '^(\w+)\s.*?$')as fw ,nom_1888 
		FROM poubelle_src
	)
	SELECT fw, count(*) AS c, max(nom_1888)
	FROM first_word
	GROUP BY  fw
	ORDER BY fw; 

	-- creating a list of equivalent for shortening of way type
	DROP TABLE IF EXISTS poubelle_type_voie_mapping; 
	CREATE TABLE poubelle_type_voie_mapping (
	gid serial primary key
	, type_voie text
	, type_voie_full text
	) ;

	INSERT INTO poubelle_type_voie_mapping (type_voie, type_voie_full) VALUES
		('ALL','allée'),
		('AV','avenue'),
		('BD','boulevard'),
		('CAR','carrefour'),
		('CITE','cité'),
		('COUR','cour'),
		('CRS','cours'),
		('GAL','galerie'),
		('IMP','impasse'),
		('IMPASSE','impasse'),
		('PAS','passage'),
		('PASSAGE','passage'),
		('PETIT','petit'),
		('PL','place'),
		('PLE','rue'), --note : only 1 case : PLE cafareli : upon close examination, it seems to be an error of editing : it is a 'rue'
		('PONT','pont'),
		('PORT','port'),
		('QU','quai'),
		('QUAI','quai'),
		('R','rue'),
		('RLE','ruelle'),
		('RPT','rond-point'),
		('RUE','rue'),
		('SQ','square'),
		('VLA','villa'),
		('VOI','voie'),
		('',''); 
	
	SELECT *
	FROM poubelle_src
	LIMIT 10 ; 

-- creating new table for axis and number
	
-- ### Create new tables inheriting from `historical_geocoding` ###
	SELECT *
	FROM poubelle_src
	LIMIT 100 ; 
	
	DROP TABLE IF EXISTS poubelle_axis ; 
	CREATE TABLE poubelle_axis(
		id serial primary key
	) INHERITS (rough_localisation) ; 

	DROP TABLE IF EXISTS poubelle_number ; 
	CREATE TABLE poubelle_number(
		gid serial primary key , 
		road_axis_id int REFERENCES poubelle_axis(id)
	) INHERITS (precise_localisation) ; 

	DROP TABLE IF EXISTS poubelle_alias ;
	CREATE TABLE poubelle_alias (
	) INHERITS (normalised_name_alias) ;

 
	-- register this new tables
		 SELECT enable_disable_geohistorical_object(  'poubelle_paris', 'poubelle_axis'::regclass, true)
			, enable_disable_geohistorical_object(  'poubelle_paris', 'poubelle_number'::regclass, true)
			, enable_disable_geohistorical_object(  'poubelle_paris', 'poubelle_alias'::regclass, true) ;

	--index whats necessary
		-- creating indexes 
		CREATE INDEX ON poubelle_axis USING GIN (normalised_name gin_trgm_ops) ;  
		CREATE INDEX ON poubelle_axis USING GIST(geom) ;
		CREATE INDEX ON poubelle_axis USING GIST(CAST (specific_fuzzy_date AS geometry)) ;
		CREATE INDEX ON poubelle_axis (historical_source) ;
		CREATE INDEX ON poubelle_axis (numerical_origin_process) ;

		
		CREATE INDEX ON poubelle_number USING GIN (normalised_name gin_trgm_ops) ;  
		CREATE INDEX ON poubelle_number USING GIST(geom) ;
		CREATE INDEX ON poubelle_number USING GIST(CAST (specific_fuzzy_date AS geometry)) ;
		CREATE INDEX ON poubelle_number (historical_source) ;
		CREATE INDEX ON poubelle_number (numerical_origin_process) ; 
		CREATE INDEX ON poubelle_number USING GIN (associated_normalised_rough_name gin_trgm_ops) ; 

		CREATE INDEX ON poubelle_number (road_axis_id) ; 

		CREATE INDEX ON poubelle_alias USING GIN (short_historical_source_name_1 gin_trgm_ops) ;
		CREATE INDEX ON poubelle_alias USING GIN (short_historical_source_name_2 gin_trgm_ops) ; 

-- inserting road axis: 
	-- we need to correct the nom_1888 before inserting it, using the poubelle_type_voie_mapping for that
	--first inserting 
	
	SELECT *
	FROM poubelle_src
	LIMIT 10 ; 

	SELECT *
	FROM poubelle_type_voie_mapping ;
	
	INSERT INTO poubelle_axis 
	SELECT nom_1888 AS historical_name
			,geohistorical_object.clean_text(nom_1888)   AS normalised_name
			,geom AS geom
			,NULL AS specific_fuzzy_date
			,NULL AS specific_spatial_precision 
			, 'poubelle_municipal_paris' AS historical_source
			, 'poubelle_paris_axis' AS numerical_origin_process
	FROM poubelle_src   ; 

	-- correcting the shortening :  
	WITH corrected_value_value AS (
		SELECT id,  normalised_name, prefix,  type_voie_full, postfix 
		FROM poubelle_axis
			, substring(normalised_name, '^\w+(\s.*?)$') as postfix  
			,  substring(normalised_name, '^(\w+)\s.*?$') as prefix 
			, LATERAL (SELECT type_voie_full FROM  poubelle_type_voie_mapping as tv WHERE tv.type_voie = upper(prefix)) as sub 
	)
	UPDATE poubelle_axis AS pa SET normalised_name =  cv.type_voie_full || postfix 
	FROM corrected_value_value AS cv
	WHERE pa.id = cv.id ; 

	SELECT *
	FROM poubelle_axis
	WHERE normalised_name is not null
	LIMIT 100 ; 

-- analysis of number in poubelle : 
	-- because many road are lacking the numbering information, we need to reconstruct this information
	-- first we need to re-merge the road section pertaining to a same road. 
	-- to this end, we need to find the direction of the road. In paris, the direction of a road is given regarding the Seine. 
	-- if the road is approximatively parallel to the Seine, the numbering is from uphill to downhill
	-- if the road is appromiatevily orthogonal to the Seine, the numbering is from toward the Seine to away from the Seine.


	DROP TABLE IF EXISTS seine_axis ; 
	CREATE TABLE IF NOT EXISTS seine_axis(
		gid serial primary key
		,geom geometry(linestring,2154)
	) ; 
	INSERT INTO seine_axis(geom) SELECT ST_GeomFromtext('LINESTRING(654809 6859373,653512 6860706,653027 6861191,652520 6861471,652470 6861790,652315 6861953,651636 6862209,651063 6862331,649912 6862872,648489 6862766,647860 6862187,647034 6861420)',2154); 


	SELECT *
	FROM poubelle_src
	WHERE nom_1888 ILIKE '%bonaparte%'
	 

	WITH input_road_axis AS (
		SELECT *
		FROM poubelle_axis
		WHERE historical_name  ILIKE '%bonaparte%'
		
		LIMIT 100
	)

	
	-- for how much road can we predict the direction of numbering
	-- for how much road can we interpolate 
