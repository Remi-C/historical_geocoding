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
    SET search_path to poubelle_paris, public; 

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

        UTILISER outils_geocodage.numerotation2float()
  
      --vue sur les rue dont les numéros d'adresses contiennent un 0 (signe d'inconnaissance) ou un NULL (signe d'un probleme)
		SELECT *
		FROM poubelle_src , outils_geocodage.numerotation2float(adr_fg88) AS fg, outils_geocodage.numerotation2float(adr_fd88) AS fd
			, outils_geocodage.numerotation2float(adr_dg88) AS dg, outils_geocodage.numerotation2float(adr_dd88) AS dd
		-- WHERE adr_fg88::int = 0 OR adr_fg88::int IS NULL OR adr_fd88::int = 0 OR adr_fd88::int IS NULL OR adr_dg88::int = 0 OR adr_dg88::int IS NULL OR adr_dd88::int = 0 OR adr_dd88::int IS NULL
      --vue verification que les numerotations gauche et droites sont bien croissantes
        SELECT *
        FROM poubelle_src 
        WHERE adr_fg88 < adr_dg88 AND adr_fd88 > adr_dd88 OR adr_fg88 > adr_dg88 AND adr_fd88 < adr_dd88
        LIMIT 10 	
    

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
	  ORDER BY n_occurence DESC, numerotation
        WHERE 
   SELECT *
   FROM 