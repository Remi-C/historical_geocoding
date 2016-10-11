------------------------
-- Remi Cura, 2016 , Projet Belle Epoque
------------------------

-- thsi extension defines a geohistorical object. 
-- it is generic and can be adapted to specific cases, such as geocoding
-- we design a template database schema  that will be used through the inheritance mechanism 
-- so users can add other historical sources

CREATE SCHEMA IF NOT EXISTS geohistorical_object ; 
SET search_path to geohistorical_object, public; 

CREATE EXTENSION IF NOT EXISTS pgsfti ; 

-- designing exension table layout.
	--defining historical sources
	-- when a user wants to add new data in the geocoding database, first add 
	-- defining a new table with all geohistorical_objects.


---------------------
-- template for sources and origin
---------------------



DROP FUNCTION IF EXISTS geohistorical_object.is_valid_source_json(   IN ijson json ); 
CREATE OR REPLACE FUNCTION geohistorical_object.is_valid_source_json(    IN ijson json )
RETURNS boolean AS 
	$BODY$
		--@brief : this function takes the json of a geohistorical source / origin and check that it contains the minimal value
		-- @example : example of correct json : SELECT '{"default": 0.2, "road":2.5, "building":0.9}'::json
		DECLARE     
			is_valid_1 boolean := FALSE ; 
			def_value float := NULL; 
		BEGIN 
			is_valid_1 :=  ijson -> 'default' IS NOT NULL; 

			IF is_valid_1 = true THEN
				def_value := ijson #>> '{"default"}' ;
				IF def_value IS NOT NULL AND def_value >= 0 THEN
					RETURN true; 
				END IF ; 
			END IF ; 
			
		RETURN FALSE;
		END ; 
	$BODY$
LANGUAGE plpgsql  IMMUTABLE STRICT; 

SELECT geohistorical_object.is_valid_source_json(f1), geohistorical_object.is_valid_source_json(f2) 
FROM CAST ( '{"default": 0.2, "road_axis":2.5, "building":0.9}' AS json )  as f1
	, CAST ( '{ "road_axis":2.5, "building":0.9}' AS json )  as f2 ;

	


DROP TABLE IF EXISTS geohistorical_object.source_object_template CASCADE ; 
CREATE TABLE IF NOT EXISTS geohistorical_object.source_object_template (
 short_name text UNIQUE NOT NULL--this is a short name uniquely describing the source
, full_name text NOT NULL -- this mandatory full name is a more human friendly name, and should be a few words max
, description text NOT NULL -- this mandatory description is the details of the source, and sould be a few sentences at least
, default_fuzzy_date sfti NOT NULL -- this fuzzy date is the defautl one for all the object associated
, default_spatial_precision json NOT NULL CHECK( geohistorical_object.is_valid_source_json(default_spatial_precision) = TRUE) --this json is a dictionnary with a defined structure. Each potential object type is given a spatial precision. The value 'default' is mandatory as a default value for all kind of objects.
); 
------ note of design 
-- primary key and unique are redundant, but necessayr in the inheritance case
-- all fields are mandatory to prevent novice user to break database
-- default for json is 


DROP TABLE IF EXISTS geohistorical_object.historical_source; 
CREATE TABLE IF NOT EXISTS geohistorical_object.historical_source( 
UNIQUE (short_name)
) INHERITS (geohistorical_object.source_object_template)  ;
-- some precisions : 
-- fuzzy date : an historical source is an interpretation of the real world at a given period. The default fuzzy date represent this period.
	-- for instance, a copy (1879) of the original map (printing 1856) where the information was acquired between 1850 and 1854 should have a fuzzy date of 1850-1854.
-- default spatial precision represents the overal spatial precision for this source and this object  
	--for instance, a map representing the position of buildings may suffer from various spatial errors: because of the scale, building may be un precise, manual computing error, topographical error, etc. The default_spatial_precision for this building is the overall spatial error.
	-- i.e. How much would I need to buffer the geometry to be sure (p>0.99) that the real building is contained by this buffered geometry .
	
	


DROP TABLE IF EXISTS geohistorical_object.numerical_origin_process CASCADE; 
CREATE TABLE IF NOT EXISTS geohistorical_object.numerical_origin_process( 
UNIQUE (short_name)
) INHERITS (geohistorical_object.source_object_template)  ;
-- some precisions : 
-- fuzzy date : this table represent the process of transforming a real worl historical source into numeric data.
	-- the date is then the date of this process ! 
	-- for instance, a copy (1879) of the original map (printing 1856) where the information was acquired between 1850 and 1854 should have a fuzzy date of 1850-1854.
-- default spatial precision represents the overal spatial precision for this source and this object  
	--for instance, a map representing the position of buildings may suffer from various spatial errors: because of the scale, building may be un precise, manual computing error, topographical error, etc. The default_spatial_precision for this building is the overall spatial error.
	-- i.e. How much would I need to buffer the geometry to be sure (p>0.99) that the real building is contained by this buffered geometry .


DROP TABLE IF EXISTS geohistorical_object.normalised_name_alias CASCADE; 
CREATE TABLE IF NOT EXISTS normalised_name_alias(
	short_historical_source_name_1 text  REFERENCES geohistorical_object.historical_source(short_name)  -- the relation is always defined for a given historical source
	, normalised_name_1 text NOT NULL -- normalised name of a geohistorical object 
	, short_historical_source_name_2 text  REFERENCES geohistorical_object.historical_source(short_name)
	, normalised_name_2 text NOT NULL -- normalised name alias of a geohistorical object
	, preference_ratio float NOT NULL CHECK ( preference_ratio>0 ), -- name_1 = preference_ratio  * name_2 , in usage value
	UNIQUE (short_historical_source_name_1, normalised_name_1, short_historical_source_name_2, normalised_name_2) -- this constraint ensure that the same equivalence is not defined several times 
	 , check (false) NO INHERIT
); 

 
-- DONT PUT ANYTHING IN THIS  TABLE, USE INHERITANCE (see test section for an example)
DROP TABLE IF EXISTS geohistorical_object.geohistorical_object CASCADE ; 
CREATE TABLE IF NOT EXISTS geohistorical_object.geohistorical_object (
	historical_name text,  -- the complete historical name, including strange characters, mistake of spelling, etc. This should not be used for joining and so, only for historical analysis
	normalised_name text, -- a normalised version of the name , sanitized. This version may be used for joins and so
	geom geometry, -- all geometry should be in the same srid
	specific_fuzzy_date sfti, -- OPTIONNAL : if defined, overrides the defaut fuzzy dates of the historical source
	specific_spatial_precision float, -- OPTIONNAL : if defined, ovverides the defaut spatial precision
	historical_source text REFERENCES geohistorical_object.historical_source ( short_name) NOT NULL, -- link to the historical source, mandatory
	numerical_origin_process text REFERENCES geohistorical_object.numerical_origin_process (  short_name) NOT NULL, -- link to the origin process, mandatory
	 UNIQUE (normalised_name, geom) --adding a constraint to limit duplicates (obvious errors here) 
	 , check (false) NO INHERIT
); 
 
-- @TODO : add a mechanism to ensure geohistorical_object is always empty


-------------------------
-- TESTING ! 
------------------------

-- creating test values :

--geohistorical_object.historical_source ;
SELECT *
FROM geohistorical_object.historical_source ;

TRUNCATE geohistorical_object.historical_source  CASCADE ; 
INSERT INTO geohistorical_object.historical_source VALUES 
	('jacoubet_paris'
	, 'Atlas Général de la Ville, des faubourgs et des monuments de Paris, Simon-Théodore Jacoubet'
	, 'Simon-Théodore Jacoubet, né en 1798 à Toulouse fut architecte employé dès
1823 à la Préfecture de la Seine puis chef du bureau chargé de la réalisation des
plans d’alignements. Mêlé à divers procès liés à ses activités à la préfecture, il fut
révolutionnaire en 1830, 1832 puis 1848, arrêté, interné et condamné à la déportation
en Algérie en 1852, condamné à la mort civile et enfin assigné à résidence à
Montesquieu-Volvestre la même année. Il sera l’auteur du plus grand et plus complet
plan de Paris existant sur la première moitié du XIXe siècle.
La réalisation de son Atlas Général de la Ville, des faubourgs et des monuments
de Paris est une fenêtre ouverte non seulement sur la topographie parisienne préhaussmanienne,
mais aussi sur le fonctionnement des services de voirie de la Seine.
13. En 1851 encore, les plans de percements de la rue de Rivoli entre la rue de la Bibliothèque et la rue
du Louvre seront tracés sur un plan parcellaire très proche de celui de Vasserot 

Suivre la construction de cet atlas permet non seulement d’entrer au coeur de la
machine d’aménagement urbain mise en place en 1800 par Napoléon, mais surtout
de découvrir les rapports qu’entretenaient les employés de la préfecture et les agents
d’affaires dans un objectif commun de spéculations immobilières, ainsi que la corruption
à l’oeuvre dans les services chargés de l’aménagement urbain : percements,
alignements, gestion des carrières, etc. 
2.4.1 Levé et structure du plan
Le travail de Jacoubet s’inscrit volontairement dans la lignée des grands plans
de Paris contruits au XVIIIe siècle 14. Commencé entre 1825 et 1827, l’Atlas Général
s’inspire directement des travaux de Verniquet dont il reprend en partie la
triangulation. Il est important de noter dès maintenant que Jacoubet entreprend
la réalisation de son atlas alors qu’il se trouve employé au Bureau des Plans de la
préfecture de la Seine. C’est grâce à cette position qu’il sera en mesure d’utiliser
les relevés topographiques réalisés par les géomètres de l’administration à partir des
plans de Verniquet, alors utilisé comme plan général pour les travaux de voierie.
Comme nous le verrons plus tard, il a également repris les mesures de triangulation
effectuées par les équipes de Verniquet, ce qui lui permet d’économiser des opérations
de levé topographiques d’envergure 15. L’atlas est réalisé entre 1825 (ou 1827)
et 1836 et il est publié par parties selon la méthode de la souscription. Cette méthode
consiste à financer le travail de gravure, très coûteux, par étapes successives
grâce à la contribution de particuliers qui subventionnent des lots de feuilles d’atlas.
Au total, l’Atlas Général de la ville de Paris comporte 54 feuilles traçant un plan de
Paris au 1/2000e 16. Les feuilles 53 et 54 présentent en outre un plan des principales
opérations de triangulation ayant permi de construire l’atlas.
2.4.2 Contenu du plan
Tout comme l’atlas de Verniquet, Jacoubet crée un plan relativement épuré contenant
principalement le tracé des rues et les plans des bâtiments publics. Toutefois,
l’objectif de l’architecte est de faire de son atlas un outil de travail pour la préfecture
de la Seine, mais aussi pour les propriétaires et entrepreneurs parisiens. Pour cette
raison, il rajoute le tracé des alignements prévus par la préfecture en vertu de la loi
du 16 septembre 1807 (cf. le paragraphe 2.6.1), ainsi que les parcelles cadastrales
numérotées. Enfin, les bâtiments à l’intérieur des boulevard sont dessinés en coupe ;
On peut d’ailleurs remarquer, par une étude fine des planches et de l’espace qu’elles
représentent, que les échelles des bâtiments et des autres thèmes cartographiques
ne sont pas toujours identiques. L’échelle des bâtiments est ainsi régulièrement plus
grande que celle des rues et ilôts. Cela s’explique par le fait que les bâtiments figurés
dans l’atlas proviennent très certainement des levés de l’atlas des 48 quartiers de
14. Notamment ceux de Delagrive, Verniquet, Delisle et Jaillot
15. Paris ayant toutefois évolué depuis 1791, notamment aux alentours des boulevards, Jacoubet complète
le canevas de triangle existantRéutilisant en partie les levés de Verniquet, il est possible qu’il se soit cantonné
à lever en détail les parties périphériques de la ville. En effet, contrairement à Verniquet ou même Vasserot,
Jacoubet est presque seul à réaliser son atlas. Seuls quelques employé de la Seine l’aideront à reporter les
calques -c’est à dire les premières minutes- de l’atlas sur les feuilles de l’atlas.
16. L’échelle idiquée sur le plan est de 1 millimètre pour deux mètres 
Vasserot, différents de ceux de Verniquet. On a ici un exemple de réutilisation de
différentes sources cartographiques générant des erreurs dans la carte ainsi consituée
en patchwork. L’atlas est donc globalement hétérogène. Tout d’abord, les bâtiments
à l’exterieur des boulevards sont dessinés en masse, à l’inverse de paris intra-muros.
Le dessin des parcelles est également très inégal. Dans l’extrême centre de Paris
(autour de la place du Châtelet) et de l’exterieur de la ville, toutes les parcelles sont
représentées et numérotées. Partout ailleurs, les parcelles sont seulement ébauchées
et seuls leur numéro et leur amorce sur la rue est dessinés.
Tous ces éléments contribue à faire de l’atlas de Jacoubet un plan majeur du milieu
du 19e siècle mais dont les hétérogénéités appellent à le considérer avec prudence.
Cet atlas et son auteur sont symptomatiques de la mutation que subit la gestion
urbaine au 19e siècle, entamée entre la Révolution et le Premier Empire et qui s’achèvera
par l’arrivée du préfet Haussmann à la tête de la très centralisée préférecture
de la Seine. Pour cette raison, nous proposons en section 2.6 d’explorer plus en profondeur
le personnage de Jacoubet et la réalisation de son grand atlas, ce qui nous
permet de mettre en évidence cette mutation.'
	, sfti_makesfti(1825, 1827, 1836, 1837)
	,  '{"default": 4, "road_axis":2.5, "building":1, "number":2}'::json 
	)
	
	,('poubelle_municipal_paris'
	, 'atlas municipal de paris sous la direction de M. Poubelle'
	, 'super atlas blabla'
	, sfti_makesfti(1887, 1888, 1888, 1889) 
	,  '{"default": 2, "road_axis":2, "building":1, "number":10}'::json 
	) ; 


----- geohistorical_object.numerical_origin_process
-- numerical_origin_process
	SELECT *
	FROM geohistorical_object.numerical_origin_process ; 

	TRUNCATE geohistorical_object.numerical_origin_process  CASCADE; 
	
	INSERT INTO geohistorical_object.numerical_origin_process VALUES
	('default_human_manual'
		, 'A human manually entered these values'
		, 'this is the default option when a human created the data, and you dont want to create a custom numerical_origin_process. You probably should'
		, sfti_makesfti(1995, 1995, 2016, 2016) 
		, '{"default": 1, "road_axis":3, "building":0.5, "number":1.5}'::json)
	,('default_computer_automatic'
		, 'these values are automatically created by a computer'
		, 'this is the default option when a computer created automatically the data, and you dont want to create a custom numerical_origin_process. You probably should, because the precision will greatly depend on your algorithm'
		, sfti_makesfti(1995, 1995, 2016, 2016) 
		, '{"default": 10, "road_axis":5, "building":5, "number":10}'::json) ;


----- geohistorical_object.geohistorical_object
-- geohistorical_object
-- THIS TABLE SHOULD REMAIN EMPTY ! 
-- instead, create another table and inherit from geohistorical_object


	SELECT *
	FROM geohistorical_object.geohistorical_object ;

	DROP TABLE IF EXISTS test_geohistorical_object CASCADE; 
	CREATE TABLE test_geohistorical_object (
		my_custom_uid serial PRIMARY KEY 
	)
	INHERITS (geohistorical_object.geohistorical_object) ; 
	ALTER TABLE test_geohistorical_object ADD CONSTRAINT historical_source_short_name FOREIGN KEY (historical_source) REFERENCES geohistorical_object.historical_source ( short_name) ;  
	ALTER TABLE test_geohistorical_object ADD CONSTRAINT numerical_origin_process_short_name FOREIGN KEY (numerical_origin_process) REFERENCES geohistorical_object.numerical_origin_process ( short_name) ; 
	

	-- adding indexes  
	CREATE INDEX ON test_geohistorical_object  USING GIST(geom) ;
	CREATE INDEX ON test_geohistorical_object  USING  GIN (normalised_name gin_trgm_ops);


	SELECT *
	FROM test_geohistorical_object  ;

	INSERT INTO test_geohistorical_object VALUES (
	'rue saint étienne à Paris', 'rue saint etienne, Paris',   ST_GeomFromEWKT('SRID=2154;LINESTRING(0 0 , 10 10, 20 10)')	
	, NULL, NULL
	,'jacoubet_paris',  'default_human_manual'  ),
	(
	'r. st-étienne à Paris', 'r. saint etienne, Paris',   ST_GeomFromEWKT('SRID=2154;LINESTRING(1 1 , 11 11, 21 11)')	
	,  sfti_makesfti('08-06-1888'::date,'08-06-1888','01-09-1888','01-10-1888'), 3
	,'poubelle_municipal_paris',  'default_computer_automatic'   ) ; 

	DROP TABLE IF EXISTS test_geohistorical_object_2 CASCADE; 
	CREATE TABLE test_geohistorical_object_2 (
		example_additional_column serial PRIMARY KEY 
	) INHERITS (test_geohistorical_object)  ; 

	DROP TABLE IF EXISTS test_geohistorical_object_3 CASCADE; 
	CREATE TABLE test_geohistorical_object_3 (
		example_additional_column serial PRIMARY KEY 
	) INHERITS (test_geohistorical_object,  geohistorical_object.normalised_name_alias)  ; 

---- geohistorical_object.normalised_name_alias 
-- THIS TABLE SHOULD REMAIN EMPTY ! 
-- instead, create a new table and inherit from it

	SELECT *
	FROM geohistorical_object.normalised_name_alias  ;

	DROP TABLE IF EXISTS test_normalised_name_alias ; 
	CREATE TABLE test_normalised_name_alias (
	my_custom_uid serial PRIMARY KEY -- you can add as amny columns as you want
	)INHERITS (geohistorical_object.normalised_name_alias)  ;
	
	ALTER TABLE test_normalised_name_alias ADD CONSTRAINT historical_source_short_name_1 FOREIGN KEY (short_historical_source_name_1) REFERENCES geohistorical_object.historical_source ( short_name) ;  
	ALTER TABLE test_normalised_name_alias ADD CONSTRAINT historical_source_short_name_2 FOREIGN KEY (short_historical_source_name_2) REFERENCES geohistorical_object.historical_source ( short_name) ; 
	
	TRUNCATE test_normalised_name_alias CASCADE ; 
	SELECT *
	FROM test_normalised_name_alias ;

	INSERT INTO test_normalised_name_alias VALUES 
	('jacoubet_paris', 'rue saint etienne, Paris', 'poubelle_municipal_paris', 'r. saint etienne, Paris', 2)
	, (NULL, 'rue saint etienne', NULL, 'rue Saint-Etienne, Paris', 0.1) ;

	

-- @TODO  : foreign keys are not inherited
/* --need to define a function that will create the foreign keys appropriatly
	2 cases : to distinguish, look for target column name (fixed through inheritance) 
		geohistorical_object --> check if foreign key already exists, add foreign key to historical_source and numerical_origin_process
		normalised_name_alias --> check if foregin key already exists , add foreign keys to historical_source 
*/

SELECT 'geohistorical_object.geohistorical_object'::regclass

SELECT *
FROM   pg_catalog.pg_class c
    JOIN   pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE relname = 'geohistorical_object.geohistorical_object'::regclass::text

DROP FUNCTION IF EXISTS geohistorical_object.enable_disable_geohistorical_object(   IN fulltablename regclass); 
CREATE OR REPLACE FUNCTION geohistorical_object.enable_disable_geohistorical_object(   IN fulltablename regclass)
RETURNS text AS 
	$BODY$
		--@brief : this function takes a table name, check if it inherits from geohistorical_object or normalised_name_alias, then add foreign key if necessary 
		DECLARE  
			_isobj record; 
			_isalias record; 
			_isobjb boolean;
			_isaliasb boolean ; 
			_r record; 
			_fk_exists record; 
			_fk_existsb boolean ; 
		BEGIN 
			-- get schema and table name from input
			
			-- check if input table is in the list of tables that inherits from 'geohistorical_object' and/or from 'normalised_name_alias' 
				SELECT children INTO _isobj
				FROM  find_all_children_in_inheritance('geohistorical_object.geohistorical_object')
				WHERE children = fulltablename
				LIMIT 1 ;
				SELECT children INTO _isaliasj
				FROM  find_all_children_in_inheritance('geohistorical_object.normalised_name_alias')
				WHERE children = fulltablename
				LIMIT 1 ;

				_isobjb := _isobj IS NOT NULL; 
				_isaliasb := _isalias IS NOT NULL;  

				
			IF _isobjb IS TRUE THEN
				-- 2 foregin key to add
					
					FOR  _r IN SELECT 'historical_source' as stn, 'geohistorical_object' as sn, 'historical_source' as tn, 'short_name' AS cn 
						UNION ALL  SELECT 'numerical_origin_process' as stn, 'geohistorical_object','numerical_origin_process', 'short_name'
					LOOP
						--for each, check if the foreign key exist, if not , create it
						 _fk_exists := geohistorical_object.find_foregin_key_between_source_and_target(  'geohistorical_object', 'test_geohistorical_object', _r.stn,_r.sn, _r.tn, _r.cn ) ; 
					END LOOP; 
				--checking if the foreign key
			END IF ; 
				 
			-- check if foreign key already exists
			
			-- add/delete foreign keys.
		 
		RETURN 'the foreign key to geohistorical_object.historical_source and/or  to geohistorical_object.numerical_origin_process were removed';
		END ; 
	$BODY$
LANGUAGE plpgsql  IMMUTABLE STRICT; 



DROP FUNCTION IF EXISTS geohistorical_object.find_all_children_in_inheritance(   IN parent_table_full_name regclass); 
CREATE OR REPLACE FUNCTION geohistorical_object.find_all_children_in_inheritance(   IN parent_table_full_name regclass)
RETURNS table(children_table regclass) AS 
	$BODY$
		--@brief : given a parent table, look for all the tables that inherit from it (several level of inheritance allowed)
		DECLARE      
		BEGIN 
		 RETURN QUERY 
			SELECT children FROM (
		   WITH RECURSIVE inh AS (
			SELECT i.inhrelid FROM pg_catalog.pg_inherits i WHERE inhparent = parent_table_full_name::regclass
			UNION
			SELECT i.inhrelid FROM inh INNER JOIN pg_catalog.pg_inherits i ON (inh.inhrelid = i.inhparent)
		)
		SELECT pg_namespace.nspname AS father , pg_class.relname::regclass AS children
		    FROM inh 
		      INNER JOIN pg_catalog.pg_class ON (inh.inhrelid = pg_class.oid) 
		      INNER JOIN pg_catalog.pg_namespace ON (pg_class.relnamespace = pg_namespace.oid)
		      ) AS sub;

		RETURN ;
		END ; 
	$BODY$
LANGUAGE plpgsql  IMMUTABLE STRICT; 



DROP FUNCTION IF EXISTS geohistorical_object.find_foregin_key_between_source_and_target(   source_schema text, source_table text, source_column text,
	target_schema text, target_table text, target_column text); 
CREATE OR REPLACE FUNCTION geohistorical_object.find_foregin_key_between_source_and_target(   source_schema text, source_table text, source_column text,
	target_schema text, target_table text, target_column text)
RETURNS table(constraint_catalog text, constraint_schema text, constraint_name text) AS 
	$BODY$
		--@brief : given a source and target table and columns, returns the foreign keys if it exists
		DECLARE      
		BEGIN 
			-- conver
			RETURN QUERY 

			SELECT tc.constraint_catalog::text , tc.constraint_schema::text  , tc.constraint_name::text
			FROM information_schema.table_constraints tc 
			INNER JOIN information_schema.constraint_column_usage ccu 
			  USING (constraint_catalog, constraint_schema, constraint_name) 
			INNER JOIN information_schema.key_column_usage kcu 
			  USING (constraint_catalog, constraint_schema, constraint_name) 
			WHERE constraint_type = 'FOREIGN KEY' 
			  AND tc.table_schema = source_schema
			  AND tc.table_name = source_table
			  AND kcu.column_name = source_column
			    AND ccu.table_schema = target_schema
			    AND ccu.table_name = target_table
			    AND ccu.column_name = target_column; 
		RETURN ;
		END ; 
	$BODY$
LANGUAGE plpgsql  IMMUTABLE STRICT; 

SELECT *
FROM geohistorical_object.find_foregin_key_between_source_and_target(  'geohistorical_object', 'test_geohistorical_object', 'historical_source','geohistorical_object', 'historical_source', 'short_name' ) ; 
 