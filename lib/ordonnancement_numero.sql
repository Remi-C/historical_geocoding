--------------------------------
-- Rémi Cura, 2016
-- projet geohistorical data
-- 
--------------------------------
-- fonction reconnaissant et exploitant la numérotation de rue francaise
-- pour deux numéros donnés 48 bis, 48-A, 48A etc
-- on veut pouvoir les ordonner
-- on passe par une etape de parsing, puis des regles d'ordonnancement
--
-- note : fonctions testées avec succès sur les données open street map ile de france
-- cas d'echec : normalisation : aucun
-- cas d'echec : numerotation2float : robuste aux erreur d'orth, sauf "66is" -> "66I"->"66.09"
--------------------------------
	CREATE SCHEMA IF NOT EXISTS outils_geocodage ; 
	CREATE EXTENSION IF NOT EXISTS pg_trgm  ; 

	
	DROP FUNCTION IF EXISTS outils_geocodage.normaliser_numerotation(numerotation text) ;
	CREATE OR REPLACE FUNCTION outils_geocodage.normaliser_numerotation(numerotation text, OUT numero int, OUT suffixe text)   AS 
	$$
		-- le format accepté en entré est D*%*W*, avec D des chiffres, % des characteres de separation non chiffre non lettre, et W des lettres
	DECLARE
		_r record; 
		_numero text;
		_suffixe text; 
		
	-- on essaye de séparer le numéro du reste
	BEGIN 
		SELECT NULL, NULL INTO numero, suffixe ; 
		SELECT ar[1] AS numero, ar[2] as suffixe INTO _numero,_suffixe FROM  regexp_matches(trim( both ' ' from numerotation), '([\-]{0,1}[0-9]*).*?([a-zA-Z]*)') AS ar ; 
		--RAISE NOTICE '%, %', _numero,_suffixe ; 
		IF _numero <> ''THEN 
			numero := _numero::int ; 
		ELSE 
			numero := NULL ;
		END IF ; 

		IF _suffixe <> ''THEN 
			suffixe := _suffixe ; 
		ELSE 
			suffixe := NULL ; 
		END IF ; 
		RETURN ;
	END;
	$$
	LANGUAGE 'plpgsql' IMMUTABLE STRICT ; 

	--design
	SELECT *
	FROM CAST('-48s' AS text) as numerotation,  regexp_matches(trim( both ' ' from numerotation), '([\-]{0,1}[0-9]*).*?([a-zA-Z]*)') AS ar  ; 
	
	-- test
	SELECT *
	FROM outils_geocodage.normaliser_numerotation('-48s') ;

	


	
	-- creation d'une table de suffixe autorisé et de leur poid relatif, pour l'ordonnancement 
	DROP TABLE IF EXISTS outils_geocodage.ordonnancement_suffixe ; 
	CREATE TABLE IF NOT EXISTS outils_geocodage.ordonnancement_suffixe(
	gid serial  PRIMARY KEY,
	suffixe text,
	ordonnancement float
	);  

	INSERT INTO outils_geocodage.ordonnancement_suffixe(suffixe, ordonnancement) VALUES
		('ANTE',-0.01),
		('A',0.01),('B',0.02),('C',0.03),('D',0.04),('E',0.05),('F',0.06),('G',0.07),('H',0.08),('I',0.09),('J',0.10),('K',0.11)
			,('L',0.12),('M',0.13),('N',0.14),('O',0.15),('P',0.16),('Q',0.17),('R',0.18),('S',0.19) --,('T',0.20)
			,('U',0.21),('V',0.22),('W',0.23),('X',0.24),('Y',0.25),('Z',0.26)
		,('BIS',0.02),('TER',0.03),('QUATER',0.04),('QUINQUIES',0.05),('SEXIES',0.06),('SEPTIES',0.07),('OCTIES',0.08),('NONIES',0.09)
		,('SIXTE',0.06) ; 





	DROP FUNCTION IF EXISTS outils_geocodage.numerotation2float(numerotation text) ;
	CREATE OR REPLACE FUNCTION outils_geocodage.numerotation2float(numerotation text) 
	RETURNS float AS 
	$$
		-- le format accepté en entré est D*%*W*, avec D des chiffres, % des characteres de separation non chiffre non lettre, et W des lettres
	DECLARE
	-- on separe numéro et suffixe,. Pour chaque siffixe, on regarde quel modulateur correspond dans la liste des suffixe, puis on retourne le numéro modifié
		_num int  ; 
		_suff text := NULL;
		_ord float ; 
	BEGIN 
		SELECT numero, suffixe INTO _num, _suff
		FROM  outils_geocodage.normaliser_numerotation(numerotation)
		LIMIT 1 ;

		IF _suff IS NULL AND _num IS NULL OR _num IS NULL THEN 
			RAISE NOTICE  'la numerotation "%" n a pas pu être décomposée en une paire numér+suffixe',numerotation ; 
			RETURN NULL ; 
		END IF;

		IF _suff IS NULL THEN 
		return _num ; 
		END IF;
 
		--on cherche le suffixe le plus approprié
		SELECT ordonnancement INTO _ord
		FROM  outils_geocodage.ordonnancement_suffixe as suf
		ORDER BY similarity(_suff,suf.suffixe) DESC
		LIMIT 1 ; 

		IF _ord IS NULL OR _ord = 0 THEN -- pas de suffixe correspondant
			RETURN _num ; 
		END IF ;

		RETURN _num + _ord ;  
		
	END;
	$$
	LANGUAGE 'plpgsql' IMMUTABLE STRICT ;  

	--test
	SELECT outils_geocodage.numerotation2float('48 ante')  ;

	