------------------------
-- Remi Cura, 2016 , Projet Belle Epoque
------------------------

-- load the data collected by maurizio gribaudi from ehess


DROP SCHEMA  IF EXISTS ehess_data;

CREATE SCHEMA IF NOT EXISTS ehess_data  ;

SET search_path to ehess_data, public ; 

-- starting by loading professiono data at 3 dates
DROP TABLE IF EXISTS profession_raw ; 
CREATE TABLE profession_raw (
nl text,
nfsource text,
nlfs text,
catP text,
Professionobs text,
profession text,
Profession_complement text,
detail text,
NIND text,
NOMOK text,
indiv_titre text,
type_rue text,
article_rue text,
nom_rue text,
num_rue text,
nom_immeuble text,
date text,
source text,
NINDSUCC text,
successeur_de text,
autres_informations_geographiques text,
autres_infos text
) ;

COPY profession_raw
FROM '/media/sf_RemiCura/DATA/Donnees_belleepoque/ehess/BOTTINS_PROFS_OK.csv'
WITH (FORMAT CSV, HEADER,  DELIMITER ';', ENCODING 'LATIN1'); 
DELETE FROM profession_raw WHERE nl = 'nl' ; --removing first row withheaders


-- select set_limit(0.8) ; 
DROP TABLE IF EXISTS profession_geocoded ; 
CREATE TABLE profession_geocoded AS 
SELECT  nl, catp, professionobs, nind, nomok
		, date AS sdate, source
		, adresse
		, f.*
		, St_Multi(ST_Buffer(f.geom, f.spatial_precision))::geometry(multipolygon,2154) AS fuzzy_geom
FROM profession_raw
	, trim(both ' '::text from 
		COALESCE(num_rue, ' '::text) || ' '::text || 
		COALESCE(type_rue, ' '::text)|| ' '::text || 
		COALESCE(article_rue, ' '::text)|| ' '::text || 
		COALESCE(nom_rue, ' '::text) ) AS adresse_temp
	, CAST((postal_normalize(adresse_temp))[1] AS text) as adresse
	, historical_geocoding.geocode_name(
		query_adress:=adresse
		, query_date:= sfti_makesfti(date::int-1,date::int,date::int,date::int+1)
		, target_scale_range := numrange(0,30)
		, ordering_priority_function := '100 * semantic + 5 * temporal  + 0.01 * scale + 0.001 * spatial '
			, semantic_distance_range := numrange(0.5,1)	
			, temporal_distance_range:= sfti_makesfti(1820,1820,2000,2000)
			, scale_distance_range := numrange(0,30) 
			, optional_reference_geometry := NULL-- ST_Buffer(ST_GeomFromText('POINT(652208.7 6861682.4)',2154),5)
			, optional_spatial_distance_range := NULL -- numrange(0,10000)
		) as f
LIMIT 1000 ;



 
-- now loading another type of data , people with the right to vote in 1844: 


DROP TABLE IF EXISTS censitaire_raw ;
CREATE TABLE IF NOT EXISTS censitaire_raw (
orsid text primary key, 
code_elect text,
ardt_num text,
ardt_alp text,
n_ordre text,
nom text,
prenom text,
profession text,
profession_special text, 
domicile text,
date_naiss text,
tot_contr text,
lieu_paiement text,
lieu_contrib text, 
fonciere text,
person text,
port text,
patente text,
nat_titre text,
motif_retranchement text 
); 



COPY censitaire_raw
FROM '/media/sf_RemiCura/DATA/Donnees_belleepoque/ehess/censitairesParis.csv'
WITH (FORMAT CSV, HEADER, DELIMITER ';', ENCODING 'LATIN1');

--celaning the iunput adresse, it is written in reverse, with shortenings
 SELECT domicile 
	, (postal_normalize(regexp_replace(domicile , '^(.*?)(\d+.*?)$', '\2 \1')))[1]
 FROM censitaire_raw
 LIMIT 1000 ; 


--SELECT set_limit(0.8)

DROP TABLE IF EXISTS censitaire_geocoded ; 
CREATE TABLE censitaire_geocoded AS 
 SELECT orsid, code_elect, nom, prenom, profession, date_naiss, tot_contr, lieu_paiement, lieu_contrib
	, adresse
	, f.*, 
	 St_Multi(ST_Buffer(f.geom, f.spatial_precision))::geometry(multipolygon,2154) AS fuzzy_geom

  FROM censitaire_raw 
	, CAST((postal_normalize(regexp_replace(domicile , '^(.*?)(\d+.*?)$', '\2 \1')))[1] AS text) AS adresse
	, historical_geocoding.geocode_name(
		query_adress:=adresse
		, query_date:= sfti_makesfti(1844-1,1844,1844,1844+1)
		, target_scale_range := numrange(0,30)
		, ordering_priority_function := '100 * semantic + 5 * temporal  + 0.01 * scale + 0.001 * spatial '
			, semantic_distance_range := numrange(0.5,1)	
			, temporal_distance_range:= sfti_makesfti(1820,1820,2000,2000)
			, scale_distance_range := numrange(0,30) 
			, optional_reference_geometry := NULL-- ST_Buffer(ST_GeomFromText('POINT(652208.7 6861682.4)',2154),5)
			, optional_spatial_distance_range := NULL -- numrange(0,10000)
		) as f
 LIMIT 1000 ; 


-- now loading another type of data , poeople who get arrested in 1848 after the failed revolution: 


DROP TABLE IF EXISTS prevenu_raw ; 
CREATE TABLE prevenu_raw (
num_ligne text primary key,
num_doublon text,
num_registre text,
ville text,
cod_ban text,
attribut text,
particule text,
nom_rue text,
num_adr text,
nom text,
prenom text,
age text,
profession text,
activite text,
branche text,
lieu_naiss text,
dep_naiss text,
decision text,
sexe text
) ; 



COPY prevenu_raw
FROM '/media/sf_RemiCura/DATA/Donnees_belleepoque/ehess/prevenus_tous_dec_2012.csv'
WITH (FORMAT CSV, HEADER, DELIMITER ';', ENCODING 'LATIN1');

--11644

-- select set_limit(0.8)
DROP TABLE IF EXISTS prevenu_geocoded ; 
CREATE TABLE IF NOT EXISTS prevenu_geocoded AS
SELECT num_ligne, ville
	, num_adr, attribut, particule, nom_rue
	, nom, prenom, age, profession, 
	lieu_naiss,decision
	, adresse
	, f.*
	,  St_Multi(ST_Buffer(f.geom, f.spatial_precision))::geometry(multipolygon,2154) AS fuzzy_geom
FROM prevenu_raw
	, trim(both ' '::text from 
		COALESCE(num_adr, ' '::text) || ' '::text || 
		COALESCE(attribut, ' '::text)|| ' '::text || 
		COALESCE(particule, ' '::text)|| ' '::text || 
		COALESCE(nom_rue, ' '::text)|| ' '::text  ) AS adresse_temp
	, CAST((postal_normalize(adresse_temp))[1] AS text) as adresse
	, historical_geocoding.geocode_name(
		query_adress:=adresse
		, query_date:= sfti_makesfti(1848-1,1848,1848,1848+1)
		, target_scale_range := numrange(0,30)
		, ordering_priority_function := '100 * semantic + 5 * temporal  + 0.01 * scale + 0.001 * spatial '
			, semantic_distance_range := numrange(0.5,1)	
			, temporal_distance_range:= sfti_makesfti(1820,1820,2000,2000)
			, scale_distance_range := numrange(0,30) 
			, optional_reference_geometry := NULL-- ST_Buffer(ST_GeomFromText('POINT(652208.7 6861682.4)',2154),5)
			, optional_spatial_distance_range := NULL -- numrange(0,10000)
		) as f
LIMIT 4000 ; 
 --  SELECT 7741 /8610.0

 SELECT count(*)
 FROM prevenu_geocoded
 WHERE ville ilike 'paris'

 SELECT count(*)
 FROM prevenu_raw
, trim(both ' '::text from 
		COALESCE(num_adr, ' '::text) || ' '::text || 
		COALESCE(attribut, ' '::text)|| ' '::text || 
		COALESCE(particule, ' '::text)|| ' '::text || 
		COALESCE(nom_rue, ' '::text)|| ' '::text  ) AS adresse_temp
	, CAST((postal_normalize(adresse_temp))[1] AS text) as adresse
	WHERE adresse is not null AND ville ILIKe 'paris'

 