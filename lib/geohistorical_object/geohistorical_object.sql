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
ALTER TABLE geohistorical_object.historical_source ADD PRIMARY KEY (short_name) ; 
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
ALTER TABLE geohistorical_object.numerical_origin_process ADD PRIMARY KEY (short_name) ; 
-- some precisions : 
-- fuzzy date : this table represent the process of transforming a real worl historical source into numeric data.
	-- the date is then the date of this process ! 
	-- for instance, a copy (1879) of the original map (printing 1856) where the information was acquired between 1850 and 1854 should have a fuzzy date of 1850-1854.
-- default spatial precision represents the overal spatial precision for this source and this object  
	--for instance, a map representing the position of buildings may suffer from various spatial errors: because of the scale, building may be un precise, manual computing error, topographical error, etc. The default_spatial_precision for this building is the overall spatial error.
	-- i.e. How much would I need to buffer the geometry to be sure (p>0.99) that the real building is contained by this buffered geometry .


-- DONT PUT ANYTHING IN THIS  TABLE, USE INHERITANCE (see test section for an example)
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
  


 