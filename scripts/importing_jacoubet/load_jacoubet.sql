--------------------------------
-- Rémi Cura, 2016
-- projet geohistorical data
-- 
--------------------------------
-- import et normalisation du plan de Paris de Jacoubet de Benoit
-- 
--------------------------------

  CREATE EXTENSION IF NOT EXISTS postgis ; 	
  CREATE SCHEMA IF NOT EXISTS jacoubet_paris ; 

  
--load jacoubet road axis data with  shp2pgsql
    -- /usr/lib/postgresql/9.5/bin/shp2pgsql -d -I /media/sf_RemiCura/DATA/Donnees_belleepoque/reseau_routier_benoit_20160701/jacoubet_l93_utf8.shp jacoubet_paris.jacoubet_src_axis  > /tmp/tmp_jacoubet.sql ;
    --  psql -d geocodage_historique -f /tmp/tmp_jacoubet.sql ;


-- load jacoubet building  number
    -- /usr/lib/postgresql/9.5/bin/shp2pgsql -d -I /media/sf_RemiCura/DATA/EHESS/GIS_maurizio/Vasserot_jacoub3/vasserot_adresses_alpage_bis.shp jacoubet_paris.jacoubet_src_number  > /tmp/tmp_jacoubet.sql ;
    --  psql -d geocodage_historique -f /tmp/tmp_jacoubet.sql ;