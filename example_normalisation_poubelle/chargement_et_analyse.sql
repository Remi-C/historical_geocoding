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

  -- creer schema pour chargement des données
	--DROP SCHEMA IF EXISTS poubelle CASCADE; 
	CREATE SCHEMA IF NOT EXISTS poubelle;
  -- on change le path psql pour ne pas avoir à repeter le schema 
	SET search_path to poubelle, public; 


  --charger les données dans la base avec shp2pgsql
		/* ----------------------------
		/usr/lib/postgresql/9.5/bin/shp2pgsql -d -S 2154 -I /media/sf_RemiCura/DATA/Donnees_belleepoque/reseau_routier_benoit_20160701/poubelle_TEMPORAIRE_emprise_utf8_L93_v2.shp poubelle.poubelle_src  > /tmp/tmp_poublelle.sql ;
		psql -d geocodage_historique -f /tmp/tmp_poublelle.sql ;
		------------------------------- */
	  -- la table poubelle_src est maintenant remplie
	    --verification dans QGIS
	    -- les données ne contiennent pas d'accent et sont déjà en majuscule...

		   SELECT *
		   FROM poubelle_src
		   LIMIT 1 ;

  --creation d'une vue pour voir les endroits problématiques
      --vue sur les rue homonymes 

		SELECT DISTINCT ON (nom_1888) nom_1888 , show_trgm(nom_1888)
		FROM poubelle_src
		WHERE nom_1888 % 'r de l ecole de medecine'
		ORDER BY nom_1888, ST_LEngth(geom) DESC
      
		DROP VIEW IF EXISTS poubelle_compte_homonyme  ; 
		CREATE VIEW poubelle_compte_homonyme AS 

			  SELECT gid, nom_1888, count(*) over(partition by nom_1888) AS nbr_troncons, geom::geometry(multilinestring,2154)
			  FROM poubelle_src
			  ORDER BY nom_1888 ASC ;



			  SELECT *-- distinct type_voie
				  FROM poubelle_src 
				  WHERE type_voie % 'PLE'
				  ORDER BY type_voie
				  LIMIT 10


		DROP MATERIALIZED  VIEW IF EXISTS poubelle_homonyme_non_connecte ; 
		CREATE MATERIALIZED VIEW poubelle_homonyme_non_connecte AS 

			WITH parameters AS (
				SELECT 20 AS dist_tolerancy
			)
			,  unioned_axis AS (
				  SELECT   nom_1888, ST_Union(ST_Buffer( geom, dist_tolerancy, 'quad_segs=2'  ) ) AS geom_clusters,   array_agg(gid) AS gids
				  FROM poubelle_src 
					, parameters
				  GROUP BY nom_1888
			  )
			   , list_of_places AS (
				SELECT geom
				 FROM poubelle_src 
				  WHERE type_voie ILIKE 'PL'
			  )
			  , fusion_of_places_for_union AS (
				SELECT nom_1888,   ST_union(ST_Buffer( geom, dist_tolerancy, 'quad_segs=2' ) ) AS places 
				FROM  parameters , unioned_axis, list_of_places 
				WHERE ST_DWIthin(geom_clusters, geom, dist_tolerancy-1) = TRUE
				GROUP BY nom_1888
			  )
			 , add_places_to_union AS (
				SELECT nom_1888, CASE WHEN places IS NOT NULL THEN ST_Union(geom_clusters,places) ELSE  geom_clusters END   AS geom_clusters,gids
				FROM unioned_axis
					LEFT OUTER JOIN fusion_of_places_for_union USING (nom_1888) 
			  ) 
			 , cluster_candidates AS (
				SELECT row_number() over() as fid, nom_1888,gids , n_clusters, dmp.geom AS clust
				FROM add_places_to_union, ST_CollectionExtract(geom_clusters, 3) AS g
					,ST_NumGeometries(g) as n_clusters , ST_Dump(g) as dmp
			  ) 
			  SELECT fid, nom_1888,gids , ST_Multi(clust)::geometry(multipolygon,2154) AS clust
			  FROM cluster_candidates
			  WHERE n_clusters > 1 ; 
			   
      --vue sur les noms non rempli (NULL)    
		DROP VIEW IF EXISTS poubelle_compte_nom_null  ; 
		CREATE VIEW poubelle_compte_nom_null AS 
			SELECT gid, nom_1888, geom::geometry(multilinestring,2154)
			FROM poubelle_src
			WHERE nom_1888 IS NULL ; 

	/* -----------------------------------------------------
	- INSTALLER LES outils_geocodage : 'ordonnancement_numero.sql' : les fonction snecessaires pour outils_geocodage.numerotation2float()
	-------------------------------------------------------- */
        
  
      --vue sur les rue dont les numéros d'adresses contiennent un 0 (signe d'inconnaissance) ou un NULL (signe d'un probleme)
		DROP VIEW IF EXISTS poubelle_numerotation_0_null; 
		CREATE VIEW poubelle_numerotation_0_null AS 
		SELECT *, (fg=0)::int + (fd=0)::int + (dg=0)::int + (dd=0)::int AS nbr_zeros
		FROM poubelle_src , outils_geocodage.numerotation2float(adr_fg88) AS fg, outils_geocodage.numerotation2float(adr_fd88) AS fd
			, outils_geocodage.numerotation2float(adr_dg88) AS dg, outils_geocodage.numerotation2float(adr_dd88) AS dd 
		WHERE fg::int = 0 OR fg::int IS NULL OR fd::int = 0 OR fd::int IS NULL OR dg::int = 0 OR dg::int IS NULL OR dd::int = 0 OR dd::int IS NULL

      --vue verification que les numerotations gauche et droites sont bien croissantes
		DROP VIEW IF EXISTS poubelle_numerotation_pas_croissante; 
		CREATE VIEW poubelle_numerotation_pas_croissante AS 
		SELECT *
		FROM poubelle_src , outils_geocodage.numerotation2float(adr_fg88) AS fg, outils_geocodage.numerotation2float(adr_fd88) AS fd
				, outils_geocodage.numerotation2float(adr_dg88) AS dg, outils_geocodage.numerotation2float(adr_dd88) AS dd 
		WHERE fg < dg AND fd > dd OR fg > dg AND fd < dd;  
	    

	-- vue sur l'ensemble des numérotations existantes
		DROP VIEW IF EXISTS poubelle_ensemble_numerotations_distinctes;
		CREATE VIEW poubelle_ensemble_numerotations_distinctes AS 
		WITH tous_les_numeros AS ( 
		   SELECT gid, adr_dg88  AS numerotation FROM poubelle_src UNION ALL
		   SELECT gid, adr_dd88 FROM poubelle_src UNION ALL
		   SELECT gid, adr_fg88 FROM poubelle_src UNION ALL
		   SELECT gid, adr_fd88 FROM poubelle_src  
		  ) 
		  
		  SELECT  numerotation, count(*) as n_occurence 
			, norm.*
			, outils_geocodage.numerotation2float(numerotation)
		  FROM tous_les_numeros, outils_geocodage.normaliser_numerotation(numerotation) as norm
		  GROUP BY numerotation, norm.numero, norm.suffixe
		  ORDER BY suffixe, n_occurence DESC, numerotation  ; 