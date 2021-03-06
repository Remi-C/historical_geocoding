﻿------------------------
-- Remi Cura, 2016 , Projet Belle Epoque
------------------------

-- thsi extension defines a geohistorical object. 
-- it is generic and can be adapted to specific cases, such as geocoding
-- we design a template database schema  that will be used through the inheritance mechanism 
-- so users can add other historical sources

SET search_path to public ; 
-- DROP EXTENSION IF EXISTS unaccent ;
CREATE EXTENSION IF NOT EXISTS unaccent;

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




DROP FUNCTION IF EXISTS geohistorical_object.json_spatial_precision(   IN ijson json, IN specific_field_name text ); 
CREATE OR REPLACE FUNCTION geohistorical_object.json_spatial_precision(    IN ijson json , IN specific_field_name text)
RETURNS float AS 
	$BODY$
		--@brief : this function takes the json of a geohistorical source / numerical process, and extract the spatial precision
		-- @example : example '{"default": 0.2, "road":2.5, "building":0.9}'::json : 0.9 for building !
		DECLARE       
		BEGIN  
			RETURN COALESCE(ijson ->> quote_ident(specific_field_name), ijson->>'default') ;
		 
		END ; 
	$BODY$ 
LANGUAGE plpgsql  IMMUTABLE STRICT; 


SELECT geohistorical_object.json_spatial_precision(  ex , 'building'::text)
FROM CAST ('{"default": 0.2, "road":2.5, "building":0.9}' AS json) AS ex ; 


	  


DROP FUNCTION IF EXISTS geohistorical_object.enable_disable_geohistorical_object(   schema_name text, table_name regclass, activate_desactivate boolean); 
CREATE OR REPLACE FUNCTION geohistorical_object.enable_disable_geohistorical_object(    schema_name text, table_name regclass, activate_desactivate boolean )
RETURNS text AS 
	$BODY$
		--@brief : this function takes a table name, check if it inherits from geohistorical_object or normalised_name_alias. If activate is true, add foregin key, else remove it 
		DECLARE  
			_isobj record; 
			_isalias record; 
			_isobjb boolean;
			_isaliasb boolean ; 
			_r record; 
			_fk_exists record; 
			_fk_existsb boolean ; 
			_sql text ; 
		BEGIN 
			-- get schema and table name from input
			
			-- check if input table is in the list of tables that inherits from 'geohistorical_object' and/or from 'normalised_name_alias' 
				SELECT children_table INTO _isobj
				FROM  find_all_children_in_inheritance('geohistorical_object.geohistorical_object')
				WHERE children_table = table_name::regclass::text
				LIMIT 1 ;
				SELECT children_table INTO _isalias
				FROM  find_all_children_in_inheritance('geohistorical_object.normalised_name_alias')
				WHERE children_table = table_name::regclass::text
				LIMIT 1 ;

				_isobjb := _isobj IS NOT NULL; 
				_isaliasb := _isalias IS NOT NULL;  

				RAISE NOTICE 'is this table heriting from "geohistorical_object" : % ; Is this table inheriting from "normalised_name_alias" % ' ,_isobjb,_isaliasb ; 

				
			IF _isobjb IS TRUE THEN -- case when we inherit from geohistorical_object.geohistorical_object, we have potentially 2 foreign key to add / delete
-- ALTER TABLE test_normalised_name_alias 
-- ADD CONSTRAINT historical_source_short_name_1 
-- FOREIGN KEY (short_historical_source_name_1) 
-- REFERENCES geohistorical_object.historical_source ( short_name) ;  

					FOR  _r IN SELECT 'historical_source' as stn, 'geohistorical_object' as sn, 'historical_source' as tn, 'short_name' AS cn 
						UNION ALL  SELECT 'numerical_origin_process' as stn, 'geohistorical_object','numerical_origin_process', 'short_name' 
					LOOP
						--for each, check if the foreign key exist, if not , create it
						 SELECT (geohistorical_object.find_foreign_key_between_source_and_target( schema_name::text, table_name::text, _r.stn,_r.sn, _r.tn, _r.cn )).constraint_name INTO _fk_exists; 
						 RAISE NOTICE 'does the foreign key from %(%) to %(%) already exists? %',table_name, _r.stn, _r.tn, _r.cn,_fk_exists IS NOT NULL;

						-- si ça existe, desactiver
						-- si activate est true, tout activer 
						 IF _fk_exists IS NOT NULL THEN -- foreign key, we have to destroy it
							RAISE NOTICE '_fk_exists %',_fk_exists ; 
							-- destroying it
							_sql := format('ALTER TABLE %I.%I DROP CONSTRAINT %I;  '
								,schema_name, table_name, _fk_exists.constraint_name ) ; 

							RAISE NOTICE 'sql : %',_sql ; 
							EXECUTE  _sql ; 
						END IF ; 

						IF activate_desactivate IS TRUE THEN
							_sql := format('ALTER TABLE %I.%I
							ADD CONSTRAINT %s_%s 
							FOREIGN KEY (%I) 
							REFERENCES %I.%I ( %I) ; ',schema_name, table_name, _r.tn, _r.cn , _r.stn, _r.sn, _r.tn, _r.cn ) ;  
							
							RAISE NOTICE 'sql : %',_sql ; 
							EXECUTE  _sql ; 
						END IF ; 
							 
					END LOOP; 
				--checking if the foreign key
			END IF ; -- case of inheriting geohistorical_object.geohistorical_object
				 
			IF _isaliasb IS TRUE THEN -- case when we inherit from geohistorical_object.normalised_name_alias, we have potentially 2 foreign key to add /delete
					
					FOR  _r IN SELECT 'short_historical_source_name_1' as stn, 'geohistorical_object' as sn, 'historical_source' as tn, 'short_name' AS cn , 1 as count
						UNION ALL  SELECT 'short_historical_source_name_2' as stn, 'geohistorical_object','historical_source', 'short_name', 2 as count
					LOOP
						--for each, check if the foreign key exist, if not , create it
						 SELECT (geohistorical_object.find_foreign_key_between_source_and_target( schema_name::text, table_name::text, _r.stn,_r.sn, _r.tn, _r.cn )).constraint_name INTO _fk_exists; 
						 RAISE NOTICE 'does the foreign key from %(%) to %(%) already exists? %',table_name, _r.stn, _r.tn, _r.cn,_fk_exists IS NOT NULL;

						-- si ça existe, desactiver
						-- si activate est true, tout activer 
						 IF _fk_exists IS NOT NULL THEN -- foreign key, we have to destroy it
							RAISE NOTICE '_fk_exists %',_fk_exists ; 
							-- destroying it
							_sql := format('ALTER TABLE %I.%I DROP CONSTRAINT %I;  '
								,schema_name, table_name, _fk_exists.constraint_name ) ; 

							RAISE NOTICE 'sql : %',_sql ; 
							EXECUTE  _sql ; 
						END IF ; 

						IF activate_desactivate IS TRUE THEN
							_sql := format('ALTER TABLE %I.%I
							ADD CONSTRAINT %s_%s_%s 
							FOREIGN KEY (%I) 
							REFERENCES %I.%I ( %I) ; ',schema_name, table_name, _r.tn, _r.cn , _r.count, _r.stn, _r.sn, _r.tn, _r.cn ) ;  
							
							RAISE NOTICE 'sql : %',_sql ; 
							EXECUTE  _sql ; 
						END IF ; 
							 
					END LOOP; 
				--checking if the foreign key
			END IF ; -- case of inheriting geohistorical_object.geohistorical_object


		IF activate_desactivate IS TRUE THEN
			_sql := format('you asked to create foreign key on the table %I.%I regarding inheritance to geohistorical_object/normalised_name_alias, it is done',schema_name::text, table_name::text ); 
		ELSE
			_sql := format('you asked to delete foreign key on the table %I.%I regarding inheritance to geohistorical_object/normalised_name_alias, it is done',schema_name::text, table_name::text ); 
		END IF;  
		RETURN _sql;
		END ; 
	$BODY$
LANGUAGE plpgsql  VOLATILE STRICT; 

-- 	SELECT f.*
-- 	FROM geohistorical_object.enable_disable_geohistorical_object(  'geohistorical_object'::regclass, 'test_geohistorical_object'::regclass, false) As f;
-- 
-- 
-- 	SELECT f.*
-- 	FROM geohistorical_object.enable_disable_geohistorical_object(  'geohistorical_object'::regclass, 'test_normalised_name_alias '::regclass, true) As f;


-- ALTER TABLE  geohistorical_object.test_geohistorical_object_3 DROP CONSTRAINT historical_source_short_name
-- ALTER TABLE geohistorical_object.test_geohistorical_object DROP CONSTRAINT numerical_origin_process_short_name;
 
DROP FUNCTION IF EXISTS geohistorical_object.find_all_children_in_inheritance(   IN parent_table_full_name regclass); 
CREATE OR REPLACE FUNCTION geohistorical_object.find_all_children_in_inheritance(   IN parent_table_full_name regclass)
RETURNS table(children_table text) AS 
	$BODY$
		--@brief : given a parent table, look for all the tables that inherit from it (several level of inheritance allowed)
		DECLARE      
		BEGIN 
		 RETURN QUERY 
			SELECT children::text FROM (
				   WITH RECURSIVE inh AS (
					SELECT i.inhrelid FROM pg_catalog.pg_inherits i WHERE inhparent = parent_table_full_name::regclass
					UNION
					SELECT i.inhrelid FROM inh INNER JOIN pg_catalog.pg_inherits i ON (inh.inhrelid = i.inhparent)
				)
				SELECT pg_namespace.nspname AS father , pg_class.relname  AS children
				    FROM inh 
				      INNER JOIN pg_catalog.pg_class ON (inh.inhrelid = pg_class.oid) 
				      INNER JOIN pg_catalog.pg_namespace ON (pg_class.relnamespace = pg_namespace.oid)
		      ) AS sub;

		RETURN ;
		END ; 
	$BODY$
LANGUAGE plpgsql  IMMUTABLE STRICT; 



DROP FUNCTION IF EXISTS geohistorical_object.find_foreign_key_between_source_and_target(   source_schema text, source_table text, source_column text,
	target_schema text, target_table text, target_column text); 
CREATE OR REPLACE FUNCTION geohistorical_object.find_foreign_key_between_source_and_target(   source_schema text, source_table text, source_column text,
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
FROM geohistorical_object.find_foreign_key_between_source_and_target(  'geohistorical_object', 'test_geohistorical_object', 'historical_source','geohistorical_object', 'historical_source', 'short_name' ) ; 



	DROP FUNCTION IF EXISTS geohistorical_object.clean_text(   it text ); 
		CREATE OR REPLACE FUNCTION geohistorical_object.clean_text(  it text )
		RETURNS text AS 
			$BODY$
				--@brief : this function takes a string and return it cleaned 
				DECLARE      
				BEGIN 
					RETURN 
					regexp_replace( 
						regexp_replace( 
							regexp_replace(
								regexp_replace(  
									lower( --all to small font
										unaccent(it) --removing accent
									)
								, '[^a-zA-Z0-9]+', ' ', 'g') --removing characters that are not letters or digits
							, '[_]+', ' ', 'g') --removing underscore
						, '\s+$', '') --removing things lliek space at  the end
					 ,'^\s+', '') --removing things like space at the beginning
					 ;
				END ; 
			$BODY$
		LANGUAGE plpgsql  IMMUTABLE STRICT; 

		SELECT geohistorical_object.clean_text(  $$  5zer'ezer_ze ze'r $*ùzer ;   $$);
 