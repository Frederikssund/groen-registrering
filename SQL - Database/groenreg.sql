---
--- SET
---

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- CREATE SCHEMA
--

CREATE SCHEMA greg;

COMMENT ON SCHEMA greg IS 'Skema indeholdende grund- og rådata.';


CREATE SCHEMA greg_history;

COMMENT ON SCHEMA greg_history IS 'Skema indeholdende historikdata.';

--
-- CREATE EXTENSION
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;

COMMENT ON EXTENSION postgis IS 'PostGIS geometry, geography, and raster spatial types and functions';


CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';

--
-- Search path
--

SET search_path = greg, pg_catalog;

--
-- CREATE FUNCTION
--

CREATE FUNCTION greg.f_aendring_log(integer)
	RETURNS TABLE(
		objekt_id uuid,
		versions_id uuid,
		handling text,
		dato timestamp without time zone,
		element text,
		arbejdssted text,
		objekt_type text,
		note text
	)
	LANGUAGE sql
	AS $$

WITH

tgp AS (
		SELECT -- Select all features that has been inserted, but not updated from the main table (Points)
			a.objekt_id,
			a.versions_id,
			'Tilføjet'::text AS handling,
			a.systid_fra::timestamp(0) AS dato,
			CASE
				WHEN a.underelement_kode NOT IN(SELECT underelement_kode FROM greg.d_basis_underelementer)
				THEN a.underelement_kode
				ELSE a.underelement_kode || ' ' || b.underelement_tekst
			END AS element,
			CASE
				WHEN a.arbejdssted NOT IN(SELECT pg_distrikt_nr FROM greg.t_greg_omraader)
				THEN a.arbejdssted::text
				ELSE a.arbejdssted || ' ' || c.pg_distrikt_tekst
			END AS arbejdssted,
			'P'::text AS objekt_type,
			''::text AS note
		FROM greg.t_greg_punkter a
		LEFT JOIN greg.d_basis_underelementer b ON a.underelement_kode = b.underelement_kode
		LEFT JOIN greg.t_greg_omraader c ON a.arbejdssted = c.pg_distrikt_nr
		WHERE EXTRACT (YEAR FROM a.systid_fra) = $1 AND a.systid_fra = a.oprettet
	),

tghp AS (
		SELECT -- Select all features that represent update and delete operations from the history table (Points)
			a.objekt_id,
			a.versions_id,
			CASE
				WHEN a.systid_til = (SELECT MAX(systid_til) FROM greg_history.t_greg_punkter d WHERE a.objekt_id = d.objekt_id) AND a.objekt_id NOT IN(SELECT objekt_id FROM greg.t_greg_punkter)
				THEN 'Slettet'::text
				ELSE 'Ændring'::text
			END AS handling,
			a.systid_til::timestamp(0) AS dato,
			CASE
				WHEN a.underelement_kode NOT IN(SELECT underelement_kode FROM greg.d_basis_underelementer)
				THEN a.underelement_kode
				ELSE a.underelement_kode || ' ' || b.underelement_tekst
			END AS element,
			CASE
				WHEN a.arbejdssted NOT IN(SELECT pg_distrikt_nr FROM greg.t_greg_omraader)
				THEN a.arbejdssted::text
				ELSE a.arbejdssted || ' ' || c.pg_distrikt_tekst
			END AS arbejdssted,
			'P'::text AS objekt_type,
			CASE
				WHEN EXTRACT (YEAR FROM a.oprettet) = $1
				THEN 'Tilføjet '::text || to_char(a.oprettet::date, 'dd-mm-yyyy')
				ELSE ''::text
			END AS note
		FROM greg_history.t_greg_punkter a
		LEFT JOIN greg.d_basis_underelementer b ON a.underelement_kode = b.underelement_kode
		LEFT JOIN greg.t_greg_omraader c ON a.arbejdssted = c.pg_distrikt_nr
		WHERE EXTRACT (YEAR FROM a.systid_til) = $1
	),

tghpo AS (
		SELECT -- Select all features that represent insert opreations from the history table (Points)
			a.objekt_id,
			a.versions_id,
			'Tilføjet'::text AS handling,
			a.systid_fra::timestamp(0) AS dato,
			CASE
				WHEN a.underelement_kode NOT IN(SELECT underelement_kode FROM greg.d_basis_underelementer)
				THEN a.underelement_kode
				ELSE a.underelement_kode || ' ' || b.underelement_tekst
			END AS element,
			CASE
				WHEN a.arbejdssted NOT IN(SELECT pg_distrikt_nr FROM greg.t_greg_omraader)
				THEN a.arbejdssted::text
				ELSE a.arbejdssted || ' ' || c.pg_distrikt_tekst
			END AS arbejdssted,
			'P'::text AS objekt_type,
			''::text AS note
		FROM greg_history.t_greg_punkter a
		LEFT JOIN greg.d_basis_underelementer b ON a.underelement_kode = b.underelement_kode
		LEFT JOIN greg.t_greg_omraader c ON a.arbejdssted = c.pg_distrikt_nr
		WHERE EXTRACT (YEAR FROM a.systid_fra) = $1 AND a.systid_fra = a.oprettet
	),

tgl AS (
		SELECT -- Select all features that has been inserted, but not updated from the main table (Lines)
			a.objekt_id,
			a.versions_id,
			'Tilføjet'::text AS handling,
			a.systid_fra::timestamp(0) AS dato,
			CASE
				WHEN a.underelement_kode NOT IN(SELECT underelement_kode FROM greg.d_basis_underelementer)
				THEN a.underelement_kode
				ELSE a.underelement_kode || ' ' || b.underelement_tekst
			END AS element,
			CASE
				WHEN a.arbejdssted NOT IN(SELECT pg_distrikt_nr FROM greg.t_greg_omraader)
				THEN a.arbejdssted::text
				ELSE a.arbejdssted || ' ' || c.pg_distrikt_tekst
			END AS arbejdssted,
			'L'::text AS objekt_type,
			''::text AS note
		FROM greg.t_greg_linier a
		LEFT JOIN greg.d_basis_underelementer b ON a.underelement_kode = b.underelement_kode
		LEFT JOIN greg.t_greg_omraader c ON a.arbejdssted = c.pg_distrikt_nr
		WHERE EXTRACT (YEAR FROM a.systid_fra) = $1 AND a.systid_fra = a.oprettet
	),

tghl AS (
		SELECT -- Select all features that represent update and delete operations from the history table (Lines)
			a.objekt_id,
			a.versions_id,
			CASE
				WHEN a.systid_til = (SELECT MAX(systid_til) FROM greg_history.t_greg_linier d WHERE a.objekt_id = d.objekt_id) AND a.objekt_id NOT IN(SELECT objekt_id FROM greg.t_greg_linier)
				THEN 'Slettet'::text
				ELSE 'Ændring'::text
			END AS handling,
			a.systid_til::timestamp(0) AS dato,
			CASE
				WHEN a.underelement_kode NOT IN(SELECT underelement_kode FROM greg.d_basis_underelementer)
				THEN a.underelement_kode
				ELSE a.underelement_kode || ' ' || b.underelement_tekst
			END AS element,
			CASE
				WHEN a.arbejdssted NOT IN(SELECT pg_distrikt_nr FROM greg.t_greg_omraader)
				THEN a.arbejdssted::text
				ELSE a.arbejdssted || ' ' || c.pg_distrikt_tekst
			END AS arbejdssted,
			'L'::text AS objekt_type,
			CASE
				WHEN EXTRACT (YEAR FROM a.oprettet) = $1
				THEN 'Tilføjet '::text || to_char(a.oprettet::date, 'dd-mm-yyyy')
				ELSE ''::text
			END AS note
		FROM greg_history.t_greg_linier a
		LEFT JOIN greg.d_basis_underelementer b ON a.underelement_kode = b.underelement_kode
		LEFT JOIN greg.t_greg_omraader c ON a.arbejdssted = c.pg_distrikt_nr
		WHERE EXTRACT (YEAR FROM a.systid_til) = $1
	),

tghlo AS (
		SELECT -- Select all features that represent insert opreations from the history table (Lines)
			a.objekt_id,
			a.versions_id,
			'Tilføjet'::text AS handling,
			a.systid_fra::timestamp(0) AS dato,
			CASE
				WHEN a.underelement_kode NOT IN(SELECT underelement_kode FROM greg.d_basis_underelementer)
				THEN a.underelement_kode
				ELSE a.underelement_kode || ' ' || b.underelement_tekst
			END AS element,
			CASE
				WHEN a.arbejdssted NOT IN(SELECT pg_distrikt_nr FROM greg.t_greg_omraader)
				THEN a.arbejdssted::text
				ELSE a.arbejdssted || ' ' || c.pg_distrikt_tekst
			END AS arbejdssted,
			'L'::text AS objekt_type,
			''::text AS note
		FROM greg_history.t_greg_linier a
		LEFT JOIN greg.d_basis_underelementer b ON a.underelement_kode = b.underelement_kode
		LEFT JOIN greg.t_greg_omraader c ON a.arbejdssted = c.pg_distrikt_nr
		WHERE EXTRACT (YEAR FROM a.systid_fra) = $1 AND a.systid_fra = a.oprettet
	),

tgf AS (
		SELECT -- Select all features that has been inserted, but not updated from the main table (Polygons)
			a.objekt_id,
			a.versions_id,
			'Tilføjet'::text AS handling,
			a.systid_fra::timestamp(0) AS dato,
			CASE
				WHEN a.underelement_kode NOT IN(SELECT underelement_kode FROM greg.d_basis_underelementer)
				THEN a.underelement_kode
				ELSE a.underelement_kode || ' ' || b.underelement_tekst
			END AS element,
			CASE
				WHEN a.arbejdssted NOT IN(SELECT pg_distrikt_nr FROM greg.t_greg_omraader)
				THEN a.arbejdssted::text
				ELSE a.arbejdssted || ' ' || c.pg_distrikt_tekst
			END AS arbejdssted,
			'F'::text AS objekt_type,
			''::text AS note
		FROM greg.t_greg_flader a
		LEFT JOIN greg.d_basis_underelementer b ON a.underelement_kode = b.underelement_kode
		LEFT JOIN greg.t_greg_omraader c ON a.arbejdssted = c.pg_distrikt_nr
		WHERE EXTRACT (YEAR FROM a.systid_fra) = $1 AND a.systid_fra = a.oprettet
	),

tghf AS (
		SELECT -- Select all features that represent update and delete operations from the history table (Polygons)
			a.objekt_id,
			a.versions_id,
			CASE
				WHEN a.systid_til = (SELECT MAX(systid_til) FROM greg_history.t_greg_flader d WHERE a.objekt_id = d.objekt_id) AND a.objekt_id NOT IN(SELECT objekt_id FROM greg.t_greg_flader)
				THEN 'Slettet'::text
				ELSE 'Ændring'::text
			END AS handling,
			a.systid_til::timestamp(0) AS dato,
			CASE
				WHEN a.underelement_kode NOT IN(SELECT underelement_kode FROM greg.d_basis_underelementer)
				THEN a.underelement_kode
				ELSE a.underelement_kode || ' ' || b.underelement_tekst
			END AS element,
			CASE
				WHEN a.arbejdssted NOT IN(SELECT pg_distrikt_nr FROM greg.t_greg_omraader)
				THEN a.arbejdssted::text
				ELSE a.arbejdssted || ' ' || c.pg_distrikt_tekst
			END AS arbejdssted,
			'F'::text AS objekt_type,
			CASE
				WHEN EXTRACT (YEAR FROM a.oprettet) = $1
				THEN 'Tilføjet '::text || to_char(a.oprettet::date, 'dd-mm-yyyy')
				ELSE ''::text
			END AS note
		FROM greg_history.t_greg_flader a
		LEFT JOIN greg.d_basis_underelementer b ON a.underelement_kode = b.underelement_kode
		LEFT JOIN greg.t_greg_omraader c ON a.arbejdssted = c.pg_distrikt_nr
		WHERE EXTRACT (YEAR FROM a.systid_til) = $1
	),

tghfo AS (
		SELECT -- Select all features that represent insert opreations from the history table (Polygons)
			a.objekt_id,
			a.versions_id,
			'Tilføjet'::text AS handling,
			a.systid_fra::timestamp(0) AS dato,
			CASE
				WHEN a.underelement_kode NOT IN(SELECT underelement_kode FROM greg.d_basis_underelementer)
				THEN a.underelement_kode
				ELSE a.underelement_kode || ' ' || b.underelement_tekst
			END AS element,
			CASE
				WHEN a.arbejdssted NOT IN(SELECT pg_distrikt_nr FROM greg.t_greg_omraader)
				THEN a.arbejdssted::text
				ELSE a.arbejdssted || ' ' || c.pg_distrikt_tekst
			END AS arbejdssted,
			'F'::text AS objekt_type,
			''::text AS note
		FROM greg_history.t_greg_flader a
		LEFT JOIN greg.d_basis_underelementer b ON a.underelement_kode = b.underelement_kode
		LEFT JOIN greg.t_greg_omraader c ON a.arbejdssted = c.pg_distrikt_nr
		WHERE EXTRACT (YEAR FROM a.systid_fra) = $1 AND a.systid_fra = a.oprettet
	)

SELECT * FROM tgp
UNION
SELECT * FROM tghp
UNION
SELECT * FROM tghpo
UNION
SELECT * FROM tgl
UNION
SELECT * FROM tghl
UNION
SELECT * FROM tghlo
UNION
SELECT * FROM tgf
UNION
SELECT * FROM tghf
UNION
SELECT * FROM tghfo

ORDER BY dato DESC;

$$;

COMMENT ON FUNCTION greg.f_aendring_log(integer) IS 'Ændringslog, som registrerer alle handlinger indenfor et givent år.';



CREATE FUNCTION greg.f_dato_flader(integer, integer, integer)
	RETURNS TABLE(
		versions_id uuid,
		objekt_id uuid,
		systid_fra timestamp with time zone,
		systid_til timestamp with time zone,
		oprettet timestamp with time zone,
		cvr_kode integer,
		bruger_id character varying,
		oprindkode integer,
		statuskode integer,
		off_kode integer,
		underelement_kode character varying,
		arbejdssted integer,
		udfoerer_entrep character varying,
		kommunal_kontakt character varying,
		anlaegsaar date,
		klip_sider integer,
		hoejde numeric,
		tilstand_kode integer,
		litra character varying,
		note character varying,
		vejkode integer,
		link character varying,
		geometri public.geometry('POLYGON', 25832)
	)
	LANGUAGE sql
	AS $$

WITH

tgf AS (
		SELECT -- Select everything present at the end of the given day from the main table
			*
		FROM greg.t_greg_flader
		WHERE systid_fra::timestamp(0) <= ($3 || '-' || $2 || '-' || $1 || ' 23:59:00')::timestamp(0)
	),

tghf AS (
		SELECT -- Select everything present at the end of the given day from the history table
			*
		FROM greg_history.t_greg_flader
		WHERE 	systid_fra::timestamp(0) <= ($3 || '-' || $2 || '-' || $1 || ' 23:59:00')::timestamp(0) AND
				systid_til::timestamp(0) >  ($3 || '-' || $2 || '-' || $1 || ' 23:59:00')::timestamp(0)
	)

SELECT * FROM tgf
UNION
SELECT * FROM tghf;

$$;

COMMENT ON FUNCTION greg.f_dato_flader(integer, integer, integer) IS 'Simulering af registreringen på en bestemt dato. Format: dd-MM-yyyy.';



CREATE FUNCTION greg.f_dato_linier(integer, integer, integer)
	RETURNS TABLE(
		versions_id uuid,
		objekt_id uuid,
		systid_fra timestamp with time zone,
		systid_til timestamp with time zone,
		oprettet timestamp with time zone,
		cvr_kode integer,
		bruger_id character varying,
		oprindkode integer,
		statuskode integer,
		off_kode integer,
		underelement_kode character varying,
		arbejdssted integer,
		udfoerer_entrep character varying,
		kommunal_kontakt character varying,
		anlaegsaar date,
		hoejde numeric,
		bredde numeric,
		tilstand_kode integer,
		litra character varying,
		note character varying,
		vejkode integer,
		link character varying,
		geometri public.geometry('LINESTRING', 25832)
	)
	LANGUAGE sql
	AS $$

WITH

tgl AS (
		SELECT -- Select everything present at the end of the given day from the main table
			*
		FROM greg.t_greg_linier
		WHERE systid_fra::timestamp(0) <= ($3 || '-' || $2 || '-' || $1 || ' 23:59:00')::timestamp(0)
	),

tghl AS (
		SELECT -- Select everything present at the end of the given day from the history table
			*
		FROM greg_history.t_greg_linier
		WHERE	systid_fra::timestamp(0) <= ($3 || '-' || $2 || '-' || $1 || ' 23:59:00')::timestamp(0) AND
				systid_til::timestamp(0) >  ($3 || '-' || $2 || '-' || $1 || ' 23:59:00')::timestamp(0)
	)

SELECT * FROM tgl
UNION
SELECT * FROM tghl;

$$;

COMMENT ON FUNCTION greg.f_dato_linier(integer, integer, integer) IS 'Simulering af registreringen på en bestemt dato. Format: dd-MM-yyyy.';



CREATE FUNCTION greg.f_dato_punkter(integer, integer, integer)
	RETURNS TABLE(
		versions_id uuid,
		objekt_id uuid,
		systid_fra timestamp with time zone,
		systid_til timestamp with time zone,
		oprettet timestamp with time zone,
		cvr_kode integer,
		bruger_id character varying,
		oprindkode integer,
		statuskode integer,
		off_kode integer,
		underelement_kode character varying,
		arbejdssted integer,
		udfoerer_entrep character varying,
		kommunal_kontakt character varying,
		anlaegsaar date,
		diameter numeric,
		hoejde numeric,
		tilstand_kode integer,
		litra character varying,
		note character varying,
		vejkode integer,
		slaegt character varying,
		art character varying,
		link character varying,
		geometri public.geometry('POINT', 25832)
	)
	LANGUAGE sql
	AS $$

WITH

tgp AS (
		SELECT -- Select everything present at the end of the given day from the main table
			*
		FROM greg.t_greg_punkter
		WHERE systid_fra::timestamp(0) <= ($3 || '-' || $2 || '-' || $1 || ' 23:59:00')::timestamp(0)
	),

tghp AS (
		SELECT -- Select everything present at the end of the given day from the history table
			*
		FROM greg_history.t_greg_punkter
		WHERE	systid_fra::timestamp(0) <= ($3 || '-' || $2 || '-' || $1 || ' 23:59:00')::timestamp(0) AND
				systid_til::timestamp(0) >  ($3 || '-' || $2 || '-' || $1 || ' 23:59:00')::timestamp(0)
	)

SELECT * FROM tgp
UNION
SELECT * FROM tghp;

$$;

COMMENT ON FUNCTION greg.f_dato_punkter(integer, integer, integer) IS 'Simulering af registreringen på en bestemt dato. Format: dd-MM-yyyy.';



CREATE FUNCTION greg.f_tot_flader(integer)
	RETURNS TABLE(
		objekt_id uuid,
		handling text,
		dato date,
		element text,
		arbejdssted text,
		geometri public.geometry('POLYGON', 25832)
	)
	LANGUAGE sql
	AS $$

WITH

tgf AS (
		SELECT -- Select all inserts and updates in the main table within a specific number of days
			a.objekt_id,
			CASE
				WHEN a.systid_fra  = a.oprettet
				THEN 'Tilføjet'
				WHEN a.oprettet <> a.systid_fra AND current_date - a.oprettet::date < $1
				THEN 'Tilføjet og ændret'
				ELSE 'Ændret'
			END AS handling,
			a.systid_fra::date AS dato,
			a.underelement_kode || ' ' || b.underelement_tekst AS element,
			a.arbejdssted || ' ' || c.pg_distrikt_tekst AS arbejdssted,
			a.geometri
		FROM greg.t_greg_flader a
		LEFT JOIN greg.d_basis_underelementer b ON a.underelement_kode = b.underelement_kode
		LEFT JOIN greg.t_greg_omraader c ON a.arbejdssted = c.pg_distrikt_nr
		WHERE current_date - a.systid_fra::date < $1
	),

tghf AS (
		SELECT DISTINCT ON(a.objekt_id) -- Select all delete operations from the history table within a specific number of days
			a.objekt_id,
			'Slettet'::text AS handling,
			a.systid_til::date AS dato,
			a.underelement_kode || ' ' || b.underelement_tekst AS element,
			a.arbejdssted || ' ' || c.pg_distrikt_tekst AS arbejdssted,
			a.geometri
		FROM greg_history.t_greg_flader a
		LEFT JOIN greg.d_basis_underelementer b ON a.underelement_kode = b.underelement_kode
		LEFT JOIN greg.t_greg_omraader c ON a.arbejdssted = c.pg_distrikt_nr
		WHERE current_date - a.systid_til::date < $1 AND a.objekt_id NOT IN(SELECT objekt_id FROM tgf)

		ORDER BY a.objekt_id ASC, a.systid_til DESC
	)

SELECT * FROM tgf
UNION
SELECT * FROM tghf;

$$;

COMMENT ON FUNCTION greg.f_tot_flader(integer) IS 'Ændringsoversigt med tilhørende geometri. Defineres inden for x antal dage.';



CREATE FUNCTION greg.f_tot_linier(integer)
	RETURNS TABLE(
		objekt_id uuid,
		handling text,
		dato date,
		element text,
		arbejdssted text,
		geometri public.geometry('LINESTRING', 25832)
	)
	LANGUAGE sql
	AS $$

WITH

tgl AS (
		SELECT -- Select all inserts and updates in the main table within a specific number of days
			a.objekt_id,
			CASE
				WHEN a.systid_fra  = a.oprettet
				THEN 'Tilføjet'
				WHEN a.oprettet <> a.systid_fra AND current_date - a.oprettet::date < $1
				THEN 'Tilføjet og ændret'
				ELSE 'Ændret'
			END AS handling,
			a.systid_fra::date AS dato,
			a.underelement_kode || ' ' || b.underelement_tekst AS element,
			a.arbejdssted || ' ' || c.pg_distrikt_tekst AS arbejdssted,
			a.geometri
		FROM greg.t_greg_linier a
		LEFT JOIN greg.d_basis_underelementer b ON a.underelement_kode = b.underelement_kode
		LEFT JOIN greg.t_greg_omraader c ON a.arbejdssted = c.pg_distrikt_nr
		WHERE current_date - a.systid_fra::date < $1
	),

tghl AS (
		SELECT DISTINCT ON(a.objekt_id) -- Select all delete operations from the history table within a specific number of days
			a.objekt_id,
			'Slettet'::text AS handling,
			a.systid_til::date AS dato,
			a.underelement_kode || ' ' || b.underelement_tekst AS element,
			a.arbejdssted || ' ' || c.pg_distrikt_tekst AS arbejdssted,
			a.geometri
		FROM greg_history.t_greg_linier a
		LEFT JOIN greg.d_basis_underelementer b ON a.underelement_kode = b.underelement_kode
		LEFT JOIN greg.t_greg_omraader c ON a.arbejdssted = c.pg_distrikt_nr
		WHERE current_date - a.systid_til::date < $1 AND a.objekt_id NOT IN(SELECT objekt_id FROM tgl)

		ORDER BY a.objekt_id ASC, a.systid_til DESC
	)

SELECT * FROM tgl
UNION
SELECT * FROM tghl;

$$;

COMMENT ON FUNCTION greg.f_tot_linier(integer) IS 'Ændringsoversigt med tilhørende geometri. Defineres inden for x antal dage.';



CREATE FUNCTION greg.f_tot_punkter(integer)
	RETURNS TABLE(
		objekt_id uuid,
		handling text,
		dato date,
		element text,
		arbejdssted text,
		geometri public.geometry('POINT', 25832)
	)
	LANGUAGE sql
	AS $$

WITH

tgp AS (
		SELECT -- Select all inserts and updates in the main table within a specific number of days
			a.objekt_id,
			CASE
				WHEN a.systid_fra  = a.oprettet
				THEN 'Tilføjet'
				WHEN a.oprettet <> a.systid_fra AND current_date - a.oprettet::date < $1
				THEN 'Tilføjet og ændret'
				ELSE 'Ændret'
			END AS handling,
			a.systid_fra::date AS dato,
			a.underelement_kode || ' ' || b.underelement_tekst AS element,
			a.arbejdssted || ' ' || c.pg_distrikt_tekst AS arbejdssted,
			a.geometri
		FROM greg.t_greg_punkter a
		LEFT JOIN greg.d_basis_underelementer b ON a.underelement_kode = b.underelement_kode
		LEFT JOIN greg.t_greg_omraader c ON a.arbejdssted = c.pg_distrikt_nr
		WHERE current_date - a.systid_fra::date < $1
	),

tghp AS (
		SELECT DISTINCT ON (a.objekt_id)  -- Select all delete operations from the history table within a specific number of days
			a.objekt_id,
			'Slettet'::text AS handling,
			a.systid_til::date AS dato,
			a.underelement_kode || ' ' || b.underelement_tekst AS element,
			a.arbejdssted || ' ' || c.pg_distrikt_tekst AS arbejdssted,
			a.geometri
		FROM greg_history.t_greg_punkter a
		LEFT JOIN greg.d_basis_underelementer b ON a.underelement_kode = b.underelement_kode
		LEFT JOIN greg.t_greg_omraader c ON a.arbejdssted = c.pg_distrikt_nr
		WHERE current_date - a.systid_til::date < $1 AND a.objekt_id NOT IN(SELECT objekt_id FROM tgp)

		ORDER BY a.objekt_id ASC, a.systid_til DESC
	)

SELECT * FROM tgp
UNION
SELECT * FROM tghp;

$$;

COMMENT ON FUNCTION greg.f_tot_punkter(integer) IS 'Ændringsoversigt med tilhørende geometri. Defineres inden for x antal dage.';

--
-- CREATE (TRIGGER) FUNCTIONS
--

CREATE FUNCTION greg.t_greg_delomraader_trg() RETURNS trigger
	LANGUAGE plpgsql
	AS $$

	BEGIN

		IF (TG_OP = 'UPDATE') THEN

			NEW.objekt_id = OLD.objekt_id; -- Overskriver en evt. ændring
			NEW.geometri = public.ST_Multi(NEW.geometri);

			RETURN NEW;

		ELSIF (TG_OP = 'INSERT') THEN

			NEW.objekt_id = public.uuid_generate_v1();
			NEW.bruger_id = COALESCE(NEW.bruger_id, current_user); -- If NULL from client make one ourself
			NEW.geometri = public.ST_Multi(NEW.geometri);

			RETURN NEW;

		END IF;
	END;

$$;

COMMENT ON FUNCTION greg.t_greg_delomraader_trg() IS 'Indsætter UUID, retter geometri til ST_Multi og retter bruger_id, hvis ikke angivet.';



CREATE FUNCTION greg.t_greg_flader_trg() RETURNS trigger
	LANGUAGE plpgsql
	AS $$

	BEGIN

		IF (TG_OP = 'DELETE') THEN

			-- Old version into greg_history
			OLD.systid_til = current_timestamp;
			INSERT INTO greg_history.t_greg_flader VALUES (OLD.*);

			RETURN OLD;

		ELSE

			-- Initialize
			NEW.versions_id = public.uuid_generate_v1();
			NEW.systid_fra = current_timestamp;
			NEW.systid_til = NULL;

			IF (TG_OP = 'UPDATE') THEN

				-- Geometri-kontrol
				IF public.ST_Equals(NEW.geometri, OLD.geometri) IS FALSE THEN -- Kun hvis man ændrer på geometrien, tages der stilling
					IF EXISTS (SELECT '1' FROM greg.t_greg_flader WHERE public.ST_Contains(geometri, NEW.geometri) IS TRUE AND versions_id <> OLD.versions_id) THEN
						RAISE EXCEPTION 'Geometrien befinder sig i en anden geometri';
					END IF;
					IF EXISTS (SELECT '1' FROM greg.t_greg_flader WHERE (public.ST_Overlaps(NEW.geometri, geometri) IS TRUE OR public.ST_Within(geometri, NEW.geometri) IS TRUE) AND versions_id <> OLD.versions_id) THEN
						NEW.geometri = public.ST_Multi(public.ST_CollectionExtract(public.ST_Difference(NEW.geometri, (SELECT public.ST_Union(geometri) FROM greg.t_greg_flader WHERE (public.ST_Overlaps(NEW.geometri, geometri) IS TRUE OR public.ST_Within(geometri, NEW.geometri) IS TRUE) AND versions_id <> OLD.versions_id)), 3));
					END IF;
				ELSE
					NEW.geometri = public.ST_Multi(NEW.geometri);
				END IF;

				NEW.objekt_id = OLD.objekt_id; -- Overskriver en evt. ændring
				NEW.oprettet = OLD.oprettet; -- Overskriver en evt. ændring

				-- Old version into greg_history
				OLD.systid_til = NEW.systid_fra;
				INSERT INTO greg_history.t_greg_flader VALUES (OLD.*);

				RETURN NEW;

			ELSIF (TG_OP = 'INSERT') THEN

				-- Geometri-kontrol
				IF EXISTS (SELECT '1' FROM greg.t_greg_flader WHERE public.ST_Contains(geometri, NEW.geometri) IS TRUE) THEN
					RAISE EXCEPTION 'Geometrien befinder sig i en anden geometri';
				END IF;
				IF EXISTS (SELECT '1' FROM greg.t_greg_flader WHERE public.ST_Overlaps(NEW.geometri, geometri) IS TRUE OR public.ST_Within(geometri, NEW.geometri) IS TRUE) THEN
					NEW.geometri = public.ST_Multi(public.ST_CollectionExtract(public.ST_Difference(NEW.geometri, (SELECT public.ST_Union(geometri) FROM greg.t_greg_flader WHERE public.ST_Overlaps(NEW.geometri, geometri) IS TRUE OR public.ST_Within(geometri, NEW.geometri) IS TRUE)), 3));
				ELSE
					NEW.geometri = public.ST_Multi(NEW.geometri);
				END IF;

				NEW.objekt_id = NEW.versions_id;
				NEW.oprettet = NEW.systid_fra;

				-- Set DEFAULT values (Updateable views)
				NEW.cvr_kode = COALESCE(NEW.cvr_kode, 29189129);
				NEW.bruger_id = COALESCE(NEW.bruger_id, current_user);
				NEW.oprindkode = COALESCE(NEW.oprindkode, 0);
				NEW.statuskode = COALESCE(NEW.statuskode, 0);
				NEW.off_kode = COALESCE(NEW.off_kode, 1);
				NEW.klip_sider = COALESCE(NEW.klip_sider, 0);
				NEW.hoejde = COALESCE(NEW.hoejde, 0.00);
				NEW.tilstand_kode = COALESCE(NEW.tilstand_kode,9);

				RETURN NEW;

			END IF;
		END IF;
	END;

$$;

COMMENT ON FUNCTION greg.t_greg_flader_trg() IS 'Indsætter UUIDs, timestamps, samt default values, hvis ikke angivet, retter geometri til ST_Multi og indeholder 2 geometritjeks:
1) Geometrier må ikke overlappe eksisterende geometrier - tilskæres automatisk,
2) Geometrier må ikke befinde sig inde i andre geometrier.

Opdateres eller slettes geometrier, bliver de kopieret til en historiktabel.';



CREATE FUNCTION greg.t_greg_linier_trg() RETURNS trigger
	LANGUAGE plpgsql
	AS $$

	BEGIN

		IF (TG_OP = 'DELETE') THEN

			-- Old version into greg_history
			OLD.systid_til = current_timestamp;
			INSERT INTO greg_history.t_greg_linier VALUES (OLD.*);

			RETURN OLD;

		ELSE

			-- Initialize
			NEW.versions_id = public.uuid_generate_v1();
			NEW.systid_fra = current_timestamp;
			NEW.systid_til = NULL;
			NEW.geometri = public.ST_Multi(NEW.geometri);

			IF (TG_OP = 'UPDATE') THEN

				NEW.objekt_id = OLD.objekt_id; -- Overskriver en evt. ændring
				NEW.oprettet = OLD.oprettet; -- Overskriver en evt. ændring

				-- Old version into greg_history
				OLD.systid_til = NEW.systid_fra;
				INSERT INTO greg_history.t_greg_linier VALUES (OLD.*);

				RETURN NEW;

			ELSIF (TG_OP = 'INSERT') THEN

				NEW.objekt_id = NEW.versions_id;
				NEW.oprettet = NEW.systid_fra;

				-- Set DEFAULT values (Updateable views)
				NEW.cvr_kode = COALESCE(NEW.cvr_kode, 29189129);
				NEW.bruger_id = COALESCE(NEW.bruger_id, current_user);
				NEW.oprindkode = COALESCE(NEW.oprindkode, 0);
				NEW.statuskode = COALESCE(NEW.statuskode, 0);
				NEW.off_kode = COALESCE(NEW.off_kode, 1);
				NEW.hoejde = COALESCE(NEW.hoejde, 0.00);
				NEW.bredde = COALESCE(NEW.bredde, 0.00);
				NEW.tilstand_kode = COALESCE(NEW.tilstand_kode,9);

				RETURN NEW;

			END IF;
		END IF;
	END;

$$;

COMMENT ON FUNCTION greg.t_greg_linier_trg() IS 'Indsætter UUIDs, timestamps, samt default values, hvis ikke angivet og retter geometri til ST_Multi.

Opdateres eller slettes geometrier, bliver de kopieret til en historiktabel.';



CREATE FUNCTION greg.t_greg_omraader_flader_trg() RETURNS trigger
	LANGUAGE plpgsql
	AS $$

	DECLARE
	
	geometri_n public.geometry;
	geometri_o public.geometry;
	
	BEGIN

		IF (TG_OP = 'DELETE') THEN
		
			SELECT public.ST_Multi(public.ST_Buffer(public.ST_Union(geometri), 0.0001)) FROM greg.t_greg_flader INTO geometri_o WHERE arbejdssted = OLD.arbejdssted;

		ELSIF (TG_OP = 'UPDATE') THEN

			SELECT public.ST_Multi(public.ST_Buffer(public.ST_Union(geometri), 0.0001)) FROM greg.t_greg_flader INTO geometri_n WHERE arbejdssted = NEW.arbejdssted;

			SELECT public.ST_Multi(public.ST_Buffer(public.ST_Union(geometri), 0.0001)) FROM greg.t_greg_flader INTO geometri_o WHERE arbejdssted = OLD.arbejdssted;

		ELSIF (TG_OP = 'INSERT') THEN

			SELECT public.ST_Multi(public.ST_Buffer(public.ST_Union(geometri), 0.0001)) FROM greg.t_greg_flader INTO geometri_n WHERE arbejdssted = NEW.arbejdssted;
		
		END IF;


		IF (TG_OP = 'DELETE') THEN

			UPDATE greg.t_greg_omraader
				SET
					geometri = geometri_o
				WHERE pg_distrikt_nr = OLD.arbejdssted AND pg_distrikt_type NOT IN('Vejarealer');

			RETURN OLD;

		ELSIF (TG_OP = 'UPDATE') THEN

			IF OLD.arbejdssted <> NEW.arbejdssted THEN

				UPDATE greg.t_greg_omraader
					SET
						geometri = geometri_o
					WHERE pg_distrikt_nr = OLD.arbejdssted AND pg_distrikt_type NOT IN('Vejarealer');

				UPDATE greg.t_greg_omraader
					SET
						geometri = geometri_n
					WHERE pg_distrikt_nr = NEW.arbejdssted AND pg_distrikt_type NOT IN('Vejarealer');

			ELSIF public.ST_Equals(OLD.geometri, NEW.geometri) IS FALSE THEN
			
				UPDATE greg.t_greg_omraader
					SET
						geometri = geometri_n
					WHERE pg_distrikt_nr = NEW.arbejdssted AND pg_distrikt_type NOT IN('Vejarealer');
					
			END IF;

			RETURN NEW;

		ELSIF (TG_OP = 'INSERT') THEN

			UPDATE greg.t_greg_omraader
				SET
					geometri = geometri_n
				WHERE pg_distrikt_nr = NEW.arbejdssted AND pg_distrikt_type NOT IN('Vejarealer');

			RETURN NEW;

		END IF;
	END;

$$;

COMMENT ON FUNCTION greg.t_greg_omraader_flader_trg() IS 'Opdaterer områdegrænsen, når der sker ændringer i t_greg_flader';



CREATE FUNCTION greg.t_greg_omraader_trg() RETURNS trigger
	LANGUAGE plpgsql
	AS $$

	BEGIN

		IF (TG_OP = 'UPDATE') THEN

			-- Geometri-kontrol
			IF public.ST_Equals(NEW.geometri, OLD.geometri) IS FALSE THEN -- Kun hvis man ændrer på geometrien, tages der stilling
				IF EXISTS (SELECT '1' FROM greg.t_greg_omraader WHERE public.ST_Contains(geometri, NEW.geometri) IS TRUE AND objekt_id <> OLD.objekt_id AND pg_distrikt_type NOT IN('Vejarealer')) THEN
					RAISE EXCEPTION 'Geometrien befinder sig i en anden geometri';
				END IF;
				IF EXISTS (SELECT '1' FROM greg.t_greg_omraader WHERE (public.ST_Overlaps(NEW.geometri, geometri) IS TRUE OR public.ST_Within(geometri, NEW.geometri) IS TRUE) AND objekt_id <> OLD.objekt_id AND pg_distrikt_type NOT IN('Vejarealer')) THEN
					NEW.geometri = public.ST_Multi(public.ST_CollectionExtract(public.ST_Difference(NEW.geometri, (SELECT public.ST_Union(geometri) FROM greg.t_greg_omraader WHERE (public.ST_Overlaps(NEW.geometri, geometri) IS TRUE OR public.ST_Within(geometri, NEW.geometri) IS TRUE) AND objekt_id<>OLD.objekt_id AND pg_distrikt_type NOT IN('Vejarealer'))), 3));
				END IF;
			ELSE
				NEW.geometri = public.ST_Multi(NEW.geometri);
			END IF;

			NEW.objekt_id = OLD.objekt_id; -- Overskriver en evt. ændring

			RETURN NEW;

		ELSIF (TG_OP = 'INSERT') THEN

			-- Geometri-kontrol
			IF EXISTS (SELECT '1' FROM greg.t_greg_omraader WHERE public.ST_Contains(geometri, NEW.geometri) IS TRUE AND pg_distrikt_type NOT IN('Vejarealer')) THEN
				RAISE EXCEPTION 'Geometrien befinder sig i en anden geometri';
			END IF;
			IF EXISTS (SELECT '1' FROM greg.t_greg_omraader WHERE (public.ST_Overlaps(NEW.geometri, geometri) IS TRUE OR public.ST_Within(geometri, NEW.geometri) IS TRUE) AND pg_distrikt_type NOT IN('Vejarealer')) THEN
				NEW.geometri = public.ST_Multi(public.ST_CollectionExtract(public.ST_Difference(NEW.geometri, (SELECT public.ST_Union(geometri) FROM greg.t_greg_omraader WHERE (public.ST_Overlaps(NEW.geometri, geometri) IS TRUE OR public.ST_Within(geometri, NEW.geometri) IS TRUE) AND pg_distrikt_type NOT IN('Vejarealer'))), 3));
			ELSE
				NEW.geometri = public.ST_Multi(NEW.geometri);
			END IF;

			NEW.objekt_id = public.uuid_generate_v1();

			-- Set DEFAULT values (Updateable views)
			NEW.bruger_id = COALESCE(NEW.bruger_id, current_user);
			NEW.aktiv = COALESCE(NEW.aktiv, 1);

			RETURN NEW;

		END IF;
	END;

$$;

COMMENT ON FUNCTION greg.t_greg_omraader_trg() IS 'Indsætter UUID, samt default values, hvis ikke angivet, retter geometri til ST_Multi og indeholder 2 geometritjeks:
1) Geometrier må ikke overlappe eksisterende geometrier - tilskæres automatisk,
2) Geometrier må ikke befinde sig inde i andre geometrier.';



CREATE FUNCTION greg.t_greg_punkter_trg() RETURNS trigger
	LANGUAGE plpgsql
	AS $$

	BEGIN

		IF (TG_OP = 'DELETE') THEN

			-- Old version into greg_history
			OLD.systid_til = current_timestamp;
			INSERT INTO greg_history.t_greg_punkter VALUES (OLD.*);

			RETURN OLD;

		ELSE

			-- Initialize
			NEW.versions_id = public.uuid_generate_v1();
			NEW.systid_fra = current_timestamp;
			NEW.systid_til = NULL;
			NEW.geometri = public.ST_Multi(NEW.geometri);

			IF (TG_OP = 'UPDATE') THEN

				NEW.objekt_id = OLD.objekt_id; -- Overskriver en evt. ændring
				NEW.oprettet = OLD.oprettet; -- Overskriver en evt. ændring

				-- Old version into greg_history
				OLD.systid_til = NEW.systid_fra;
				INSERT INTO greg_history.t_greg_punkter VALUES (OLD.*);

				RETURN NEW;

			ELSIF (TG_OP = 'INSERT') THEN

				NEW.objekt_id = NEW.versions_id;
				NEW.oprettet = NEW.systid_fra;

				-- Set DEFAULT values (Updateable views)
				NEW.cvr_kode = COALESCE(NEW.cvr_kode, 29189129);
				NEW.bruger_id = COALESCE(NEW.bruger_id, current_user);
				NEW.oprindkode = COALESCE(NEW.oprindkode, 0);
				NEW.statuskode = COALESCE(NEW.statuskode, 0);
				NEW.off_kode = COALESCE(NEW.off_kode, 1);
				NEW.diameter = COALESCE(NEW.diameter, 0.00);
				NEW.hoejde = COALESCE(NEW.hoejde, 0.00);
				NEW.tilstand_kode = COALESCE(NEW.tilstand_kode,9);

				RETURN NEW;

			END IF;
		END IF;
	END;

$$;

COMMENT ON FUNCTION greg.t_greg_punkter_trg() IS 'Indsætter UUIDs, timestamps, samt default values, hvis ikke angivet og retter geometri til ST_Multi.

Opdateres eller slettes geometrier, bliver de kopieret til en historiktabel.';



CREATE FUNCTION greg.t_skitse_fl_trg() RETURNS trigger
	LANGUAGE plpgsql
	AS $$

	BEGIN

		IF (TG_OP = 'DELETE') THEN

			-- Old version into greg_history
			OLD.systid_til = current_timestamp;
			INSERT INTO greg_history.t_skitse_fl VALUES (OLD.*);

			RETURN OLD;

		ELSE

			-- Initialize
			NEW.versions_id = public.uuid_generate_v1();
			NEW.systid_fra = current_timestamp;
			NEW.systid_til = NULL;
			NEW.geometri = public.ST_Multi(NEW.geometri);

			IF (TG_OP = 'UPDATE') THEN

				NEW.objekt_id = OLD.objekt_id; -- Overskriver en evt. ændring
				NEW.oprettet = OLD.oprettet; -- Overskriver en evt. ændring

				-- Old version into greg_history
				OLD.systid_til = NEW.systid_fra;
				INSERT INTO greg_history.t_skitse_fl VALUES (OLD.*);

				RETURN NEW;

			ELSIF (TG_OP = 'INSERT') THEN

				NEW.objekt_id = NEW.versions_id;
				NEW.oprettet = NEW.systid_fra;

				NEW.bruger_id = COALESCE(NEW.bruger_id, current_user);

				RETURN NEW;

			END IF;
		END IF;
	END;

$$;

COMMENT ON FUNCTION greg.t_skitse_fl_trg() IS 'Indsætter UUIDs, timestamps, samt default values, hvis ikke angivet og retter geometri til ST_Multi.

Opdateres eller slettes geometrier, bliver de kopieret til en historiktabel.';



CREATE FUNCTION greg.t_skitse_li_trg() RETURNS trigger
	LANGUAGE plpgsql
	AS $$

	BEGIN

		IF (TG_OP = 'DELETE') THEN

			-- Old version into greg_history
			OLD.systid_til = current_timestamp;
			INSERT INTO greg_history.t_skitse_li VALUES (OLD.*);

			RETURN OLD;

		ELSE

			-- Initialize
			NEW.versions_id = public.uuid_generate_v1();
			NEW.systid_fra = current_timestamp;
			NEW.systid_til = NULL;
			NEW.geometri = public.ST_Multi(NEW.geometri);

			IF (TG_OP = 'UPDATE') THEN

				NEW.objekt_id = OLD.objekt_id; -- Overskriver en evt. ændring
				NEW.oprettet = OLD.oprettet; -- Overskriver en evt. ændring

				-- Old version into greg_history
				OLD.systid_til = NEW.systid_fra;
				INSERT INTO greg_history.t_skitse_li VALUES (OLD.*);

				RETURN NEW;

			ELSIF (TG_OP = 'INSERT') THEN

				NEW.objekt_id = NEW.versions_id;
				NEW.oprettet = NEW.systid_fra;

				NEW.bruger_id = COALESCE(NEW.bruger_id, current_user);

				RETURN NEW;

			END IF;
		END IF;
	END;

$$;

COMMENT ON FUNCTION greg.t_skitse_li_trg() IS 'Indsætter UUIDs, timestamps, samt default values, hvis ikke angivet og retter geometri til ST_Multi.

Opdateres eller slettes geometrier, bliver de kopieret til en historiktabel.';



CREATE FUNCTION t_skitse_pkt_trg() RETURNS trigger
	LANGUAGE plpgsql
	AS $$

	BEGIN

		IF (TG_OP = 'DELETE') THEN

			-- Old version into greg_history
			OLD.systid_til = current_timestamp;
			INSERT INTO greg_history.t_skitse_pkt VALUES (OLD.*);

			RETURN OLD;

		ELSE

			-- Initialize
			NEW.versions_id = public.uuid_generate_v1();
			NEW.systid_fra = current_timestamp;
			NEW.systid_til = NULL;
			NEW.geometri = public.ST_Multi(NEW.geometri);

			IF (TG_OP = 'UPDATE') THEN

				NEW.objekt_id = OLD.objekt_id; -- Overskriver en evt. ændring
				NEW.oprettet = OLD.oprettet; -- Overskriver en evt. ændring

				-- Old version into greg_history
				OLD.systid_til = NEW.systid_fra;
				INSERT INTO greg_history.t_skitse_pkt VALUES (OLD.*);

				RETURN NEW;

			ELSIF (TG_OP = 'INSERT') THEN

				NEW.objekt_id = NEW.versions_id;
				NEW.oprettet = NEW.systid_fra;

				NEW.bruger_id = COALESCE(NEW.bruger_id, current_user);

				RETURN NEW;

			END IF;
		END IF;
	END;

$$;

COMMENT ON FUNCTION greg.t_skitse_pkt_trg() IS 'Indsætter UUIDs, timestamps, samt default values, hvis ikke angivet og retter geometri til ST_Multi.

Opdateres eller slettes geometrier, bliver de kopieret til en historiktabel.';



CREATE FUNCTION greg.v_greg_flader_trg() RETURNS trigger
	LANGUAGE plpgsql
	AS $$

	BEGIN

		IF (TG_OP = 'DELETE') THEN

			-- Return "0 rows deleted" IF NOT EXISTS
			IF NOT EXISTS (SELECT '1' FROM greg.t_greg_flader WHERE versions_id = OLD.versions_id) THEN
				RETURN NULL;
			END IF;

			DELETE
				FROM greg.t_greg_flader
				WHERE versions_id = OLD.versions_id;

			RETURN OLD;

		ELSIF (TG_OP = 'UPDATE') THEN

			-- Return "0 rows deleted" IF NOT EXISTS
			IF NOT EXISTS (SELECT '1' FROM greg.t_greg_flader WHERE versions_id = OLD.versions_id) THEN
				RETURN NULL;
			END IF;

			UPDATE greg.t_greg_flader
				SET
					cvr_kode = NEW.cvr_kode,
					bruger_id = NEW.bruger_id,
					oprindkode = NEW.oprindkode,
					statuskode = NEW.statuskode,
					off_kode = NEW.off_kode,
					underelement_kode = NEW.underelement_kode,
					arbejdssted = NEW.arbejdssted,
					udfoerer_entrep = NEW.udfoerer_entrep,
					kommunal_kontakt = NEW.kommunal_kontakt,
					anlaegsaar = NEW.anlaegsaar,
					klip_sider = NEW.klip_sider,
					hoejde = NEW.hoejde,
					tilstand_kode = NEW.tilstand_kode,
					litra = NEW.litra,
					note = NEW.note,
					vejkode = NEW.vejkode,
					link = NEW.link,
					geometri = NEW.geometri
				WHERE versions_id = OLD.versions_id;

			RETURN NEW;

		ELSIF (TG_OP = 'INSERT') THEN

			INSERT INTO greg.t_greg_flader
				VALUES (
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NEW.cvr_kode,
					NEW.bruger_id,
					NEW.oprindkode,
					NEW.statuskode,
					NEW.off_kode,
					NEW.underelement_kode,
					NEW.arbejdssted,
					NEW.udfoerer_entrep,
					NEW.kommunal_kontakt,
					NEW.anlaegsaar,
					NEW.klip_sider,
					NEW.hoejde,
					NEW.tilstand_kode,
					NEW.litra,
					NEW.note,
					NEW.vejkode,
					NEW.link,
					NEW.geometri
				);

			RETURN NEW;
		END IF;
	END;

$$;

COMMENT ON FUNCTION greg.v_greg_flader_trg() IS 'Muliggør opdatering gennem v_greg_flader';



CREATE FUNCTION greg.v_greg_linier_trg() RETURNS trigger
	LANGUAGE plpgsql
	AS $$

	BEGIN

		IF (TG_OP = 'DELETE') THEN

			-- Return "0 rows deleted" IF NOT EXISTS
			IF NOT EXISTS (SELECT '1' FROM greg.t_greg_linier WHERE versions_id = OLD.versions_id) THEN
				RETURN NULL;
			END IF;

			DELETE
				FROM greg.t_greg_linier
				WHERE versions_id = OLD.versions_id;

			RETURN OLD;

		ELSIF (TG_OP = 'UPDATE') THEN

			-- Return "0 rows deleted" IF NOT EXISTS
			IF NOT EXISTS (SELECT '1' FROM greg.t_greg_linier WHERE versions_id = OLD.versions_id) THEN
				RETURN NULL;
			END IF;

			UPDATE greg.t_greg_linier
				SET
					cvr_kode = NEW.cvr_kode,
					bruger_id = NEW.bruger_id,
					oprindkode = NEW.oprindkode,
					statuskode = NEW.statuskode,
					off_kode = NEW.off_kode,
					underelement_kode = NEW.underelement_kode,
					arbejdssted = NEW.arbejdssted,
					udfoerer_entrep = NEW.udfoerer_entrep,
					kommunal_kontakt = NEW.kommunal_kontakt,
					anlaegsaar = NEW.anlaegsaar,
					hoejde = NEW.hoejde,
					bredde = NEW.bredde,
					tilstand_kode = NEW.tilstand_kode,
					litra = NEW.litra,
					note = NEW.note,
					vejkode = NEW.vejkode,
					link = NEW.link,
					geometri = NEW.geometri
				WHERE versions_id = OLD.versions_id;

			RETURN NEW;

		ELSIF (TG_OP = 'INSERT') THEN

			INSERT INTO greg.t_greg_linier
				VALUES (
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NEW.cvr_kode,
					NEW.bruger_id,
					NEW.oprindkode,
					NEW.statuskode,
					NEW.off_kode,
					NEW.underelement_kode,
					NEW.arbejdssted,
					NEW.udfoerer_entrep,
					NEW.kommunal_kontakt,
					NEW.anlaegsaar,
					NEW.hoejde,
					NEW.bredde,
					NEW.tilstand_kode,
					NEW.litra,
					NEW.note,
					NEW.vejkode,
					NEW.link,
					NEW.geometri
				);

			RETURN NEW;
		END IF;
	END;

$$;

COMMENT ON FUNCTION greg.v_greg_linier_trg() IS 'Muliggør opdatering gennem v_greg_linier';



CREATE FUNCTION greg.v_greg_omraadeliste_trg() RETURNS trigger
	LANGUAGE plpgsql
	AS $$

	BEGIN

		IF (TG_OP = 'DELETE') THEN

			-- Return "0 rows deleted" IF NOT EXISTS
			IF NOT EXISTS (SELECT '1' FROM greg.t_greg_omraader WHERE objekt_id = OLD.objekt_id) THEN
				RETURN NULL;
			END IF;

			DELETE
				FROM greg.t_greg_omraader
				WHERE objekt_id = OLD.objekt_id;

			RETURN OLD;

		ELSIF (TG_OP = 'UPDATE') THEN

			-- Return "0 rows deleted" IF NOT EXISTS
			IF NOT EXISTS (SELECT '1' FROM greg.t_greg_omraader WHERE objekt_id = OLD.objekt_id) THEN
				RETURN NULL;
			END IF;

			UPDATE greg.t_greg_omraader
				SET
					bruger_id = NEW.bruger_id,
					pg_distrikt_nr = NEW.pg_distrikt_nr,
					pg_distrikt_tekst = NEW.pg_distrikt_tekst,
					pg_distrikt_type = NEW.pg_distrikt_type,
					udfoerer = NEW.udfoerer,
					udfoerer_kontakt1 = NEW.udfoerer_kontakt1,
					udfoerer_kontakt2 = NEW.udfoerer_kontakt2,
					kommunal_kontakt = NEW.kommunal_kontakt,
					vejkode = NEW.vejkode,
					vejnr = NEW.vejnr,
					postnr = NEW.postnr,
					note = NEW.note,
					link = NEW.link,
					aktiv = NEW.aktiv
				WHERE objekt_id = OLD.objekt_id;

			RETURN NEW;

		ELSIF (TG_OP = 'INSERT') THEN

			INSERT INTO greg.t_greg_omraader
				VALUES (
					NULL,
					NEW.bruger_id,
					NEW.pg_distrikt_nr,
					NEW.pg_distrikt_tekst,
					NEW.pg_distrikt_type,
					NEW.udfoerer,
					NEW.udfoerer_kontakt1,
					NEW.udfoerer_kontakt2,
					NEW.kommunal_kontakt,
					NEW.vejkode,
					NEW.vejnr,
					NEW.postnr,
					NEW.note,
					NEW.link,
					NEW.aktiv,
					NULL
				);

			RETURN NEW;
		END IF;
	END;

$$;

COMMENT ON FUNCTION greg.v_greg_omraadeliste_trg() IS 'Muliggør opdatering gennem v_greg_omraadeliste';



CREATE FUNCTION greg.v_greg_omraader_trg() RETURNS trigger
	LANGUAGE plpgsql
	AS $$

	BEGIN

		IF (TG_OP = 'DELETE') THEN

			-- Return "0 rows deleted" IF NOT EXISTS
			IF NOT EXISTS (SELECT '1' FROM greg.t_greg_omraader WHERE objekt_id = OLD.objekt_id) THEN
				RETURN NULL;
			END IF;

			DELETE
				FROM greg.t_greg_omraader
				WHERE objekt_id = OLD.objekt_id;

			RETURN OLD;

		ELSIF (TG_OP = 'UPDATE') THEN

			-- Return "0 rows deleted" IF NOT EXISTS
			IF NOT EXISTS (SELECT '1' FROM greg.t_greg_omraader WHERE objekt_id = OLD.objekt_id) THEN
				RETURN NULL;
			END IF;

			UPDATE greg.t_greg_omraader
				SET
					bruger_id = NEW.bruger_id,
					pg_distrikt_nr = NEW.pg_distrikt_nr,
					pg_distrikt_tekst = NEW.pg_distrikt_tekst,
					pg_distrikt_type = NEW.pg_distrikt_type,
					udfoerer = NEW.udfoerer,
					udfoerer_kontakt1 = NEW.udfoerer_kontakt1,
					udfoerer_kontakt2 = NEW.udfoerer_kontakt2,
					kommunal_kontakt = NEW.kommunal_kontakt,
					vejkode = NEW.vejkode,
					vejnr = NEW.vejnr,
					postnr = NEW.postnr,
					note = NEW.note,
					link = NEW.link,
					aktiv = NEW.aktiv,
					geometri = NEW.geometri
				WHERE objekt_id = OLD.objekt_id;

			RETURN NEW;

		ELSIF (TG_OP = 'INSERT') THEN

			INSERT INTO greg.t_greg_omraader
				VALUES (
					NULL,
					NEW.bruger_id,
					NEW.pg_distrikt_nr,
					NEW.pg_distrikt_tekst,
					NEW.pg_distrikt_type,
					NEW.udfoerer,
					NEW.udfoerer_kontakt1,
					NEW.udfoerer_kontakt2,
					NEW.kommunal_kontakt,
					NEW.vejkode,
					NEW.vejnr,
					NEW.postnr,
					NEW.note,
					NEW.link,
					NEW.aktiv,
					NEW.geometri
				);
			RETURN NEW;
		END IF;
	END;

$$;

COMMENT ON FUNCTION greg.v_greg_omraader_trg() IS 'Muliggør opdatering gennem v_greg_omraader';



CREATE FUNCTION v_greg_punkter_trg() RETURNS trigger
	LANGUAGE plpgsql
	AS $$

	BEGIN

		IF (TG_OP = 'DELETE') THEN

			-- Return "0 rows deleted" IF NOT EXISTS
			IF NOT EXISTS (SELECT '1' FROM greg.t_greg_punkter WHERE versions_id = OLD.versions_id) THEN
				RETURN NULL;
			END IF;

			DELETE
				FROM greg.t_greg_punkter
				WHERE versions_id = OLD.versions_id;

			RETURN OLD;

		ELSIF (TG_OP = 'UPDATE') THEN

			-- Return "0 rows deleted" IF NOT EXISTS
			IF NOT EXISTS (SELECT '1' FROM greg.t_greg_punkter WHERE versions_id = OLD.versions_id) THEN
				RETURN NULL;
			END IF;

			UPDATE greg.t_greg_punkter
				SET
					cvr_kode = NEW.cvr_kode,
					bruger_id = NEW.bruger_id,
					oprindkode = NEW.oprindkode,
					statuskode = NEW.statuskode,
					off_kode = NEW.off_kode,
					underelement_kode = NEW.underelement_kode,
					arbejdssted = NEW.arbejdssted,
					udfoerer_entrep = NEW.udfoerer_entrep,
					kommunal_kontakt = NEW.kommunal_kontakt,
					anlaegsaar = NEW.anlaegsaar,
					diameter = NEW.diameter,
					hoejde = NEW.hoejde,
					tilstand_kode = NEW.tilstand_kode,
					litra = NEW.litra,
					note = NEW.note,
					vejkode = NEW.vejkode,
					slaegt = NEW.slaegt,
					art = NEW.art,
					link = NEW.link,
					geometri = NEW.geometri
				WHERE versions_id = OLD.versions_id;

			RETURN NEW;

		ELSIF (TG_OP = 'INSERT') THEN

			INSERT INTO greg.t_greg_punkter
				VALUES (
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NEW.cvr_kode,
					NEW.bruger_id,
					NEW.oprindkode,
					NEW.statuskode,
					NEW.off_kode,
					NEW.underelement_kode,
					NEW.arbejdssted,
					NEW.udfoerer_entrep,
					NEW.kommunal_kontakt,
					NEW.anlaegsaar,
					NEW.diameter,
					NEW.hoejde,
					NEW.tilstand_kode,
					NEW.litra,
					NEW.note,
					NEW.vejkode,
					NEW.slaegt,
					NEW.art,
					NEW.link,
					NEW.geometri
				);

			RETURN NEW;
		END IF;
	END;

$$;

COMMENT ON FUNCTION greg.v_greg_punkter_trg() IS 'Muliggør opdatering gennem v_greg_punkter';

--
-- Search path
--

SET search_path = greg, pg_catalog;

SET default_with_oids = false;

--
-- CREATE TABLE
--

CREATE TABLE greg.d_basis_ansvarlig_myndighed (
	cvr_kode integer NOT NULL,
	cvr_navn character varying(128) NOT NULL,
	kommunekode integer,
	aktiv integer DEFAULT 1 NOT NULL,
	CONSTRAINT d_basis_ansvarlig_myndighed_pk PRIMARY KEY (cvr_kode) WITH (fillfactor='10'),
	CONSTRAINT d_basis_ansvarlig_myndighed_ck_aktiv CHECK ((aktiv BETWEEN 0 AND 1))
);

COMMENT ON TABLE greg.d_basis_ansvarlig_myndighed IS 'Elementer er tilknyttet pågældende kommune (FKG).';


CREATE TABLE greg.d_basis_bruger_id (
	bruger_id character varying(28) NOT NULL,
	navn character varying(28) NOT NULL,
	aktiv integer DEFAULT 1 NOT NULL,
	CONSTRAINT d_basis_bruger_id_pk PRIMARY KEY (bruger_id) WITH (fillfactor='10'),
	CONSTRAINT d_basis_bruger_id_ck_aktiv CHECK ((aktiv BETWEEN 0 AND 1))
);

COMMENT ON TABLE greg.d_basis_bruger_id IS 'ID på bruger, som har oprettet eller ændret elementet (FKG).';


CREATE TABLE greg.d_basis_distrikt_type (
	pg_distrikt_type character varying(30) NOT NULL,
	aktiv integer DEFAULT 1 NOT NULL,
	CONSTRAINT d_basis_distrikt_type_pk PRIMARY KEY (pg_distrikt_type) WITH (fillfactor='10'),
	CONSTRAINT d_basis_distrikt_type_ck_aktiv CHECK ((aktiv BETWEEN 0 AND 1))
);

COMMENT ON TABLE greg.d_basis_distrikt_type IS 'Områder inddeles i forskellige områdetyper. Fx grønne områder, skoler mv.';


CREATE TABLE greg.d_basis_hovedelementer (
	hovedelement_kode character varying(3) NOT NULL,
	hovedelement_tekst character varying(20) NOT NULL,
	aktiv integer DEFAULT 1 NOT NULL,
	CONSTRAINT d_basis_hovedelementer_pk PRIMARY KEY (hovedelement_kode) WITH (fillfactor='10'),
	CONSTRAINT d_basis_hovedelementer_ck_aktiv CHECK ((aktiv BETWEEN 0 AND 1))
);

COMMENT ON TABLE greg.d_basis_hovedelementer IS 'Den generelle elementtype. Fx græs, belægninger mv.';


CREATE TABLE greg.d_basis_elementer (
	hovedelement_kode character varying(3) NOT NULL,
	element_kode character varying(6) NOT NULL,
	element_tekst character varying(30) NOT NULL,
	aktiv integer DEFAULT 1 NOT NULL,
	CONSTRAINT d_basis_elementer_pk PRIMARY KEY (element_kode) WITH (fillfactor='10'),
	CONSTRAINT d_basis_elementer_fk_d_basis_hovedelementer FOREIGN KEY (hovedelement_kode) REFERENCES greg.d_basis_hovedelementer(hovedelement_kode) MATCH FULL
		ON UPDATE CASCADE,
	CONSTRAINT d_basis_elementer_ck_element_kode CHECK (element_kode ~* (hovedelement_kode || '-' || '[0-9]{2}')),
	CONSTRAINT d_basis_elementer_ck_aktiv CHECK ((aktiv BETWEEN 0 AND 1))
);

COMMENT ON TABLE greg.d_basis_elementer IS 'Den mere specifikke elementtype. Fx Faste belægninger, løse belægninger mv.';


CREATE TABLE greg.d_basis_kommunal_kontakt (
	navn character varying(100) NOT NULL,
	telefon character(8) NOT NULL,
	email character varying(50) NOT NULL,
	aktiv integer DEFAULT 1 NOT NULL,
	CONSTRAINT d_basis_kommunal_kontakt_pk PRIMARY KEY (email) WITH (fillfactor='10'),
	CONSTRAINT d_basis_kommunal_kontakt_ck_telefon CHECK ((telefon ~* '[0-9]{8}')),
	CONSTRAINT d_basis_kommunal_kontakt_ck_aktiv CHECK ((aktiv BETWEEN 0 AND 1))
);

COMMENT ON TABLE greg.d_basis_kommunal_kontakt IS 'Den person, som et bestemt område vedrører (FKG).';


CREATE TABLE greg.d_basis_offentlig (
	off_kode integer NOT NULL,
	offentlig character varying(60) NOT NULL,
	aktiv integer DEFAULT 1 NOT NULL,
	CONSTRAINT d_basis_offentlig_pk PRIMARY KEY (off_kode) WITH (fillfactor='10'),
	CONSTRAINT d_basis_offentlig_ck_aktiv CHECK ((aktiv BETWEEN 0 AND 1))
);

COMMENT ON TABLE greg.d_basis_offentlig IS 'Et elements offentlighedsstatus (FKG).';


CREATE TABLE greg.d_basis_omraadenr (
	pg_distrikt_nr integer NOT NULL,
	CONSTRAINT d_basis_omraadenr_pk PRIMARY KEY (pg_distrikt_nr) WITH (fillfactor='10')
);

COMMENT ON TABLE greg.d_basis_omraadenr IS 'Indirekte relation mellem t_greg_omraader og hhv. (t_greg) flader, linier og punkter. Ellers er der problemer med merge i QGIS.';



CREATE TABLE greg.d_basis_oprindelse (
	oprindkode integer NOT NULL,
	oprindelse character varying(35) NOT NULL,
	aktiv integer DEFAULT 1 NOT NULL,
	begrebsdefinition character varying,
	CONSTRAINT d_basis_oprindelse_pk PRIMARY KEY (oprindkode) WITH (fillfactor='10'),
	CONSTRAINT d_basis_oprindelse_ck_aktiv CHECK ((aktiv BETWEEN 0 AND 1))
);

COMMENT ON TABLE greg.d_basis_oprindelse IS 'Et elements oprindelse, tegnet fra ortofoto, højdemodel mv. (FKG)';


CREATE TABLE greg.d_basis_postdistrikter (
	postnr numeric(4,0) NOT NULL,
	distriktnavn character varying(28) NOT NULL,
	aktiv integer DEFAULT 1 NOT NULL,
	CONSTRAINT d_basis_postdistrikter_pk PRIMARY KEY (postnr) WITH (fillfactor='10'),
	CONSTRAINT d_basis_postdistrikter_ck_aktiv CHECK ((aktiv BETWEEN 0 AND 1))
);

COMMENT ON TABLE greg.d_basis_postdistrikter IS 'Det postnr. et givent område ligger i.';


CREATE TABLE greg.d_basis_pris_enhed (
	pris_enhed character varying(6) NOT NULL,
	aktiv integer DEFAULT 1 NOT NULL,
	CONSTRAINT d_basis_pris_enhed_pk PRIMARY KEY (pris_enhed) WITH (fillfactor='10'),
	CONSTRAINT d_basis_pris_enhed_ck_aktiv CHECK ((aktiv BETWEEN 0 AND 1))
);

COMMENT ON TABLE greg.d_basis_pris_enhed IS 'Den enhed, som et element afregnes efter. Fx pr lbm, m2 mv.';


CREATE TABLE greg.d_basis_status (
	statuskode integer NOT NULL,
	status character varying(30) NOT NULL,
	aktiv integer DEFAULT 1 NOT NULL,
	CONSTRAINT d_basis_status_pk PRIMARY KEY (statuskode) WITH (fillfactor='10'),
	CONSTRAINT d_basis_status_ck_aktiv CHECK ((aktiv BETWEEN 0 AND 1))
);

COMMENT ON TABLE greg.d_basis_status IS 'Et elements gyldighedsstatus (FKG).';


CREATE TABLE greg.d_basis_tilstand (
	tilstand_kode integer NOT NULL,
	tilstand character varying(25) NOT NULL,
	aktiv integer DEFAULT 1 NOT NULL,
	begrebsdefinition character varying,
	CONSTRAINT d_basis_tilstand_pk PRIMARY KEY (tilstand_kode) WITH (fillfactor='10'),
	CONSTRAINT d_basis_tilstand_ck_aktiv CHECK ((aktiv BETWEEN 0 AND 1))
);

COMMENT ON TABLE greg.d_basis_tilstand IS 'Et elements tilstand (FKG).';


CREATE TABLE greg.d_basis_udfoerer (
	udfoerer character varying(50) NOT NULL,
	aktiv integer DEFAULT 1 NOT NULL,
	CONSTRAINT d_basis_udfoerer_pk PRIMARY KEY (udfoerer) WITH (fillfactor='10'),
	CONSTRAINT d_basis_udfoerer_ck_aktiv CHECK ((aktiv BETWEEN 0 AND 1))
);

COMMENT ON TABLE greg.d_basis_udfoerer IS 'Et givent områdes ansvarlige udfører (FKG).';


CREATE TABLE greg.d_basis_udfoerer_entrep (
	navn character varying(50) NOT NULL,
	aktiv integer DEFAULT 1 NOT NULL,
	CONSTRAINT d_basis_udfoerer_entrep_pk PRIMARY KEY (navn) WITH (fillfactor='10'),
	CONSTRAINT d_basis_udfoerer_entrep_ck_aktiv CHECK ((aktiv BETWEEN 0 AND 1))
);

COMMENT ON TABLE greg.d_basis_udfoerer_entrep IS 'Et elements ansvarlige udførerende entreprenør (FKG).';


CREATE TABLE greg.d_basis_udfoerer_kontakt (
	udfoerer character varying(100) NOT NULL,
	navn character varying(100) NOT NULL,
	telefon character(8) NOT NULL,
	email character varying(50) NOT NULL,
	aktiv integer DEFAULT 1 NOT NULL,
	CONSTRAINT d_basis_udfoerer_kontakt_pk PRIMARY KEY (email) WITH (fillfactor='10'),
	CONSTRAINT d_basis_udfoerer_kontakt_fk_d_basis_udfoerer FOREIGN KEY (udfoerer) REFERENCES greg.d_basis_udfoerer(udfoerer) MATCH FULL
		ON UPDATE CASCADE,
	CONSTRAINT d_basis_udfoerer_kontakt_ck_telefon CHECK ((telefon ~* '[0-9]{8}')),
	CONSTRAINT d_basis_udfoerer_kontakt_ck_aktiv CHECK ((aktiv BETWEEN 0 AND 1))
);

COMMENT ON TABLE greg.d_basis_udfoerer_kontakt IS 'Kontaktsinformationer på den ansvarlige udfører (FKG).';


CREATE TABLE greg.d_basis_underelementer (
	element_kode character varying(6) NOT NULL,
	underelement_kode character varying(9) NOT NULL,
	underelement_tekst character varying(30) NOT NULL,
	objekt_type character varying(3) NOT NULL,
	enhedspris numeric(10,2) DEFAULT 0.00 NOT NULL,
	enhedspris_klip numeric(10,2) DEFAULT 0.00,
	pris_enhed character varying(6),
	aktiv integer DEFAULT 1 NOT NULL,
	CONSTRAINT d_basis_underelementer_pk PRIMARY KEY (underelement_kode) WITH (fillfactor='10'),
	CONSTRAINT d_basis_underelementer_fk_d_basis_elementer FOREIGN KEY (element_kode) REFERENCES greg.d_basis_elementer(element_kode) MATCH FULL
		ON UPDATE CASCADE,
	CONSTRAINT d_basis_underelementer_fk_d_basis_pris_enhed FOREIGN KEY (pris_enhed) REFERENCES greg.d_basis_pris_enhed(pris_enhed),
	CONSTRAINT d_basis_underelementer_ck_enhedspris CHECK (enhedspris >= 0.0),
	CONSTRAINT d_basis_underelementer_ck_objekt_type CHECK (objekt_type ~* '(f|l|p)+'),
	CONSTRAINT d_basis_underelementer_ck_underelement_kode CHECK (underelement_kode ~* (element_kode || '-' || '[0-9]{2}')),
	CONSTRAINT d_basis_underelementer_ck_aktiv CHECK ((aktiv BETWEEN 0 AND 1))
);

COMMENT ON TABLE greg.d_basis_underelementer IS 'Den helt specifikke elementtype. Fx beton, asfalt mv.';


CREATE TABLE greg.d_basis_vejnavn (
	vejkode integer NOT NULL,
	vejnavn character varying(40) NOT NULL,
	aktiv integer DEFAULT 1 NOT NULL,
	cvf_vejkode character varying(7),
	postnr integer,
	kommunekode integer,
	CONSTRAINT d_basis_vejnavn_pk PRIMARY KEY (vejkode) WITH (fillfactor='10')
);

COMMENT ON TABLE greg.d_basis_vejnavn IS 'Vejnavne tilknyttet hhv. elementer og områder';


CREATE TABLE greg.t_greg_delomraader (
	objekt_id uuid NOT NULL,
	bruger_id character varying(128) NOT NULL,
	pg_distrikt_nr integer NOT NULL,
	delnavn character varying(150),
	delomraade integer NOT NULL,
	geometri public.geometry(MultiPolygon,25832) NOT NULL,
	CONSTRAINT t_greg_delomraader_pk PRIMARY KEY (objekt_id) WITH (fillfactor='10'),
	CONSTRAINT t_greg_delomraader_fk_d_basis_bruger_id FOREIGN KEY (bruger_id) REFERENCES greg.d_basis_bruger_id(bruger_id) MATCH FULL
	ON UPDATE CASCADE,
	CONSTRAINT t_greg_delomraader_fk_d_basis_omraadenr FOREIGN KEY (pg_distrikt_nr) REFERENCES greg.d_basis_omraadenr(pg_distrikt_nr) MATCH FULL
	ON UPDATE CASCADE
);

COMMENT ON TABLE greg.t_greg_delomraader IS 'Specifikke områdeopdelinger i tilfælde af for store områder mht. atlas i QGIS';


CREATE TABLE greg.t_greg_flader (
	versions_id uuid NOT NULL,
	objekt_id uuid NOT NULL,
	systid_fra timestamp with time zone NOT NULL,
	systid_til timestamp with time zone,
	oprettet timestamp with time zone NOT NULL,
	cvr_kode integer DEFAULT 29189129 NOT NULL,
	bruger_id character varying(128) NOT NULL,
	oprindkode integer DEFAULT 0 NOT NULL,
	statuskode integer DEFAULT 0 NOT NULL,
	off_kode integer DEFAULT 1 NOT NULL,
	underelement_kode character varying(9) NOT NULL,
	arbejdssted integer NOT NULL,
	udfoerer_entrep character varying(50),
	kommunal_kontakt character varying(150),
	anlaegsaar date,
	klip_sider integer DEFAULT 0 NOT NULL,
	hoejde numeric(10,2) DEFAULT 0.00 NOT NULL,
	tilstand_kode integer DEFAULT 9 NOT NULL,
	litra character varying(128),
	note character varying(254),
	vejkode integer,
	link character varying(1024),
	geometri public.geometry(MultiPolygon,25832) NOT NULL,
	CONSTRAINT t_greg_flader_pk PRIMARY KEY (versions_id) WITH (fillfactor='10'),
	CONSTRAINT t_greg_flader_fk_d_basis_ansvarlig_myndighed FOREIGN KEY (cvr_kode) REFERENCES greg.d_basis_ansvarlig_myndighed(cvr_kode) MATCH FULL,
	CONSTRAINT t_greg_flader_fk_d_basis_bruger_id FOREIGN KEY (bruger_id) REFERENCES greg.d_basis_bruger_id(bruger_id) MATCH FULL
		ON UPDATE CASCADE,
	CONSTRAINT t_greg_flader_fk_d_basis_kommunal_kontakt FOREIGN KEY (kommunal_kontakt) REFERENCES greg.d_basis_kommunal_kontakt(email) MATCH FULL
		ON UPDATE CASCADE,
	CONSTRAINT t_greg_flader_fk_d_basis_offentlig FOREIGN KEY (off_kode) REFERENCES greg.d_basis_offentlig(off_kode) MATCH FULL,
	CONSTRAINT t_greg_flader_fk_d_basis_omraadenr FOREIGN KEY (arbejdssted) REFERENCES greg.d_basis_omraadenr(pg_distrikt_nr) MATCH FULL
		ON UPDATE CASCADE,
	CONSTRAINT t_greg_flader_fk_d_basis_oprindelse FOREIGN KEY (oprindkode) REFERENCES greg.d_basis_oprindelse(oprindkode) MATCH FULL,
	CONSTRAINT t_greg_flader_fk_d_basis_status FOREIGN KEY (statuskode) REFERENCES greg.d_basis_status(statuskode) MATCH FULL,
	CONSTRAINT t_greg_flader_fk_d_basis_tilstand FOREIGN KEY (tilstand_kode) REFERENCES greg.d_basis_tilstand(tilstand_kode) MATCH FULL,
	CONSTRAINT t_greg_flader_fk_d_basis_udfoerer_entrep FOREIGN KEY (udfoerer_entrep) REFERENCES greg.d_basis_udfoerer_entrep(navn) MATCH FULL
		ON UPDATE CASCADE,
	CONSTRAINT t_greg_flader_fk_d_basis_underelementer FOREIGN KEY (underelement_kode) REFERENCES greg.d_basis_underelementer(underelement_kode) MATCH FULL,
	CONSTRAINT t_greg_flader_fk_d_basis_vejnavn FOREIGN KEY (vejkode) REFERENCES greg.d_basis_vejnavn(vejkode) MATCH FULL,
	CONSTRAINT t_greg_flader_ck_hoejde CHECK ((hoejde BETWEEN 0.00 AND 9.99)),
	CONSTRAINT t_greg_flader_ck_klip_sider CHECK ((klip_sider BETWEEN 0 AND 2)),
	CONSTRAINT t_greg_flader_ck_geometri CHECK ((public.ST_IsValid(geometri) IS TRUE))
);

COMMENT ON TABLE greg.t_greg_flader IS 'Rådatatabel for elementer defineret som flader';


CREATE TABLE greg.t_greg_linier (
	versions_id uuid NOT NULL,
	objekt_id uuid NOT NULL,
	systid_fra timestamp with time zone NOT NULL,
	systid_til timestamp with time zone,
	oprettet timestamp with time zone NOT NULL,
	cvr_kode integer DEFAULT 29189129 NOT NULL,
	bruger_id character varying(128) NOT NULL,
	oprindkode integer DEFAULT 0 NOT NULL,
	statuskode integer DEFAULT 0 NOT NULL,
	off_kode integer DEFAULT 1 NOT NULL,
	underelement_kode character varying(9) NOT NULL,
	arbejdssted integer NOT NULL,
	udfoerer_entrep character varying(50),
	kommunal_kontakt character varying(150),
	anlaegsaar date,
	hoejde numeric(10,2) DEFAULT 0.00 NOT NULL,
	bredde numeric(10,2) DEFAULT 0.00 NOT NULL,
	tilstand_kode integer DEFAULT 9 NOT NULL,
	litra character varying(128),
	note character varying(254),
	vejkode integer,
	link character varying(1024),
	geometri public.geometry(MultiLineString,25832) NOT NULL,
	CONSTRAINT t_greg_linier_pk PRIMARY KEY (versions_id) WITH (fillfactor='10'),
	CONSTRAINT t_greg_linier_fk_d_basis_ansvarlig_myndighed FOREIGN KEY (cvr_kode) REFERENCES greg.d_basis_ansvarlig_myndighed(cvr_kode) MATCH FULL,
	CONSTRAINT t_greg_linier_fk_d_basis_bruger_id FOREIGN KEY (bruger_id) REFERENCES greg.d_basis_bruger_id(bruger_id) MATCH FULL
		ON UPDATE CASCADE,
	CONSTRAINT t_greg_linier_fk_d_basis_kommunal_kontakt FOREIGN KEY (kommunal_kontakt) REFERENCES greg.d_basis_kommunal_kontakt(email) MATCH FULL
		ON UPDATE CASCADE,
	CONSTRAINT t_greg_linier_fk_d_basis_offentlig FOREIGN KEY (off_kode) REFERENCES greg.d_basis_offentlig(off_kode) MATCH FULL,
	CONSTRAINT t_greg_linier_fk_d_basis_omraadenr FOREIGN KEY (arbejdssted) REFERENCES greg.d_basis_omraadenr(pg_distrikt_nr) MATCH FULL
		ON UPDATE CASCADE,
	CONSTRAINT t_greg_linier_fk_d_basis_oprindelse FOREIGN KEY (oprindkode) REFERENCES greg.d_basis_oprindelse(oprindkode) MATCH FULL,
	CONSTRAINT t_greg_linier_fk_d_basis_status FOREIGN KEY (statuskode) REFERENCES greg.d_basis_status(statuskode) MATCH FULL,
	CONSTRAINT t_greg_linier_fk_d_basis_tilstand FOREIGN KEY (tilstand_kode) REFERENCES greg.d_basis_tilstand(tilstand_kode) MATCH FULL,
	CONSTRAINT t_greg_linier_fk_d_basis_udfoerer_entrep FOREIGN KEY (udfoerer_entrep) REFERENCES greg.d_basis_udfoerer_entrep(navn) MATCH FULL
		ON UPDATE CASCADE,
	CONSTRAINT t_greg_linier_fk_d_basis_underelementer FOREIGN KEY (underelement_kode) REFERENCES greg.d_basis_underelementer(underelement_kode) MATCH FULL,
	CONSTRAINT t_greg_linier_fk_d_basis_vejnavn FOREIGN KEY (vejkode) REFERENCES greg.d_basis_vejnavn(vejkode) MATCH FULL,
	CONSTRAINT t_greg_linier_ck_bredde CHECK ((bredde BETWEEN 0.00 AND 9.99)),
	CONSTRAINT t_greg_linier_ck_hoejde CHECK ((hoejde BETWEEN 0.00 AND 9.99)),
	CONSTRAINT t_greg_linier_ck_valid CHECK ((public.ST_IsValid(geometri) IS TRUE))
);

COMMENT ON TABLE greg.t_greg_linier IS 'Rådatatabel for elementer defineret som linier';


CREATE TABLE greg.t_greg_omraader (
	objekt_id uuid NOT NULL,
	bruger_id character varying(128) NOT NULL,
	pg_distrikt_nr integer NOT NULL,
	pg_distrikt_tekst character varying(150) NOT NULL,
	pg_distrikt_type character varying(30) NOT NULL,
	udfoerer character varying(50),
	udfoerer_kontakt1 character varying(50),
	udfoerer_kontakt2 character varying(50),
	kommunal_kontakt character varying(150),
	vejkode integer,
	vejnr character varying(20),
	postnr integer NOT NULL,
	note character varying(254),
	link character varying(1024),
	aktiv integer DEFAULT 1 NOT NULL,
	geometri public.geometry(MultiPolygon,25832),
	CONSTRAINT t_greg_omraader_pk PRIMARY KEY (objekt_id) WITH (fillfactor='10'),
	CONSTRAINT t_greg_omraader_unique_pg_distrikt_nr UNIQUE (pg_distrikt_nr),
	CONSTRAINT t_greg_omraader_fk_d_basis_bruger_id FOREIGN KEY (bruger_id) REFERENCES greg.d_basis_bruger_id(bruger_id) MATCH FULL
		ON UPDATE CASCADE,
	CONSTRAINT t_greg_omraader_fk_d_basis_distrikt_type FOREIGN KEY (pg_distrikt_type) REFERENCES greg.d_basis_distrikt_type(pg_distrikt_type) MATCH FULL
		ON UPDATE CASCADE,
	CONSTRAINT t_greg_omraader_fk_d_basis_kommunal_kontakt FOREIGN KEY (kommunal_kontakt) REFERENCES greg.d_basis_kommunal_kontakt(email) MATCH FULL
		ON UPDATE CASCADE,
	CONSTRAINT t_greg_omraader_fk_d_basis_omraadenr FOREIGN KEY (pg_distrikt_nr) REFERENCES greg.d_basis_omraadenr(pg_distrikt_nr) MATCH FULL
		ON UPDATE CASCADE,
	CONSTRAINT t_greg_omraader_fk_d_basis_postdistrikter FOREIGN KEY (postnr) REFERENCES greg.d_basis_postdistrikter(postnr) MATCH FULL,
	CONSTRAINT t_greg_omraader_fk_d_basis_udfoerer FOREIGN KEY (udfoerer) REFERENCES greg.d_basis_udfoerer(udfoerer) MATCH FULL
		ON UPDATE CASCADE,
	CONSTRAINT t_greg_omraader_fk_d_basis_udfoerer_kontakt1 FOREIGN KEY (udfoerer_kontakt1) REFERENCES greg.d_basis_udfoerer_kontakt(email) MATCH FULL
		ON UPDATE CASCADE,
	CONSTRAINT t_greg_omraader_fk_d_basis_udfoerer_kontakt2 FOREIGN KEY (udfoerer_kontakt2) REFERENCES greg.d_basis_udfoerer_kontakt(email) MATCH FULL
		ON UPDATE CASCADE,
	CONSTRAINT t_greg_omraader_fk_d_basis_vejnavn FOREIGN KEY (vejkode) REFERENCES greg.d_basis_vejnavn(vejkode) MATCH FULL,
	CONSTRAINT t_greg_omraader_ck_aktiv CHECK ((aktiv BETWEEN 0 AND 1))
);

COMMENT ON TABLE greg.t_greg_omraader IS 'Områdetabel';


CREATE TABLE greg.t_greg_punkter (
	versions_id uuid NOT NULL,
	objekt_id uuid NOT NULL,
	systid_fra timestamp with time zone NOT NULL,
	systid_til timestamp with time zone,
	oprettet timestamp with time zone NOT NULL,
	cvr_kode integer DEFAULT 29189129 NOT NULL,
	bruger_id character varying(128) NOT NULL,
	oprindkode integer DEFAULT 0 NOT NULL,
	statuskode integer DEFAULT 0 NOT NULL,
	off_kode integer DEFAULT 1 NOT NULL,
	underelement_kode character varying(9) NOT NULL,
	arbejdssted integer NOT NULL,
	udfoerer_entrep character varying(50),
	kommunal_kontakt character varying(150),
	anlaegsaar date,
	diameter numeric(10,2) DEFAULT 0.00 NOT NULL,
	hoejde numeric(10,2) DEFAULT 0.00 NOT NULL,
	tilstand_kode integer DEFAULT 9 NOT NULL,
	litra character varying(128),
	note character varying(254),
	vejkode integer,
	slaegt character varying(50),
	art character varying(50),
	link character varying(1024),
	geometri public.geometry(MultiPoint,25832) NOT NULL,
	CONSTRAINT t_greg_punkter_pk PRIMARY KEY (versions_id) WITH (fillfactor='10'),
	CONSTRAINT t_greg_punkter_fk_d_basis_ansvarlig_myndighed FOREIGN KEY (cvr_kode) REFERENCES greg.d_basis_ansvarlig_myndighed(cvr_kode) MATCH FULL,
	CONSTRAINT t_greg_punkter_fk_d_basis_bruger_id FOREIGN KEY (bruger_id) REFERENCES greg.d_basis_bruger_id(bruger_id) MATCH FULL
		ON UPDATE CASCADE,
	CONSTRAINT t_greg_punkter_fk_d_basis_kommunal_kontakt FOREIGN KEY (kommunal_kontakt) REFERENCES greg.d_basis_kommunal_kontakt(email) MATCH FULL
		ON UPDATE CASCADE,
	CONSTRAINT t_greg_punkter_fk_d_basis_offentlig FOREIGN KEY (off_kode) REFERENCES greg.d_basis_offentlig(off_kode) MATCH FULL,
	CONSTRAINT t_greg_punkter_fk_d_basis_omraadenr FOREIGN KEY (arbejdssted) REFERENCES greg.d_basis_omraadenr(pg_distrikt_nr) MATCH FULL
		ON UPDATE CASCADE,
	CONSTRAINT t_greg_punkter_fk_d_basis_oprindelse FOREIGN KEY (oprindkode) REFERENCES greg.d_basis_oprindelse(oprindkode) MATCH FULL,
	CONSTRAINT t_greg_punkter_fk_d_basis_status FOREIGN KEY (statuskode) REFERENCES greg.d_basis_status(statuskode) MATCH FULL,
	CONSTRAINT t_greg_punkter_fk_d_basis_tilstand FOREIGN KEY (tilstand_kode) REFERENCES greg.d_basis_tilstand(tilstand_kode) MATCH FULL,
	CONSTRAINT t_greg_punkter_fk_d_basis_udfoerer_entrep FOREIGN KEY (udfoerer_entrep) REFERENCES greg.d_basis_udfoerer_entrep(navn) MATCH FULL
		ON UPDATE CASCADE,
	CONSTRAINT t_greg_punkter_fk_d_basis_underelementer FOREIGN KEY (underelement_kode) REFERENCES greg.d_basis_underelementer(underelement_kode) MATCH FULL,
	CONSTRAINT t_greg_punkter_fk_d_basis_vejnavn FOREIGN KEY (vejkode) REFERENCES greg.d_basis_vejnavn(vejkode) MATCH FULL,
	CONSTRAINT t_greg_punkter_ck_diameter CHECK ((diameter >= 0.00)),
	CONSTRAINT t_greg_punkter_ck_hoejde CHECK ((hoejde >= 0.00))
);

COMMENT ON TABLE greg.t_greg_punkter IS 'Rådatatabel for elementer defineret som punkter';


CREATE TABLE greg.t_skitse_fl (
	versions_id uuid NOT NULL,
	objekt_id uuid NOT NULL,
	systid_fra timestamp with time zone NOT NULL,
	systid_til timestamp with time zone,
	oprettet timestamp with time zone NOT NULL,
	bruger_id character varying(128) NOT NULL,
	note character varying(254),
	geometri public.geometry(MultiPolygon,25832) NOT NULL,
	CONSTRAINT t_skitse_fl_pk PRIMARY KEY (versions_id) WITH (fillfactor='10'),
	CONSTRAINT t_skitse_fl_fk_bruger_id FOREIGN KEY (bruger_id) REFERENCES d_basis_bruger_id(bruger_id) MATCH FULL
		ON UPDATE CASCADE
);

COMMENT ON TABLE greg.t_skitse_fl IS 'Skitselag, flader';


CREATE TABLE greg.t_skitse_li (
	versions_id uuid NOT NULL,
	objekt_id uuid NOT NULL,
	systid_fra timestamp with time zone NOT NULL,
	systid_til timestamp with time zone,
	oprettet timestamp with time zone NOT NULL,
	bruger_id character varying(128) NOT NULL,
	note character varying(254),
	geometri public.geometry(MultiLineString,25832) NOT NULL,
	CONSTRAINT t_skitse_li_pk PRIMARY KEY (versions_id) WITH (fillfactor='10'),
	CONSTRAINT t_skitse_li_fk_bruger_id FOREIGN KEY (bruger_id) REFERENCES d_basis_bruger_id(bruger_id) MATCH FULL
		ON UPDATE CASCADE
);

COMMENT ON TABLE greg.t_skitse_li IS 'Skitselag, linier';


CREATE TABLE greg.t_skitse_pkt (
	versions_id uuid NOT NULL,
	objekt_id uuid NOT NULL,
	systid_fra timestamp with time zone NOT NULL,
	systid_til timestamp with time zone,
	oprettet timestamp with time zone NOT NULL,
	bruger_id character varying(128) NOT NULL,
	note character varying(254),
	geometri public.geometry(MultiPoint,25832) NOT NULL,
	CONSTRAINT t_skitse_pkt_pk PRIMARY KEY (versions_id) WITH (fillfactor='10'),
	CONSTRAINT t_skitse_pkt_fk_bruger_id FOREIGN KEY (bruger_id) REFERENCES d_basis_bruger_id(bruger_id) MATCH FULL
		ON UPDATE CASCADE
);

COMMENT ON TABLE greg.t_skitse_pkt IS 'Skitselag, punkter';

--
-- Search path
--

SET search_path = greg_history, pg_catalog;

--
-- CREATE TABLE
--

CREATE TABLE greg_history.t_greg_flader (
	versions_id uuid NOT NULL,
	objekt_id uuid NOT NULL,
	systid_fra timestamp with time zone NOT NULL,
	systid_til timestamp with time zone NOT NULL,
	oprettet timestamp with time zone NOT NULL,
	cvr_kode integer NOT NULL,
	bruger_id character varying(128) NOT NULL,
	oprindkode integer NOT NULL,
	statuskode integer NOT NULL,
	off_kode integer NOT NULL,
	underelement_kode character varying(9) NOT NULL,
	arbejdssted integer,
	udfoerer_entrep character varying(50),
	kommunal_kontakt character varying(150),
	anlaegsaar date,
	klip_sider integer NOT NULL,
	hoejde numeric(10,2) NOT NULL,
	tilstand_kode integer NOT NULL,
	litra character varying(128),
	note character varying(254),
	vejkode integer,
	link character varying(1024),
	geometri public.geometry(MultiPolygon,25832) NOT NULL,
	CONSTRAINT t_greg_flader_pk PRIMARY KEY (versions_id) WITH (fillfactor='10')
);

COMMENT ON TABLE greg_history.t_greg_flader IS 'Historik tilknyttet flader';


CREATE TABLE greg_history.t_greg_linier (
	versions_id uuid NOT NULL,
	objekt_id uuid NOT NULL,
	systid_fra timestamp with time zone NOT NULL,
	systid_til timestamp with time zone NOT NULL,
	oprettet timestamp with time zone NOT NULL,
	cvr_kode integer NOT NULL,
	bruger_id character varying(128) NOT NULL,
	oprindkode integer NOT NULL,
	statuskode integer NOT NULL,
	off_kode integer NOT NULL,
	underelement_kode character varying(9) NOT NULL,
	arbejdssted integer NOT NULL,
	udfoerer_entrep character varying(50),
	kommunal_kontakt character varying(150),
	anlaegsaar date,
	hoejde numeric(10,2) NOT NULL,
	bredde numeric(10,2) NOT NULL,
	tilstand_kode integer NOT NULL,
	litra character varying(128),
	note character varying(254),
	vejkode integer,
	link character varying(1024),
	geometri public.geometry(MultiLineString,25832) NOT NULL,
	CONSTRAINT t_greg_linier_pk PRIMARY KEY (versions_id) WITH (fillfactor='10')
);

COMMENT ON TABLE greg_history.t_greg_linier IS 'Historik tilknyttet linier';


CREATE TABLE greg_history.t_greg_punkter (
	versions_id uuid NOT NULL,
	objekt_id uuid NOT NULL,
	systid_fra timestamp with time zone NOT NULL,
	systid_til timestamp with time zone NOT NULL,
	oprettet timestamp with time zone NOT NULL,
	cvr_kode integer NOT NULL,
	bruger_id character varying(128) NOT NULL,
	oprindkode integer NOT NULL,
	statuskode integer NOT NULL,
	off_kode integer NOT NULL,
	underelement_kode character varying(9) NOT NULL,
	arbejdssted integer NOT NULL,
	udfoerer_entrep character varying(50),
	kommunal_kontakt character varying(150),
	anlaegsaar date,
	diameter numeric(10,2) NOT NULL,
	hoejde numeric(10,2) NOT NULL,
	tilstand_kode integer NOT NULL,
	litra character varying(128),
	note character varying(254),
	vejkode integer,
	slaegt character varying(50),
	art character varying(50),
	link character varying(1024),
	geometri public.geometry(MultiPoint,25832) NOT NULL,
	CONSTRAINT t_greg_punkter_pk PRIMARY KEY (versions_id) WITH (fillfactor='10')
);

COMMENT ON TABLE greg_history.t_greg_punkter IS 'Historik tilknyttet punkter';


CREATE TABLE greg_history.t_skitse_fl (
	versions_id uuid NOT NULL,
	objekt_id uuid NOT NULL,
	systid_fra timestamp with time zone NOT NULL,
	systid_til timestamp with time zone NOT NULL,
	oprettet timestamp with time zone NOT NULL,
	bruger_id character varying(128) NOT NULL,
	note character varying(254),
	geometri public.geometry(MultiPolygon,25832) NOT NULL,
	CONSTRAINT t_skitse_fl_pk PRIMARY KEY (versions_id) WITH (fillfactor='10')
);

COMMENT ON TABLE greg_history.t_skitse_fl IS 'Historik tilknyttet flader (Skitser)';


CREATE TABLE greg_history.t_skitse_li (
	versions_id uuid NOT NULL,
	objekt_id uuid NOT NULL,
	systid_fra timestamp with time zone NOT NULL,
	systid_til timestamp with time zone NOT NULL,
	oprettet timestamp with time zone NOT NULL,
	bruger_id character varying(128) NOT NULL,
	note character varying(254),
	geometri public.geometry(MultiLineString,25832) NOT NULL,
	CONSTRAINT t_skitse_li_pk PRIMARY KEY (versions_id) WITH (fillfactor='10')
);

COMMENT ON TABLE greg_history.t_skitse_li IS 'Historik tilknyttet linier (Skitser)';


CREATE TABLE greg_history.t_skitse_pkt (
	versions_id uuid NOT NULL,
	objekt_id uuid NOT NULL,
	systid_fra timestamp with time zone NOT NULL,
	systid_til timestamp with time zone NOT NULL,
	oprettet timestamp with time zone NOT NULL,
	bruger_id character varying(128) NOT NULL,
	note character varying(254),
	geometri public.geometry(MultiPoint,25832) NOT NULL,
	CONSTRAINT t_skitse_pkt_pk PRIMARY KEY (versions_id) WITH (fillfactor='10')
);

COMMENT ON TABLE greg_history.t_skitse_pkt IS 'Historik tilknyttet punkter (Skitser)';

--
-- Search path
--

SET search_path = greg, pg_catalog;

--
-- CREATE VIEW (Updateable views)
--

CREATE VIEW greg.v_greg_flader AS

SELECT
	a.versions_id,
	a.objekt_id,
	a.systid_fra,
	a.oprettet,
	a.cvr_kode,
	b.cvr_navn,
	a.bruger_id,
	c.navn AS bruger,
	a.oprindkode,
	d.oprindelse,
	a.statuskode,
	e.status,
	a.off_kode,
	f.offentlig,
	m.hovedelement_kode,
	m.hovedelement_tekst,
	l.element_kode,
	l.element_tekst,
	a.underelement_kode,
	g.underelement_tekst,
	a.arbejdssted,
	h.pg_distrikt_tekst,
	a.udfoerer_entrep,
	a.kommunal_kontakt,
	i.navn || ', tlf: ' || i.telefon AS kommunal_kontakt_info,
	a.anlaegsaar,
	a.klip_sider,
	a.hoejde,
	CASE
		WHEN LEFT(a.underelement_kode,2) LIKE 'HÆ'
		THEN (public.ST_Area(a.geometri) + a.klip_sider * a.hoejde * public.ST_Perimeter(a.geometri) /2)::numeric(10,2)
		ELSE NULL
	END AS klip_flade,
	a.tilstand_kode,
	j.tilstand,
	a.litra,
	a.note,
	a.vejkode,
	k.vejnavn,
	a.link,
	public.ST_Area(a.geometri)::numeric(10,2) AS areal,
	public.ST_Perimeter(a.geometri)::numeric(10,2) AS omkreds,
	CASE
		WHEN g.enhedspris = 0 AND g.enhedspris_klip = 0
		THEN NULL
		WHEN LEFT(a.underelement_kode,2) LIKE 'HÆ'
		THEN (g.enhedspris * public.ST_Area(a.geometri) + g.enhedspris_klip * (public.ST_Area(a.geometri) + a.klip_sider * a.hoejde * public.ST_Perimeter(a.geometri) /2))::numeric(10,2)
		ELSE (g.enhedspris * public.ST_Area(a.geometri))::numeric(10,2)
	END AS element_pris,
	h.aktiv,
	a.geometri
FROM greg.t_greg_flader a
LEFT JOIN greg.d_basis_ansvarlig_myndighed b ON a.cvr_kode = b.cvr_kode
LEFT JOIN greg.d_basis_bruger_id c ON a.bruger_id = c.bruger_id
LEFT JOIN greg.d_basis_oprindelse d ON a.oprindkode = d.oprindkode
LEFT JOIN greg.d_basis_status e ON a.statuskode = e.statuskode
LEFT JOIN greg.d_basis_offentlig f ON a.off_kode = f.off_kode
LEFT JOIN greg.d_basis_underelementer g ON a.underelement_kode = g.underelement_kode
LEFT JOIN greg.t_greg_omraader h ON a.arbejdssted = h.pg_distrikt_nr
LEFT JOIN greg.d_basis_kommunal_kontakt i ON a.kommunal_kontakt = i.email
LEFT JOIN greg.d_basis_tilstand j ON a.tilstand_kode = j.tilstand_kode
LEFT JOIN greg.d_basis_vejnavn k ON a.vejkode = k.vejkode
LEFT JOIN greg.d_basis_elementer l ON g.element_kode = l.element_kode
LEFT JOIN greg.d_basis_hovedelementer m ON l.hovedelement_kode = m.hovedelement_kode

ORDER BY a.arbejdssted, a.underelement_kode;

COMMENT ON VIEW greg.v_greg_flader IS 'Opdatérbar view for greg.t_greg_flader';


CREATE VIEW greg.v_greg_linier AS

SELECT
	a.versions_id,
	a.objekt_id,
	a.systid_fra,
	a.oprettet,
	a.cvr_kode,
	b.cvr_navn,
	a.bruger_id,
	c.navn AS bruger,
	a.oprindkode,
	d.oprindelse,
	a.statuskode,
	e.status,
	a.off_kode,
	f.offentlig,
	m.hovedelement_kode,
	m.hovedelement_tekst,
	l.element_kode,
	l.element_tekst,
	a.underelement_kode,
	g.underelement_tekst,
	a.arbejdssted,
	h.pg_distrikt_tekst,
	a.udfoerer_entrep,
	a.kommunal_kontakt,
	i.navn || ', tlf: ' || i.telefon AS kommunal_kontakt_info,
	a.anlaegsaar,
	a.hoejde,
	public.ST_Length(a.geometri)::numeric(10,2) AS laengde,
	a.bredde,
	CASE
		WHEN a.underelement_kode = 'BL-05-02'
		THEN (public.ST_Length(a.geometri) * a.hoejde)::numeric(10,2)
		ELSE NULL
	END AS klip_flade,
	a.tilstand_kode,
	j.tilstand,
	a.litra,
	a.note,
	a.vejkode,
	k.vejnavn,
	a.link,
	CASE
		WHEN g.enhedspris = 0 AND g.enhedspris_klip = 0
		THEN NULL
		WHEN a.underelement_kode = 'BL-05-02'
		THEN (g.enhedspris * public.ST_Length(a.geometri) + g.enhedspris_klip * (public.ST_Length(a.geometri) * a.hoejde))::numeric(10,2)
		ELSE (g.enhedspris * public.ST_Length(a.geometri))::numeric(10,2)
	END AS element_pris,
	h.aktiv,
	a.geometri
FROM greg.t_greg_linier a
LEFT JOIN greg.d_basis_ansvarlig_myndighed b ON a.cvr_kode = b.cvr_kode
LEFT JOIN greg.d_basis_bruger_id c ON a.bruger_id = c.bruger_id
LEFT JOIN greg.d_basis_oprindelse d ON a.oprindkode = d.oprindkode
LEFT JOIN greg.d_basis_status e ON a.statuskode = e.statuskode
LEFT JOIN greg.d_basis_offentlig f ON a.off_kode = f.off_kode
LEFT JOIN greg.d_basis_underelementer g ON a.underelement_kode = g.underelement_kode
LEFT JOIN greg.t_greg_omraader h ON a.arbejdssted = h.pg_distrikt_nr
LEFT JOIN greg.d_basis_kommunal_kontakt i ON a.kommunal_kontakt = i.email
LEFT JOIN greg.d_basis_tilstand j ON a.tilstand_kode = j.tilstand_kode
LEFT JOIN greg.d_basis_vejnavn k ON a.vejkode = k.vejkode
LEFT JOIN greg.d_basis_elementer l ON g.element_kode = l.element_kode
LEFT JOIN greg.d_basis_hovedelementer m ON l.hovedelement_kode = m.hovedelement_kode

ORDER BY a.arbejdssted, a.underelement_kode;

COMMENT ON VIEW greg.v_greg_linier IS 'Opdatérbar view for greg.t_greg_linier';


CREATE VIEW greg.v_greg_omraadeliste AS

SELECT
	a.objekt_id,
	a.bruger_id,
	b.navn AS bruger,
	a.pg_distrikt_nr,
	a.pg_distrikt_tekst,
	a.pg_distrikt_type,
	a.udfoerer,
	a.udfoerer_kontakt1,
	c.navn || ', tlf: ' || c.telefon AS udfoerer_kontakt1_info,
	a.udfoerer_kontakt2,
	d.navn || ', tlf: ' || d.telefon AS udfoerer_kontakt2_info,
	a.kommunal_kontakt,
	e.navn || ', tlf: ' || e.telefon AS kommunal_kontakt_info,
	a.vejkode,
	f.vejnavn,
	a.vejnr,
	a.postnr,
	g.distriktnavn AS distrikt,
	a.note,
	a.link,
	a.aktiv
FROM greg.t_greg_omraader a
LEFT JOIN greg.d_basis_bruger_id b ON a.bruger_id = b.bruger_id
LEFT JOIN greg.d_basis_udfoerer_kontakt c ON a.udfoerer_kontakt1 = c.email
LEFT JOIN greg.d_basis_udfoerer_kontakt d ON a.udfoerer_kontakt2 = d.email
LEFT JOIN greg.d_basis_kommunal_kontakt e ON a.kommunal_kontakt = e.email
LEFT JOIN greg.d_basis_vejnavn f ON a.vejkode = f.vejkode
LEFT JOIN greg.d_basis_postdistrikter g ON a.postnr = g.postnr

ORDER BY a.pg_distrikt_nr;

COMMENT ON VIEW greg.v_greg_omraadeliste IS 'Opdatérbar view for greg.t_greg_omraader, dog uden tilknyttet geometri';


CREATE VIEW greg.v_greg_omraader AS

SELECT
	a.objekt_id,
	a.bruger_id,
	b.navn AS bruger,
	a.pg_distrikt_nr,
	a.pg_distrikt_tekst,
	a.pg_distrikt_type,
	a.udfoerer,
	a.udfoerer_kontakt1,
	c.navn || ', tlf: ' || c.telefon AS udfoerer_kontakt1_info,
	a.udfoerer_kontakt2,
	d.navn || ', tlf: ' || d.telefon AS udfoerer_kontakt2_info,
	a.kommunal_kontakt,
	e.navn || ', tlf: ' || e.telefon AS kommunal_kontakt_info,
	a.vejkode,
	f.vejnavn,
	a.vejnr,
	a.postnr,
	g.distriktnavn AS distrikt,
	a.note,
	a.link,
	public.ST_Area(a.geometri)::numeric(10,2) AS areal,
	a.aktiv,
	a.geometri
FROM greg.t_greg_omraader a
LEFT JOIN greg.d_basis_bruger_id b ON a.bruger_id = b.bruger_id
LEFT JOIN greg.d_basis_udfoerer_kontakt c ON a.udfoerer_kontakt1 = c.email
LEFT JOIN greg.d_basis_udfoerer_kontakt d ON a.udfoerer_kontakt2 = d.email
LEFT JOIN greg.d_basis_kommunal_kontakt e ON a.kommunal_kontakt = e.email
LEFT JOIN greg.d_basis_vejnavn f ON a.vejkode = f.vejkode
LEFT JOIN greg.d_basis_postdistrikter g ON a.postnr = g.postnr
WHERE a.pg_distrikt_type NOT IN('Vejarealer') AND a.geometri IS NOT NULL

ORDER BY a.pg_distrikt_nr;

COMMENT ON VIEW greg.v_greg_omraader IS 'Opdatérbar view for greg.t_greg_omraader';


CREATE VIEW greg.v_greg_punkter AS

SELECT
	a.versions_id,
	a.objekt_id,
	a.systid_fra,
	a.oprettet,
	a.cvr_kode,
	b.cvr_navn,
	a.bruger_id,
	c.navn AS bruger,
	a.oprindkode,
	d.oprindelse,
	a.statuskode,
	e.status,
	a.off_kode,
	f.offentlig,
	m.hovedelement_kode,
	m.hovedelement_tekst,
	l.element_kode,
	l.element_tekst,
	a.underelement_kode,
	g.underelement_tekst,
	a.arbejdssted,
	h.pg_distrikt_tekst,
	a.udfoerer_entrep,
	a.kommunal_kontakt,
	i.navn || ', tlf: ' || i.telefon AS kommunal_kontakt_info,
	a.anlaegsaar,
	a.diameter,
	a.hoejde,
	a.tilstand_kode,
	j.tilstand,
	a.litra,
	a.note,
	a.vejkode,
	k.vejnavn,
	a.slaegt,
	a.art,
	a.link,
	CASE
	WHEN g.enhedspris = 0
	THEN NULL
	WHEN m.hovedelement_kode = 'REN'
	THEN (g.enhedspris * n.areal)::numeric(10,2)
	ELSE g.enhedspris
	END AS element_pris,
	h.aktiv,
	a.geometri
FROM greg.t_greg_punkter a
LEFT JOIN greg.d_basis_ansvarlig_myndighed b ON a.cvr_kode = b.cvr_kode
LEFT JOIN greg.d_basis_bruger_id c ON a.bruger_id = c.bruger_id
LEFT JOIN greg.d_basis_oprindelse d ON a.oprindkode = d.oprindkode
LEFT JOIN greg.d_basis_status e ON a.statuskode = e.statuskode
LEFT JOIN greg.d_basis_offentlig f ON a.off_kode = f.off_kode
LEFT JOIN greg.d_basis_underelementer g ON a.underelement_kode = g.underelement_kode
LEFT JOIN greg.t_greg_omraader h ON a.arbejdssted = h.pg_distrikt_nr
LEFT JOIN greg.d_basis_kommunal_kontakt i ON a.kommunal_kontakt = i.email
LEFT JOIN greg.d_basis_tilstand j ON a.tilstand_kode = j.tilstand_kode
LEFT JOIN greg.d_basis_vejnavn k ON a.vejkode = k.vejkode
LEFT JOIN greg.d_basis_elementer l ON g.element_kode = l.element_kode
LEFT JOIN greg.d_basis_hovedelementer m ON l.hovedelement_kode = m.hovedelement_kode
LEFT JOIN (SELECT	arbejdssted,
					SUM(public.ST_Area(geometri)) AS areal
				FROM greg.t_greg_flader
				WHERE LEFT(underelement_kode, 3) NOT IN('ANA', 'VA-')
				GROUP BY arbejdssted) n
		ON h.pg_distrikt_nr = n.arbejdssted

ORDER BY a.arbejdssted, a.underelement_kode;

COMMENT ON VIEW greg.v_greg_punkter IS 'Opdatérbar view for greg.t_greg_punkter';

--
-- CREATE VIEW (Miscellaneous)
--

CREATE VIEW greg.v_atlas AS

SELECT
	a.objekt_id,
	'Område' AS omraadetype,
	a.pg_distrikt_nr,
	a.pg_distrikt_tekst,
	NULL AS delnavn,
	a.pg_distrikt_type,
	NULL AS delomraade,
	NULL AS delomraade_total,
	b.vejnavn,
	a.vejnr,
	a.postnr,
	c.distriktnavn,
	a.geometri
FROM greg.t_greg_omraader a
LEFT JOIN greg.d_basis_vejnavn b ON a.vejkode = b.vejkode
LEFT JOIN greg.d_basis_postdistrikter c ON a.postnr = c.postnr
WHERE a.aktiv = 1 AND pg_distrikt_nr NOT IN(SELECT pg_distrikt_nr FROM greg.t_greg_delomraader) AND pg_distrikt_type NOT IN('Vejarealer') AND a.geometri IS NOT NULL

UNION

SELECT
	a.objekt_id,
	'Delområde' AS omraadetype,
	a.pg_distrikt_nr,
	d.pg_distrikt_tekst,
	a.delnavn,
	d.pg_distrikt_type,
	a.delomraade,
	e.delomraade_total,
	b.vejnavn,
	d.vejnr,
	d.postnr,
	c.distriktnavn,
	a.geometri
FROM greg.t_greg_delomraader a
LEFT JOIN greg.t_greg_omraader d ON a.pg_distrikt_nr = d.pg_distrikt_nr
LEFT JOIN greg.d_basis_vejnavn b ON d.vejkode = b.vejkode
LEFT JOIN greg.d_basis_postdistrikter c ON d.postnr = c.postnr
LEFT JOIN (SELECT
			pg_distrikt_nr,
				COUNT(pg_distrikt_nr) AS delomraade_total
			FROM greg.t_greg_delomraader
			GROUP BY pg_distrikt_nr) e
		ON a.pg_distrikt_nr = e.pg_distrikt_nr
WHERE d.aktiv = 1

ORDER BY pg_distrikt_nr, delomraade;

COMMENT ON VIEW greg.v_atlas IS 'Samlet områdetabel på baggrund af områder og delområder';



CREATE VIEW greg.v_basis_kommunal_kontakt AS

SELECT

email,
navn || ', tlf: ' || telefon || ', ' || email as samling

FROM greg.d_basis_kommunal_kontakt
WHERE aktiv = 1;

COMMENT ON VIEW greg.v_basis_kommunal_kontakt IS 'Look-up for d_basis_kommunal_kontakt';



CREATE VIEW greg.v_basis_postdistrikter AS

SELECT

postnr,
postnr || ' ' || distriktnavn as distriktnavn

FROM greg.d_basis_postdistrikter
WHERE aktiv = 1;

COMMENT ON VIEW greg.v_basis_postdistrikter IS 'Look-up for d_basis_postdistrikter';



CREATE VIEW greg.v_basis_udfoerer_kontakt AS

SELECT

email,
udfoerer|| ', '|| navn || ', tlf: ' || telefon || ', ' || email as samling

FROM greg.d_basis_udfoerer_kontakt
WHERE aktiv = 1;

COMMENT ON VIEW greg.v_basis_udfoerer_kontakt IS 'Look-up for d_basis_udfoerer_kontakt';



CREATE VIEW greg.v_basis_hovedelementer AS

SELECT

a.hovedelement_kode,
a.hovedelement_kode || ' - ' || a.hovedelement_tekst AS hovedelement_tekst,
string_agg(distinct(c.objekt_type), '') AS objekt_type

FROM greg.d_basis_hovedelementer a
LEFT JOIN greg.d_basis_elementer b ON a.hovedelement_kode = b.hovedelement_kode
LEFT JOIN greg.d_basis_underelementer c ON b.element_kode = c.element_kode
WHERE a.aktiv = 1
GROUP BY a.hovedelement_kode, a.hovedelement_tekst

ORDER BY a.hovedelement_kode;

COMMENT ON VIEW greg.v_basis_hovedelementer IS 'Look-up for d_basis_hovedelementer';



CREATE VIEW greg.v_basis_elementer AS

SELECT

a.hovedelement_kode,
a.element_kode,
a.element_kode || ' ' || a.element_tekst AS element_tekst,
string_agg(DISTINCT(b.objekt_type), '') AS objekt_type

FROM greg.d_basis_elementer a
LEFT JOIN greg.d_basis_underelementer b ON a.element_kode = b.element_kode
LEFT JOIN greg.d_basis_hovedelementer c ON a.hovedelement_kode = c.hovedelement_kode
WHERE a.aktiv = 1 AND c.aktiv = 1
GROUP BY a.element_kode, element_tekst

ORDER BY a.element_kode;

COMMENT ON VIEW greg.v_basis_elementer IS 'Look-up for d_basis_elementer';



CREATE VIEW greg.v_basis_underelementer AS

SELECT

a.element_kode,
a.underelement_kode,
a.underelement_kode || ' ' || a.underelement_tekst AS element_tekst,
a.objekt_type

FROM greg.d_basis_underelementer a
LEFT JOIN greg.d_basis_elementer b ON a.element_kode = b.element_kode
LEFT JOIN greg.d_basis_hovedelementer c ON b.hovedelement_kode = c.hovedelement_kode
WHERE a.aktiv = 1 AND b.aktiv = 1 AND c.aktiv = 1

ORDER BY a.underelement_kode;

COMMENT ON VIEW greg.v_basis_underelementer IS 'Look-up for d_basis_underelementer';



CREATE VIEW greg.v_oversigt_omraade AS

SELECT
	a.pg_distrikt_nr as omraadenr,
	a.pg_distrikt_nr || ' ' || a.pg_distrikt_tekst AS omraade,
	a.pg_distrikt_type AS arealtype,
	CASE
		WHEN a.vejnr IS NOT NULL
		THEN b.vejnavn || ' ' || a.vejnr || ' - ' || a.postnr || ' ' || c.distriktnavn
		WHEN a.vejkode IS NOT NULL
		THEN b.vejnavn || ' - ' || a.postnr || ' ' || c.distriktnavn
		ELSE a.postnr || ' ' || c.distriktnavn
	END AS adresse,
	public.ST_Area(a.geometri) AS areal
FROM greg.t_greg_omraader a
LEFT JOIN greg.d_basis_vejnavn b ON a.vejkode = b.vejkode
LEFT JOIN greg.d_basis_postdistrikter c ON a.postnr = c.postnr
WHERE a.aktiv = 1

ORDER BY a.pg_distrikt_nr;

COMMENT ON VIEW greg.v_oversigt_omraade IS 'Look-up for aktive områder (QGIS + Excel)';

--
-- CREATE INDEX
--

CREATE INDEX t_greg_flader_gist ON greg.t_greg_flader USING gist (geometri);



CREATE INDEX t_greg_linier_gist ON greg.t_greg_linier USING gist (geometri);



CREATE INDEX t_greg_omraader_gist ON greg.t_greg_omraader USING gist (geometri);



CREATE INDEX t_greg_punkter_gist ON greg.t_greg_punkter USING gist (geometri);



CREATE INDEX t_skitse_fl_gist ON greg.t_skitse_fl USING gist (geometri);



CREATE INDEX t_skitse_li_gist ON greg.t_skitse_li USING gist (geometri);



CREATE INDEX t_skitse_pkt_gist ON greg.t_skitse_pkt USING gist (geometri);

--
-- Search Path
--

SET search_path = greg_history, pg_catalog;

--
-- CREATE INDEX
--

CREATE INDEX t_greg_flader_gist ON greg_history.t_greg_flader USING gist (geometri);



CREATE INDEX t_greg_linier_gist ON greg_history.t_greg_linier USING gist (geometri);



CREATE INDEX t_greg_punkter_gist ON greg_history.t_greg_punkter USING gist (geometri);



CREATE INDEX t_skitse_fl_gist ON greg_history.t_skitse_fl USING gist (geometri);



CREATE INDEX t_skitse_li_gist ON greg_history.t_skitse_li USING gist (geometri);



CREATE INDEX t_skitse_pkt_gist ON greg_history.t_skitse_pkt USING gist (geometri);

--
-- Search Path
--

SET search_path = greg, pg_catalog;

--
-- CREATE TRIGGER
--

CREATE TRIGGER t_greg_delomraader_trg_iu BEFORE INSERT OR UPDATE ON greg.t_greg_delomraader FOR EACH ROW EXECUTE PROCEDURE greg.t_greg_delomraader_trg();


CREATE TRIGGER t_greg_flader_trg_iud BEFORE INSERT OR DELETE OR UPDATE ON greg.t_greg_flader FOR EACH ROW EXECUTE PROCEDURE greg.t_greg_flader_trg();


CREATE TRIGGER t_greg_linier_trg_iud BEFORE INSERT OR DELETE OR UPDATE ON greg.t_greg_linier FOR EACH ROW EXECUTE PROCEDURE greg.t_greg_linier_trg();


CREATE TRIGGER t_greg_omraader_flader_trg_a_iud AFTER INSERT OR DELETE OR UPDATE ON greg.t_greg_flader FOR EACH ROW EXECUTE PROCEDURE greg.t_greg_omraader_flader_trg();


CREATE TRIGGER t_greg_omraader_trg_iu BEFORE INSERT OR UPDATE ON greg.t_greg_omraader FOR EACH ROW EXECUTE PROCEDURE greg.t_greg_omraader_trg();


CREATE TRIGGER t_greg_punkter_trg_iud BEFORE INSERT OR DELETE OR UPDATE ON greg.t_greg_punkter FOR EACH ROW EXECUTE PROCEDURE greg.t_greg_punkter_trg();


CREATE TRIGGER t_skitse_fl_trg_iud BEFORE INSERT OR DELETE OR UPDATE ON greg.t_skitse_fl FOR EACH ROW EXECUTE PROCEDURE greg.t_skitse_fl_trg();


CREATE TRIGGER t_skitse_li_trg_iud BEFORE INSERT OR DELETE OR UPDATE ON greg.t_skitse_li FOR EACH ROW EXECUTE PROCEDURE greg.t_skitse_li_trg();


CREATE TRIGGER t_skitse_pkt_trg_iud BEFORE INSERT OR DELETE OR UPDATE ON greg.t_skitse_pkt FOR EACH ROW EXECUTE PROCEDURE greg.t_skitse_pkt_trg();


CREATE TRIGGER v_greg_flader_trg_iud INSTEAD OF INSERT OR DELETE OR UPDATE ON greg.v_greg_flader FOR EACH ROW EXECUTE PROCEDURE greg.v_greg_flader_trg();


CREATE TRIGGER v_greg_linier_trg_iud INSTEAD OF INSERT OR DELETE OR UPDATE ON greg.v_greg_linier FOR EACH ROW EXECUTE PROCEDURE greg.v_greg_linier_trg();


CREATE TRIGGER v_greg_omraadeliste_trg_iud INSTEAD OF INSERT OR DELETE OR UPDATE ON greg.v_greg_omraadeliste FOR EACH ROW EXECUTE PROCEDURE greg.v_greg_omraadeliste_trg();


CREATE TRIGGER v_greg_omraader_trg_iud INSTEAD OF INSERT OR DELETE OR UPDATE ON greg.v_greg_omraader FOR EACH ROW EXECUTE PROCEDURE greg.v_greg_omraader_trg();


CREATE TRIGGER v_greg_punkter_trg_iud INSTEAD OF INSERT OR DELETE OR UPDATE ON greg.v_greg_punkter FOR EACH ROW EXECUTE PROCEDURE greg.v_greg_punkter_trg();

--
-- INSERT INTO
--

--
-- d_basis_ansvarlig_myndighed
--

INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (66137112, 'Albertslund Kommune', 165, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (60183112, 'Allerød Kommune', 201, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189692, 'Assens Kommune', 420, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (58271713, 'Ballerup Kommune', 151, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189765, 'Billund Kommune', 530, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (26696348, 'Bornholms Regionskommune', 400, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (65113015, 'Brøndby Kommune', 153, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189501, 'Brønderslev Kommune', 810, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (25775635, 'Christiansø', 411, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (12881517, 'Dragør Kommune', 155, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29188386, 'Egedal Kommune', 240, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189803, 'Esbjerg Kommune', 561, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (31210917, 'Fanø Kommune', 563, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189714, 'Favrskov Kommune', 710, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29188475, 'Faxe Kommune', 320, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29188335, 'Fredensborg Kommune', 210, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (69116418, 'Fredericia Kommune', 607, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (11259979, 'Frederiksberg Kommune', 147, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189498, 'Frederikshavn Kommune', 813, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189129, 'Frederikssund Kommune', 250, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29188327, 'Furesø Kommune', 190, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29188645, 'Faaborg-Midtfyn Kommune', 430, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (19438414, 'Gentofte Kommune', 157, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (62761113, 'Gladsaxe Kommune', 159, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (65120119, 'Glostrup Kommune', 161, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (44023911, 'Greve Kommune', 253, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29188440, 'Gribskov Kommune', 270, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29188599, 'Guldborgsund Kommune', 376, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189757, 'Haderslev Kommune', 510, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29188416, 'Halsnæs Kommune', 260, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189587, 'Hedensted Kommune', 766, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (64502018, 'Helsingør Kommune', 217, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (63640719, 'Herlev Kommune', 163, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189919, 'Herning Kommune', 657, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189366, 'Hillerød Kommune', 219, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189382, 'Hjørring Kommune', 860, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189447, 'Holbæk Kommune', 316, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189927, 'Holstebro Kommune', 661, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189889, 'Horsens Kommune', 615, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (55606617, 'Hvidovre Kommune', 167, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (19501817, 'Høje-Taastrup Kommune', 169, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (70960516, 'Hørsholm Kommune', 223, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189617, 'Ikast-Brande Kommune', 756, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (11931316, 'Ishøj Kommune', 183, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189439, 'Jammerbugt Kommune', 849, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189595, 'Kalundborg Kommune', 326, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189706, 'Kerteminde Kommune', 440, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189897, 'Kolding Kommune', 621, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (64942212, 'Københavns Kommune', 101, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189374, 'Køge Kommune', 259, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29188955, 'Langeland Kommune', 482, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29188548, 'Lejre Kommune', 350, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189935, 'Lemvig Kommune', 665, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29188572, 'Lolland Kommune', 360, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (11715311, 'Lyngby-Taarbæk Kommune', 173, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (45973328, 'Læsø Kommune', 825, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189455, 'Mariagerfjord Kommune', 846, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189684, 'Middelfart Kommune', 410, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (41333014, 'Morsø Kommune', 773, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189986, 'Norddjurs Kommune', 707, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29188947, 'Nordfyns Kommune', 480, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189722, 'Nyborg Kommune', 450, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189625, 'Næstved Kommune', 370, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (32264328, 'Odder Kommune', 727, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (35209115, 'Odense Kommune', 461, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29188459, 'Odsherred Kommune', 306, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189668, 'Randers Kommune', 730, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189463, 'Rebild Kommune', 840, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189609, 'Ringkøbing-Skjern Kommune', 760, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (18957981, 'Ringsted Kommune', 329, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189404, 'Roskilde Kommune', 265, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29188378, 'Rudersdal Kommune', 230, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (65307316, 'Rødovre Kommune', 175, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (23795515, 'Samsø Kommune', 741, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189641, 'Silkeborg Kommune', 740, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189633, 'Skanderborg Kommune', 746, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189579, 'Skive Kommune', 779, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29188505, 'Slagelse Kommune', 330, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (68534917, 'Solrød Kommune', 269, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189994, 'Sorø Kommune', 340, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29208654, 'Stevns Kommune', 336, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189951, 'Struer Kommune', 671, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189730, 'Svendborg Kommune', 479, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189978, 'Syddjurs Kommune', 706, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189773, 'Sønderborg Kommune', 540, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189560, 'Thisted Kommune', 787, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189781, 'Tønder Kommune', 550, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (20310413, 'Tårnby Kommune', 185, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (19583910, 'Vallensbæk Kommune', 187, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189811, 'Varde Kommune', 573, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189838, 'Vejen Kommune', 575, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189900, 'Vejle Kommune', 630, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189471, 'Vesthimmerlands Kommune', 820, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189846, 'Viborg Kommune', 791, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189676, 'Vordingborg Kommune', 390, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (28856075, 'Ærø Kommune', 492, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189854, 'Aabenraa Kommune', 580, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (29189420, 'Aalborg Kommune', 851, 1);
INSERT INTO greg.d_basis_ansvarlig_myndighed VALUES (55133018, 'Aarhus Kommune', 751, 1);

--
-- d_basis_offentlig
--

INSERT INTO greg.d_basis_offentlig VALUES (1, 'Synlig for alle', 1);
INSERT INTO greg.d_basis_offentlig VALUES (2, 'Synlig for den ansvarlige myndighed', 1);
INSERT INTO greg.d_basis_offentlig VALUES (3, 'Synlig for alle myndigheder, men ikke offentligheden', 1);

--
-- d_basis_oprindelse
--

INSERT INTO greg.d_basis_oprindelse VALUES (0, 'Ikke udfyldt', 1, NULL);
INSERT INTO greg.d_basis_oprindelse VALUES (1, 'Ortofoto', 1, 'Der skelnes ikke mellem forskellige producenter og forskellige årgange');
INSERT INTO greg.d_basis_oprindelse VALUES (2, 'Matrikelkort', 1, 'Matrikelkort fra KMS (København og Frederiksberg). Det forudsættes, at der benyttes opdaterede matrikelkort for datoen for planens indberetning');
INSERT INTO greg.d_basis_oprindelse VALUES (3, 'Opmåling', 1, 'Kan være med GPS, andet instrument el. lign. Det er ikke et udtryk for præcisi-on, men at det er udført i marken');
INSERT INTO greg.d_basis_oprindelse VALUES (4, 'FOT / Tekniske kort', 1, 'FOT, DTK, Danmarks Topografisk kortværk eller andre raster kort samt kommunernes tekniske kort eller andre vektorkort. Indtil FOT er landsdækkende benyttes kort10 (jf. overgangsregler for FOT)');
INSERT INTO greg.d_basis_oprindelse VALUES (5, 'Modelberegning', 1, 'GIS analyser eller modellering');
INSERT INTO greg.d_basis_oprindelse VALUES (6, 'Tegning', 1, 'Digitaliseret på baggrund af PDF, billede eller andet tegningsmateriale');
INSERT INTO greg.d_basis_oprindelse VALUES (7, 'Felt-/markbesøg', 1, 'Registrering på baggrund af tilsyn i marken');
INSERT INTO greg.d_basis_oprindelse VALUES (8, 'Borgeranmeldelse', 1, 'Indberetning via diverse borgerløsninger – eks. "Giv et praj"');
INSERT INTO greg.d_basis_oprindelse VALUES (9, 'Luftfoto (historiske 1944-1993)', 1, 'Luftfoto er kendetegnet ved ikke at have samme nøjagtighed i georeferingen, men man kan se en del ting, der ikke er på de nuværende ortofoto.');
INSERT INTO greg.d_basis_oprindelse VALUES (10, 'Skråfoto', 1, 'Luftfoto tager fra de 4 verdenshjørner');
INSERT INTO greg.d_basis_oprindelse VALUES (11, 'Andre foto', 1, 'Foto taget i jordhøjde - "terræn foto" (street-view, sagsbehandlerfotos, borgerfotos m.v.). Her er det meget tydeligt at se de enkelte detaljer, men også her kan man normalt ikke direkte placere et punkt via fotoet, men må over at gøre det via noget andet.');
INSERT INTO greg.d_basis_oprindelse VALUES (12, '3D', 1, 'Laserscanning, Digital terrænmodel (DTM) afledninger, termografiske målinger (bestemmelse af temperaturforskelle) o.lign.');

--
-- d_basis_status
--

INSERT INTO greg.d_basis_status VALUES (0, 'Ukendt', 1);
INSERT INTO greg.d_basis_status VALUES (1, 'Kladde', 1);
INSERT INTO greg.d_basis_status VALUES (2, 'Forslag', 1);
INSERT INTO greg.d_basis_status VALUES (3, 'Gældende / Vedtaget', 1);
INSERT INTO greg.d_basis_status VALUES (4, 'Ikke gældende / Aflyst', 1);

--
-- d_basis_tilstand
--

INSERT INTO greg.d_basis_tilstand VALUES (1, 'Dårlig', 1, 'Udskiftning eller vedligeholdelse tiltrængt/påkrævet. Fungerer ikke efter hensigten eller i fare for det sker inden for kort tid.');
INSERT INTO greg.d_basis_tilstand VALUES (2, 'Middel', 1, 'Fungerer efter hensigten, men kunne trænge til vedligeholdelse for at forlænge levetiden/funktionen');
INSERT INTO greg.d_basis_tilstand VALUES (3, 'God', 1, 'Tæt på lige så god som et nyt.');
INSERT INTO greg.d_basis_tilstand VALUES (8, 'Andet', 1, 'Anden tilstand end Dårlig, Middel, God eller Ukendt.');
INSERT INTO greg.d_basis_tilstand VALUES (9, 'Ukendt', 1, 'Mangler viden til at kunne udfylde værdien med Dårlig, Middel eller God.');

--
-- d_basis_pris_enhed
--

INSERT INTO greg.d_basis_pris_enhed VALUES ('kr/stk', 1);
INSERT INTO greg.d_basis_pris_enhed VALUES ('kr/lbm', 1);
INSERT INTO greg.d_basis_pris_enhed VALUES ('kr/m2', 1);

--
-- d_basis_bruger_id
--

INSERT INTO greg.d_basis_bruger_id VALUES ('postgres', 'Ikke angivet', 1);

--
-- d_basis_distrikt_type
--

INSERT INTO greg.d_basis_distrikt_type VALUES ('Grønne områder', 1);
INSERT INTO greg.d_basis_distrikt_type VALUES ('Vejarealer', 1);
INSERT INTO greg.d_basis_distrikt_type VALUES ('Administrative ejendomme', 1);
INSERT INTO greg.d_basis_distrikt_type VALUES ('Boldbaner', 1);
INSERT INTO greg.d_basis_distrikt_type VALUES ('Idræt', 1);
INSERT INTO greg.d_basis_distrikt_type VALUES ('Kultur og fritid', 1);
INSERT INTO greg.d_basis_distrikt_type VALUES ('Skoler', 1);
INSERT INTO greg.d_basis_distrikt_type VALUES ('Institutioner', 1);
INSERT INTO greg.d_basis_distrikt_type VALUES ('Familieafdelingen', 1);
INSERT INTO greg.d_basis_distrikt_type VALUES ('Dag- og døgntilbud', 1);
INSERT INTO greg.d_basis_distrikt_type VALUES ('Ældreboliger', 1);
INSERT INTO greg.d_basis_distrikt_type VALUES ('Kommunale ejendomme', 1);
INSERT INTO greg.d_basis_distrikt_type VALUES ('Uden for drift', 1);
INSERT INTO greg.d_basis_distrikt_type VALUES ('Ukendt', 1);

--
-- d_basis_hovedelementer
--

INSERT INTO greg.d_basis_hovedelementer VALUES ('GR', 'Græs', 1);
INSERT INTO greg.d_basis_hovedelementer VALUES ('BL', 'Blomster', 1);
INSERT INTO greg.d_basis_hovedelementer VALUES ('BU', 'Buske', 1);
INSERT INTO greg.d_basis_hovedelementer VALUES ('HÆ', 'Hække og hegn', 1);
INSERT INTO greg.d_basis_hovedelementer VALUES ('TR', 'Træer', 1);
INSERT INTO greg.d_basis_hovedelementer VALUES ('VA', 'Vand', 1);
INSERT INTO greg.d_basis_hovedelementer VALUES ('BE', 'Belægninger', 1);
INSERT INTO greg.d_basis_hovedelementer VALUES ('UD', 'Terrænudstyr', 1);
INSERT INTO greg.d_basis_hovedelementer VALUES ('ANA', 'Anden anvendelse', 1);
INSERT INTO greg.d_basis_hovedelementer VALUES ('REN', 'Renhold', 1);

--
-- d_basis_elementer
--

INSERT INTO greg.d_basis_elementer VALUES ('GR', 'GR-00', 'Græs', 1);
INSERT INTO greg.d_basis_elementer VALUES ('GR', 'GR-01', 'Brugsplæner', 1);
INSERT INTO greg.d_basis_elementer VALUES ('GR', 'GR-02', 'Græsflader', 1);
INSERT INTO greg.d_basis_elementer VALUES ('GR', 'GR-03', 'Sportsplæner', 1);
INSERT INTO greg.d_basis_elementer VALUES ('GR', 'GR-04', 'Fælledgræs', 1);
INSERT INTO greg.d_basis_elementer VALUES ('GR', 'GR-05', 'Rabatgræs', 1);
INSERT INTO greg.d_basis_elementer VALUES ('GR', 'GR-06', 'Naturgræs', 1);
INSERT INTO greg.d_basis_elementer VALUES ('GR', 'GR-07', 'Græsning', 1);
INSERT INTO greg.d_basis_elementer VALUES ('GR', 'GR-08', 'Strande og klitter', 1);
INSERT INTO greg.d_basis_elementer VALUES ('GR', 'GR-09', '§3 Områder', 1);
INSERT INTO greg.d_basis_elementer VALUES ('GR', 'GR-10', 'Særlige græsområder', 1);
INSERT INTO greg.d_basis_elementer VALUES ('BL', 'BL-00', 'Blomster', 1);
INSERT INTO greg.d_basis_elementer VALUES ('BL', 'BL-01', 'Sommerblomster', 1);
INSERT INTO greg.d_basis_elementer VALUES ('BL', 'BL-02', 'Ampler', 1);
INSERT INTO greg.d_basis_elementer VALUES ('BL', 'BL-03', 'Plantekummer', 1);
INSERT INTO greg.d_basis_elementer VALUES ('BL', 'BL-04', 'Roser og stauder', 1);
INSERT INTO greg.d_basis_elementer VALUES ('BL', 'BL-05', 'Klatreplanter', 1);
INSERT INTO greg.d_basis_elementer VALUES ('BL', 'BL-06', 'Urtehaver', 1);
INSERT INTO greg.d_basis_elementer VALUES ('BU', 'BU-00', 'Buske', 1);
INSERT INTO greg.d_basis_elementer VALUES ('BU', 'BU-01', 'Bunddækkende buske', 1);
INSERT INTO greg.d_basis_elementer VALUES ('BU', 'BU-02', 'Busketter', 1);
INSERT INTO greg.d_basis_elementer VALUES ('BU', 'BU-03', 'Krat og hegn', 1);
INSERT INTO greg.d_basis_elementer VALUES ('BU', 'BU-04', 'Bunddækkende krat', 1);
INSERT INTO greg.d_basis_elementer VALUES ('HÆ', 'HÆ-00', 'Hække', 1);
INSERT INTO greg.d_basis_elementer VALUES ('HÆ', 'HÆ-01', 'Hække og pur', 1);
INSERT INTO greg.d_basis_elementer VALUES ('HÆ', 'HÆ-02', 'Hækkekrat', 1);
INSERT INTO greg.d_basis_elementer VALUES ('TR', 'TR-00', 'Træer', 1);
INSERT INTO greg.d_basis_elementer VALUES ('TR', 'TR-01', 'Fritstående træer', 1);
INSERT INTO greg.d_basis_elementer VALUES ('TR', 'TR-02', 'Vejtræer', 1);
INSERT INTO greg.d_basis_elementer VALUES ('TR', 'TR-03', 'Trægrupper', 1);
INSERT INTO greg.d_basis_elementer VALUES ('TR', 'TR-04', 'Trærækker', 1);
INSERT INTO greg.d_basis_elementer VALUES ('TR', 'TR-05', 'Formede træer', 1);
INSERT INTO greg.d_basis_elementer VALUES ('TR', 'TR-06', 'Frugttræer', 1);
INSERT INTO greg.d_basis_elementer VALUES ('TR', 'TR-07', 'Alléer', 1);
INSERT INTO greg.d_basis_elementer VALUES ('TR', 'TR-08', 'Skove og lunde', 1);
INSERT INTO greg.d_basis_elementer VALUES ('TR', 'TR-09', 'Fælledskove', 1);
INSERT INTO greg.d_basis_elementer VALUES ('VA', 'VA-00', 'Vand', 1);
INSERT INTO greg.d_basis_elementer VALUES ('VA', 'VA-01', 'Bassiner', 1);
INSERT INTO greg.d_basis_elementer VALUES ('VA', 'VA-02', 'Vandhuller', 1);
INSERT INTO greg.d_basis_elementer VALUES ('VA', 'VA-03', 'Søer og gadekær', 1);
INSERT INTO greg.d_basis_elementer VALUES ('VA', 'VA-04', 'Vandløb', 1);
INSERT INTO greg.d_basis_elementer VALUES ('VA', 'VA-05', 'Rørskove', 1);
INSERT INTO greg.d_basis_elementer VALUES ('BE', 'BE-00', 'Belægninger', 1);
INSERT INTO greg.d_basis_elementer VALUES ('BE', 'BE-01', 'Faste belægninger', 1);
INSERT INTO greg.d_basis_elementer VALUES ('BE', 'BE-02', 'Grus', 1);
INSERT INTO greg.d_basis_elementer VALUES ('BE', 'BE-03', 'Trimmet grus', 1);
INSERT INTO greg.d_basis_elementer VALUES ('BE', 'BE-04', 'Andre løse belægninger', 1);
INSERT INTO greg.d_basis_elementer VALUES ('BE', 'BE-05', 'Sportsbelægninger', 1);
INSERT INTO greg.d_basis_elementer VALUES ('BE', 'BE-06', 'Faldunderlag', 1);
INSERT INTO greg.d_basis_elementer VALUES ('UD', 'UD-00', 'Terrænudstyr', 1);
INSERT INTO greg.d_basis_elementer VALUES ('UD', 'UD-01', 'Andet terrænudstyr', 1);
INSERT INTO greg.d_basis_elementer VALUES ('UD', 'UD-02', 'Trapper', 1);
INSERT INTO greg.d_basis_elementer VALUES ('UD', 'UD-03', 'Terrænmure', 1);
INSERT INTO greg.d_basis_elementer VALUES ('UD', 'UD-04', 'Bænke', 1);
INSERT INTO greg.d_basis_elementer VALUES ('UD', 'UD-05', 'Faste hegn', 1);
INSERT INTO greg.d_basis_elementer VALUES ('UD', 'UD-06', 'Legeudstyr', 1);
INSERT INTO greg.d_basis_elementer VALUES ('UD', 'UD-07', 'Affald', 1);
INSERT INTO greg.d_basis_elementer VALUES ('UD', 'UD-08', 'Busstop', 1);
INSERT INTO greg.d_basis_elementer VALUES ('UD', 'UD-09', 'Fitness', 1);
INSERT INTO greg.d_basis_elementer VALUES ('ANA', 'ANA-01', 'Anden anvendelse', 1);
INSERT INTO greg.d_basis_elementer VALUES ('ANA', 'ANA-02', 'Udenfor drift og pleje', 1);
INSERT INTO greg.d_basis_elementer VALUES ('ANA', 'ANA-03', 'Private haver', 1);
INSERT INTO greg.d_basis_elementer VALUES ('ANA', 'ANA-04', 'Kantsten', 1);
INSERT INTO greg.d_basis_elementer VALUES ('REN', 'REN-01', 'Bypræg', 1);
INSERT INTO greg.d_basis_elementer VALUES ('REN', 'REN-02', 'Parkpræg', 1);
INSERT INTO greg.d_basis_elementer VALUES ('REN', 'REN-03', 'Naturpræg', 1);

--
-- d_basis_underelementer
--

INSERT INTO greg.d_basis_underelementer VALUES ('GR-00', 'GR-00-00', 'Græs', 'F', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('GR-01', 'GR-01-01', 'Brugsplæne', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('GR-01', 'GR-01-02', 'Brugsplæne - sport', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('GR-02', 'GR-02-01', 'Græsflade', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('GR-03', 'GR-03-01', 'Sportsplæne', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('GR-04', 'GR-04-01', 'Fælledgræs', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('GR-04', 'GR-04-02', 'Fælledgræs B', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('GR-04', 'GR-04-03', 'Fælledgræs - Tørbassin', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('GR-05', 'GR-05-01', 'Rabatgræs', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('GR-06', 'GR-06-01', 'Naturgræs', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('GR-06', 'GR-06-02', 'Naturgræs A', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('GR-06', 'GR-06-03', 'Naturgræs B', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('GR-06', 'GR-06-04', 'Naturgræs C', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('GR-07', 'GR-07-01', 'Græsning', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('GR-08', 'GR-08-01', 'Strand og klit', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('GR-09', 'GR-09-01', '§3 Område', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('GR-10', 'GR-10-01', 'Særligt græsområde', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BL-00', 'BL-00-00', 'Blomster', 'FLP', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BL-01', 'BL-01-01', 'Sommerblomster', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BL-02', 'BL-02-01', 'Ampel', 'P', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BL-03', 'BL-03-01', 'Plantekumme', 'P', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BL-04', 'BL-04-01', 'Roser og stauder', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BL-05', 'BL-05-01', 'Solitær klatreplante', 'P', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BL-05', 'BL-05-02', 'Klatreplante', 'L', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BL-06', 'BL-06-01', 'Urtehave', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BU-00', 'BU-00-00', 'Buske', 'F', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BU-01', 'BU-01-01', 'Bunddækkende busk', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BU-02', 'BU-02-01', 'Busket', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BU-03', 'BU-03-01', 'Krat og hegn', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BU-04', 'BU-04-01', 'Bunddækkende krat', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('HÆ-00', 'HÆ-00-00', 'Hække', 'F', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('HÆ-01', 'HÆ-01-01', 'Hæk og pur', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('HÆ-01', 'HÆ-01-02', 'Hæk og pur - 2x klip', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('HÆ-02', 'HÆ-02-01', 'Hækkekrat', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('TR-00', 'TR-00-00', 'Træer', 'FP', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('TR-01', 'TR-01-01', 'Fritstående træ', 'P', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('TR-02', 'TR-02-01', 'Vejtræ', 'P', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('TR-03', 'TR-03-01', 'Trægruppe', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('TR-04', 'TR-04-01', 'Trærække', 'P', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('TR-05', 'TR-05-01', 'Formet træ', 'P', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('TR-06', 'TR-06-01', 'Frugttræ', 'P', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('TR-07', 'TR-07-01', 'Allé', 'P', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('TR-08', 'TR-08-01', 'Skov og lund', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('TR-09', 'TR-09-01', 'Fælledskov', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('VA-00', 'VA-00-00', 'Vand', 'FL', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('VA-01', 'VA-01-01', 'Bassin', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('VA-01', 'VA-01-02', 'Forbassin', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('VA-01', 'VA-01-03', 'Hovedbassin', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('VA-01', 'VA-01-04', 'Rørbassin', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('VA-02', 'VA-02-01', 'Vandhul', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('VA-03', 'VA-03-01', 'Sø og gadekær', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('VA-04', 'VA-04-01', 'Vandløb', 'L', 0.00, 0.00, 'kr/lbm', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('VA-05', 'VA-05-01', 'Rørskov', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BE-00', 'BE-00-00', 'Belægninger', 'F', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BE-01', 'BE-01-01', 'Anden fast belægning', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BE-01', 'BE-01-02', 'Asfalt', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BE-01', 'BE-01-03', 'Beton', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BE-01', 'BE-01-04', 'Natursten', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BE-01', 'BE-01-05', 'Træ', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BE-02', 'BE-02-01', 'Grus', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BE-03', 'BE-03-01', 'Trimmet grus', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BE-04', 'BE-04-01', 'Anden løs belægning', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BE-04', 'BE-04-02', 'Sten', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BE-04', 'BE-04-03', 'Skærver', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BE-04', 'BE-04-04', 'Flis', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BE-04', 'BE-04-05', 'Jord', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BE-05', 'BE-05-01', 'SB - Anden sportsbelægning', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BE-05', 'BE-05-02', 'SB - Kunststof', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BE-05', 'BE-05-03', 'SB - Kunstgræs', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BE-05', 'BE-05-04', 'SB - Tennisgrus', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BE-05', 'BE-05-05', 'SB - Slagger', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BE-05', 'BE-05-06', 'SB - Stenmel', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BE-05', 'BE-05-07', 'SB - Asfalt', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BE-06', 'BE-06-01', 'Andet faldunderlag', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BE-06', 'BE-06-02', 'Faldgrus', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BE-06', 'BE-06-03', 'Faldsand', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BE-06', 'BE-06-04', 'Gummifliser', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('BE-06', 'BE-06-05', 'Støbt gummi', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-00', 'UD-00-00', 'Terrænudstyr', 'FLP', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-01', 'UD-01-01', 'Andet terrænudstyr', 'FLP', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-01', 'UD-01-02', 'Skilt', 'P', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-01', 'UD-01-03', 'Trafikbom', 'P', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-01', 'UD-01-04', 'Pullert', 'LP', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-01', 'UD-01-05', 'Cykelstativ', 'LP', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-01', 'UD-01-06', 'Parklys', 'P', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-01', 'UD-01-07', 'Banelys', 'P', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-01', 'UD-01-08', 'Tagrende', 'L', 0.00, 0.00, 'kr/lbm', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-01', 'UD-01-09', 'Lyskasse', 'P', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-01', 'UD-01-10', 'Faskine', 'P', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-01', 'UD-01-11', 'Affaldscontainer', 'P', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-01', 'UD-01-12', 'Shelterhytte', 'P', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-01', 'UD-01-13', 'Træbro', 'L', 0.00, 0.00, 'kr/lbm', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-01', 'UD-01-14', 'Kampesten', 'P', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-01', 'UD-01-15', 'Flagstang', 'P', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-02', 'UD-02-01', 'Trappe', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-02', 'UD-02-02', 'Betontrappe', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-02', 'UD-02-03', 'Naturstenstrappe', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-02', 'UD-02-04', 'Trappe - træ/jord', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-03', 'UD-03-01', 'Terrænmur', 'L', 0.00, 0.00, 'kr/lbm', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-03', 'UD-03-02', 'Kampestensmur', 'L', 0.00, 0.00, 'kr/lbm', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-03', 'UD-03-03', 'Betonmur', 'L', 0.00, 0.00, 'kr/lbm', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-03', 'UD-03-04', 'Naturstensmur', 'L', 0.00, 0.00, 'kr/lbm', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-03', 'UD-03-05', 'Træmur', 'L', 0.00, 0.00, 'kr/lbm', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-04', 'UD-04-01', 'Bænk', 'P', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-04', 'UD-04-02', 'Bord- og bænkesæt', 'P', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-05', 'UD-05-01', 'Fast hegn', 'L', 0.00, 0.00, 'kr/lbm', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-05', 'UD-05-02', 'Trådhegn', 'L', 0.00, 0.00, 'kr/lbm', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-05', 'UD-05-03', 'Maskinflettet hegn', 'L', 0.00, 0.00, 'kr/lbm', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-05', 'UD-05-04', 'Træhegn', 'L', 0.00, 0.00, 'kr/lbm', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-05', 'UD-05-05', 'Fodhegn', 'L', 0.00, 0.00, 'kr/lbm', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-06', 'UD-06-01', 'Legeudstyr', 'P', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-06', 'UD-06-02', 'Sandkasse', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-06', 'UD-06-03', 'Kant - faldunderlag', 'L', 0.00, 0.00, 'kr/lbm', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-06', 'UD-06-04', 'Kant - sandkasse', 'L', 0.00, 0.00, 'kr/lbm', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-07', 'UD-07-01', 'Affald', 'P', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-07', 'UD-07-02', 'Affaldsspand', 'P', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-07', 'UD-07-03', 'Askebæger', 'P', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-07', 'UD-07-04', 'Hundeposestativ', 'P', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-08', 'UD-08-01', 'Busstop', 'P', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-09', 'UD-09-01', 'Fitness', 'P', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('UD-09', 'UD-09-02', 'Fast sportsudstyr', 'P', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('ANA-01', 'ANA-01-01', 'Anden anvendelse', 'FLP', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('ANA-02', 'ANA-02-01', 'Udenfor drift og pleje', 'FLP', 0.00, 0.00, 'kr/stk', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('ANA-03', 'ANA-03-01', 'Privat have', 'F', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('ANA-04', 'ANA-04-01', 'Kantsten', 'L', 0.00, 0.00, 'kr/lbm', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('REN-01', 'REN-01-01', 'Bypræg', 'P', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('REN-02', 'REN-02-01', 'Parkpræg', 'P', 0.00, 0.00, 'kr/m2', 1);
INSERT INTO greg.d_basis_underelementer VALUES ('REN-03', 'REN-03-01', 'Naturpræg', 'P', 0.00, 0.00, 'kr/m2', 1);

--
-- d_basis_postdistrikter
--

INSERT INTO greg.d_basis_postdistrikter VALUES (3550, 'Slangerup', 1);
INSERT INTO greg.d_basis_postdistrikter VALUES (3600, 'Frederikssund', 1);
INSERT INTO greg.d_basis_postdistrikter VALUES (3630, 'Jægerspris', 1);
INSERT INTO greg.d_basis_postdistrikter VALUES (4050, 'Skibby', 1);

--
-- d_basis_udfoerer
--

INSERT INTO greg.d_basis_udfoerer VALUES ('HedeDanmark', 1);

--
-- d_basis_vejnavn
--

INSERT INTO greg.d_basis_vejnavn VALUES (1, 'A C Hansensvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (2, 'Aaskildevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (4, 'Abildgård', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (5, 'Adilsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (6, 'Agerhøjen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (7, 'Agervangen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (8, 'Agervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (9, 'Agervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (10, 'Ahornkrogen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (11, 'Ahornvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (13, 'Ahornvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (14, 'Akacievej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (15, 'Alholm Ø', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (16, 'Alholmvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (17, 'Allingbjergvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (18, 'Amalievej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (19, 'Amledsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (20, 'Amsterdamhusene', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (21, 'Andekærvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (22, 'Anders Jensens Vej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (23, 'Anders Jensensvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (24, 'Anemonevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (25, 'Anemonevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (26, 'Anemonevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (28, 'Anne Marievej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (29, 'Ansgarsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (30, 'Apholm', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (31, 'Arvedsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (32, 'Asgård', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (33, 'Askelundsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (34, 'Askevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (35, 'Askevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (37, 'Askøvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (38, 'Aslaugsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (39, 'Axelgaardsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (40, 'Bag Hegnet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (43, 'Bag Skovens Brugs', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (45, 'Bakager', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (46, 'Bakkebo', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (47, 'Bakkedraget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (48, 'Bakkegaardsmarken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (49, 'Bakkegade', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (50, 'Bakkegården', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (51, 'Bakkegårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (52, 'Bakkehøjen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (53, 'Bakkekammen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (54, 'Bakkelundsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (55, 'Bakkestrædet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (56, 'Bakkesvinget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (57, 'Bakkesvinget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (58, 'Bakkesvinget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (59, 'Bakkevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (61, 'Bakkevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (63, 'Bakkevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (64, 'Bakkevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (65, 'Bakkevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (66, 'Baldersvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (67, 'Ballermosevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (68, 'Banegraven', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (69, 'Baneledet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (70, 'Banevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (71, 'Barakvejen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (72, 'Baunehøjen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (73, 'Baunehøjgaardsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (75, 'Baunehøjvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (76, 'Baunevangen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (77, 'Bautahøjvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (78, 'Bavnehøj', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (79, 'Bavnen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (82, 'Baygårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (83, 'Beckersvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (84, 'Bellisvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (85, 'Bellisvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (86, 'Bellisvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (88, 'Benediktevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (89, 'Betulavej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (90, 'Birkagervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (91, 'Birkealle', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (92, 'Birkebakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (93, 'Birkebækvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (94, 'Birkedal', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (95, 'Birkedalsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (96, 'Birkeengen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (97, 'Birkehaven', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (98, 'Birkehøjen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (99, 'Birkekæret', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (100, 'Birkelunden', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (101, 'Birkemosevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (102, 'Birkemosevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (103, 'Birketoften', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (104, 'Birkevang', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (106, 'Birkevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (107, 'Birkevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (108, 'Birkevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (112, 'Birkevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (113, 'Birkevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (114, 'Birkholmvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (116, 'Bjarkesvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (117, 'Bjarkesvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (118, 'Bjergvejen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (120, 'Blakke Møllevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (121, 'Blommehaven', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (122, 'Blommevang', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (123, 'Blommevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (124, 'Blødevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (125, 'Bogfinkevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (126, 'Bogfinkevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (127, 'Bogøvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (132, 'Bonderupvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (133, 'Bonderupvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (134, 'Bopladsen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (135, 'Borgervænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (136, 'Borgmarken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (137, 'Borgmestervænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (138, 'Brantegårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (139, 'Bredagervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (141, 'Bredviggårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (142, 'Bredvigvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (144, 'Bregnevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (145, 'Brobæksgade', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (146, 'Broengen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (147, 'Bronzeager', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (148, 'Bruhnsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (149, 'Buen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (150, 'Buen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (152, 'Buresø', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (153, 'Busvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (154, 'Bybakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (155, 'Bygaden', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (156, 'Bygaden', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (157, 'Bygaden', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (158, 'Bygaden', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (160, 'Bygmarken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (161, 'Bygtoften', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (162, 'Bygvænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (163, 'Byhøjen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (164, 'Bykærvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (165, 'Bymidten', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (166, 'Bystrædet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (168, 'Bytoften', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (169, 'Byvangen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (170, 'Byvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (171, 'Bækkevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (172, 'Bøgealle', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (173, 'Bøgebakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (174, 'Bøgetoften', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (175, 'Bøgevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (176, 'Bøgevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (177, 'Bøgevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (179, 'Centervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (181, 'Chr Jørgensensvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (183, 'Christiansmindevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (186, 'Dalbovej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (190, 'Dalby Huse Vej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (192, 'Dalby Strandvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (193, 'Dalskrænten', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (194, 'Dalsænkningen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (196, 'Dalvejen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (198, 'Damgårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (199, 'Damgårdsvænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (202, 'Dammen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (203, 'Damstræde', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (204, 'Damvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (207, 'Degnebakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (210, 'Degnemosevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (211, 'Degnersvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (212, 'Degnevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (213, 'Degnevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (214, 'Digevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (215, 'Digevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (217, 'Draaby Strandvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (218, 'Drosselvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (219, 'Drosselvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (220, 'Drosselvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (222, 'Drosselvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (223, 'Druedalsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (224, 'Druekrogen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (226, 'Dråbyvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (227, 'Duemosevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (228, 'Duevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (229, 'Duevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (230, 'Duevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (231, 'Dunhammervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (232, 'Dunhammervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (233, 'Dyrlægegårds Alle', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (234, 'Dyrnæsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (235, 'Dysagervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (236, 'Dyssebjerg', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (237, 'Dyssegaardsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (238, 'Dådyrvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (239, 'Egebakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (240, 'Egebjergvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (241, 'Egehøj', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (243, 'Egelundsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (244, 'Egelyvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (245, 'Egeparken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (246, 'Egeparken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (247, 'Egernvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (249, 'Egernvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (250, 'Egestien', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (251, 'Egetoften', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (252, 'Egevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (254, 'Egevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (255, 'Egevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (257, 'Egilsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (258, 'Elbakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (259, 'Ellehammervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (260, 'Ellekildehøj', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (261, 'Ellekær', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (262, 'Ellekær', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (263, 'Ellelunden', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (264, 'Ellemosevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (265, 'Ellens Vænge', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (266, 'Ellevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (268, 'Ellevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (270, 'Elmegårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (271, 'Elmegårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (272, 'Elmetoften', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (273, 'Elmevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (274, 'Elmevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (275, 'Elmevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (276, 'Elmevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (278, 'Elsenbakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (279, 'Elverhøjen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (280, 'Enebærvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (281, 'Engbakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (282, 'Engblommevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (283, 'Engbovej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (284, 'Engdraget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (285, 'Engdraget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (286, 'Enghavegårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (287, 'Enghaven', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (288, 'Enghaven', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (289, 'Enghøj', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (290, 'Engledsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (291, 'Englodden', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (292, 'Englodden', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (293, 'Englodsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (294, 'Englystvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (295, 'Engparken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (296, 'Engsvinget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (297, 'Engtoftevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (298, 'Engvang', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (299, 'Engvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (300, 'Engvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (301, 'Engvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (303, 'Erantisvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (304, 'Erantisvænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (305, 'Erik Arupsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (306, 'Erik Ejegodsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (307, 'Eskemosevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (309, 'Eskilsø', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (310, 'Esrogårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (311, 'Esrohaven', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (312, 'Esromarken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (313, 'Fabriksvangen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (314, 'Fagerholtvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (316, 'Fagerkærsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (317, 'Falkenborggården', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (318, 'Falkenborgvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (319, 'Falkevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (320, 'Falkevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (321, 'Fasangårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (322, 'Fasanvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (323, 'Fasanvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (324, 'Fasanvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (325, 'Fasanvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (327, 'Fasanvænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (328, 'Fejøvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (329, 'Femhøj Stationsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (330, 'Femhøjvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (331, 'Femvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (332, 'Fengesvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (334, 'Fiskerhusevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (335, 'Fiskervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (336, 'Fjeldhøjvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (337, 'Fjordbakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (338, 'Fjordbakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (339, 'Fjordglimtvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (340, 'Fjordgårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (341, 'Fjordparken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (342, 'Fjordskovvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (343, 'Fjordskrænten', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (344, 'Fjordslugten', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (345, 'Fjordstien', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (346, 'Fjordtoften', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (348, 'Fjordvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (349, 'Fjordvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (350, 'Fjordvænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (351, 'Flintehøjen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (352, 'Foderstofgården', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (353, 'Fogedgårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (355, 'Forårsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (356, 'Fredbo Vænge', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (357, 'Fredensgade', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (358, 'Fredensgade', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (359, 'Frederiksborggade', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (360, 'Frederiksborgvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (361, 'Frederiksborgvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (362, 'Hørup Skovvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (363, 'Frederikssundsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (364, 'Frederiksværkvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (365, 'Frejasvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (366, 'Frejasvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (367, 'Frihedsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (368, 'Frodesvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (369, 'Frodesvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (370, 'Fuglebakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (371, 'Fyrrebakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (372, 'Fyrrebakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (373, 'Fyrrehaven', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (374, 'Fyrrehegnet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (375, 'Fyrrehøj', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (376, 'Fyrreknolden', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (377, 'Fyrrekrogen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (378, 'Fyrreparken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (379, 'Fyrresidevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (380, 'Fyrrevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (381, 'Fyrrevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (383, 'Fyrvænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (384, 'Fælledvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (385, 'Fællesvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (386, 'Færgelundsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (387, 'Færgeparken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (388, 'Færgevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (389, 'Fæstermarken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (390, 'Gadehøjvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (392, 'Gadekærsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (393, 'Gammel Dalbyvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (394, 'Gammel Færgegårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (395, 'Gammel Kulhusvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (396, 'Gammel Marbækvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (397, 'Gammel Slangerupvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (398, 'Gammel Stationsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (399, 'Gartnervænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (400, 'Gartnervænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (401, 'Kilde Alle', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (402, 'Geddestien', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (403, 'Gedehøjvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (404, 'Gefionvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (406, 'Gerlev Strandvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (407, 'Gl Københavnsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (411, 'Glentevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (412, 'Goldbjergvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (413, 'Gormsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (414, 'Granbrinken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (415, 'Granhøj', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (416, 'Granplantagen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (417, 'Gransangervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (418, 'Grantoften', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (420, 'Granvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (421, 'Græse Bygade', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (422, 'Græse Mølle', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (423, 'Græse Skolevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (424, 'Græse Strandvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (425, 'Græsedalen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (426, 'Græsevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (427, 'Grønhøj', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (429, 'Grønnevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (430, 'Grønnevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (431, 'Grønshøjvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (432, 'Guldstjernevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (433, 'Gulspurvevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (434, 'Gyldenstens Vænge', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (435, 'Gyvelbakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (436, 'Gyvelkrogen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (437, 'Gyvelvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (438, 'Gøgebakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (439, 'Gøgevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (440, 'Gøgevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (441, 'H.C.Vej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (443, 'Hagerupvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (444, 'Halfdansvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (445, 'Halvdansvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (446, 'Hammer Bakke', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (447, 'Hammertoften', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (448, 'Hammervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (450, 'Hanghøjvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (451, 'Hannelundsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (452, 'Hans Atkesvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (453, 'Harald Blåtandsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (454, 'Harebakkevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (456, 'Harevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (457, 'Harevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (458, 'Hartmannsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (459, 'Haspeholms Alle', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (460, 'Hasselhøjvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (462, 'Hasselstrædet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (463, 'Hasselvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (464, 'Hasselvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (465, 'Hasselvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (466, 'Hauge Møllevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (467, 'Havelse Mølle', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (468, 'Havnegade', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (469, 'Havnen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (470, 'Havnevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (471, 'Havremarken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (472, 'Havretoften', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (473, 'Havrevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (474, 'Heegårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (475, 'Heimdalsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (476, 'Hejre Sidevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (477, 'Hejrevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (478, 'Helgesvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (479, 'Helgesvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (480, 'Hellesø', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (482, 'Hestefolden', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (483, 'Hestetorvet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (484, 'Hillerødvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (485, 'Hindbærvænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (486, 'Hjaltesvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (487, 'Hjortehaven', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (489, 'Hjortevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (490, 'Hjortevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (491, 'Hjorthøjvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (492, 'Hofvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (493, 'Holmegårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (494, 'Holmensvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (495, 'Horsehagevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (496, 'Hovdiget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (497, 'Hovedgaden', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (500, 'Hovedgaden', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (501, 'Hovleddet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (502, 'Hovmandsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (503, 'Hulekærsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (504, 'Hummervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (505, 'Hvedemarken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (506, 'Hvilehøj Sidevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (507, 'Hvilehøjvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (508, 'Hybenvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (509, 'Hybenvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (510, 'Hybenvænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (511, 'Hyggevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (512, 'Hyldeager', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (513, 'Hyldebakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (514, 'Hyldebærvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (515, 'Hyldedal', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (516, 'Hyldegaardsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (517, 'Hyldeholm', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (518, 'Hyldevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (519, 'Hyllestedvejen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (520, 'Hyllingeriis', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (522, 'Hyrdevigen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (524, 'Hyttevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (525, 'Hækkevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (526, 'Høgevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (527, 'Højager', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (528, 'Højagergaardsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (529, 'Højagervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (530, 'Højbovej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (531, 'Højdevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (532, 'Højdevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (534, 'Højgårds Alle', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (535, 'Højskolevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (536, 'Højtoften', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (537, 'Højtoften', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (539, 'Højtoften', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (540, 'Højvang', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (541, 'Højvangen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (546, 'Hørupstien', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (547, 'Hørupvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (548, 'Hørupvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (549, 'Høstvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (550, 'Håndværkervangen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (551, 'Håndværkervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (553, 'Idrætsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (554, 'Idrætsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (555, 'Indelukket', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (556, 'Industrivej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (557, 'Industrivej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (559, 'Ingridvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (560, 'Irisvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (562, 'Irisvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (563, 'Irisvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (565, 'Isefjordvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (566, 'Islebjergvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (567, 'Ivar Lykkes Vej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (568, 'J. F. Willumsens Vej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (569, 'Jenriksvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (570, 'Jerichausvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (571, 'Jernager', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (572, 'Jernbanegade', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (573, 'Jernbanevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (574, 'Jernhøjvænge', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (575, 'Jomsborgvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (576, 'Jordbærvang', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (579, 'Jordhøj Bakke', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (580, 'Jordhøjvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (581, 'Julemosevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (582, 'Jungedalsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (583, 'Jungehøj', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (584, 'Jupitervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (585, 'Juulsbjergvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (586, 'Jægeralle', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (587, 'Jægerbakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (588, 'Jægerstien', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (591, 'Jættehøj', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (592, 'Jættehøjen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (594, 'Jørlunde Overdrev', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (595, 'Kalvøvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (596, 'Kannikestræde', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (597, 'Karl Frandsens Vej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (598, 'Karpevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (599, 'Kastaniealle', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (600, 'Kastanievej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (601, 'Kignæsbakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (602, 'Kignæshaven', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (603, 'Kignæskrogen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (604, 'Kignæsskrænten', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (606, 'Kikkerbakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (607, 'Kildebakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (608, 'Kildeskåret', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (609, 'Kildestien', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (610, 'Kildevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (612, 'Kingovej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (613, 'Kirkealle', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (614, 'Kirkebakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (615, 'Kirkebakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (616, 'Kirkegade', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (618, 'Kirkegade', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (619, 'Kirkestien', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (620, 'Kirkestræde', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (622, 'Kirkestræde', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (623, 'Kirkestræde', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (624, 'Kirketoften', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (625, 'Kirketorvet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (626, 'Kirkevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (627, 'Kirkevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (629, 'Kirkevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (630, 'Kirkeåsen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (631, 'Kirsebærvang', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (632, 'Kirsebærvænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (633, 'Klinten', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (634, 'Klintevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (635, 'Klintevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (636, 'Klokkervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (637, 'Klostergården', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (638, 'Klosterstræde', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (639, 'Kløvertoften', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (640, 'Kløvervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (641, 'Kløvervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (642, 'Knoldager', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (643, 'Knud Den Storesvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (644, 'Kobbelgårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (645, 'Kobbelvangsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (646, 'Kocksvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (647, 'Koholmmosen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (648, 'Kong Dansvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (649, 'Kong Skjoldsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (650, 'Kongelysvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (651, 'Kongensgade', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (653, 'Kongshøj Alle', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (654, 'Kongshøjparken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (655, 'Konkylievej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (656, 'Koralvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (657, 'Kornvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (658, 'Kornvænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (659, 'Korshøj', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (660, 'Krabbevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (661, 'Kragevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (662, 'Krakasvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (663, 'Kratmøllestien', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (664, 'Kratvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (665, 'Kratvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (666, 'Kroghøj', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (668, 'Krogstrupvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (669, 'Kronprins Fr''S Bro', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (671, 'Kulhusgårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (672, 'Kulhustværvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (673, 'Kulhusvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (674, 'Kulmilevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (675, 'Kulsviervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (677, 'Kvinderupvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (681, 'Kyndbyvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (683, 'Kystsvinget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (684, 'Kysttoften', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (685, 'Kystvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (686, 'Kæmpesvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (687, 'Kærkrogen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (689, 'Kærsangervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (690, 'Kærstrædet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (693, 'Kærvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (694, 'Kærvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (695, 'Københavnsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (696, 'Kølholm', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (697, 'Kølholmvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (698, 'Laksestien', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (700, 'Landerslevvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (701, 'Langager', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (702, 'Langesvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (703, 'Lanternevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (704, 'Lars Hansensvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (705, 'Lebahnsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (706, 'Lejrvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (707, 'Lerager', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (709, 'Lergårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (710, 'Liljevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (711, 'Lille Bautahøjvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (712, 'Lille Blødevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (713, 'Lille Druedalsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (714, 'Lille Engvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (715, 'Lille Fjordvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (716, 'Lille Færgevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (717, 'Lille Hofvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (718, 'Lille Lyngerupvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (719, 'Lille Marbækvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (720, 'Lille Rørbæk Enge', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (721, 'Lille Rørbækvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (723, 'Lille Skovvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (724, 'Lille Solbakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (725, 'Lille Strandvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (727, 'Lillebakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (728, 'Lilledal', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (729, 'Lillekær', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (730, 'Lilletoften', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (731, 'Lillevangsstien', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (732, 'Lillevangsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (734, 'Lindealle', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (735, 'Lindegaardsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (736, 'Lindegårds Alle', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (737, 'Lindegårdsstien', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (738, 'Lindegårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (739, 'Lindeparken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (741, 'Linderupvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (742, 'Lindevang', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (743, 'Lindevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (745, 'Lindholm Stationsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (746, 'Lindholmvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (747, 'Lindormevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (748, 'Lineborg', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (750, 'Ll Troldmosevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (751, 'Lodden', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (753, 'Lodshaven', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (754, 'Lokesvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (755, 'Louiseholmsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (756, 'Louisevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (757, 'Lundebjergvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (758, 'Lundeparken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (759, 'Lundevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (760, 'Lupinvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (761, 'Lupinvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (762, 'Lupinvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (764, 'Lyngbakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (765, 'Lyngbakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (766, 'Lyngerupvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (767, 'Lynghøj', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (768, 'Lyngkrogen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (769, 'Lysebjergvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (772, 'Lystrup Skov', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (773, 'Lystrupvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (774, 'Lyøvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (775, 'Lærketoften', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (776, 'Lærkevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (778, 'Lærkevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (779, 'Lærkevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (780, 'Lærkevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (781, 'Lærkevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (782, 'Løgismose', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (783, 'Løjerthusvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (784, 'Løvekær', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (785, 'M P Jensens Vej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (786, 'Maglehøjparken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (787, 'Maglehøjvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (789, 'Magnoliavej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (790, 'Magnoliavej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (794, 'Manderupvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (795, 'Manderupvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (796, 'Mannekildevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (797, 'Marbæk Alle', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (798, 'Marbæk-Parken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (800, 'Marbækvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (801, 'Marbækvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (803, 'Margrethevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (804, 'Mariendalsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (805, 'Marienlystvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (806, 'Markleddet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (807, 'Markstien', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (808, 'Marksvinget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (809, 'Markvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (810, 'Mathiesens Enghave', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (811, 'Mathildevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (812, 'Mejerigårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (814, 'Mejerivej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (815, 'Mejsevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (816, 'Mejsevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (817, 'Mejsevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (820, 'Mellemvang', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (821, 'Midgård', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (822, 'Midtbanevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (823, 'Mimersvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (824, 'Mirabellestrædet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (826, 'Mirabellevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (827, 'Morbærvænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (828, 'Morelvang', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (829, 'Morænevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (830, 'Mosebuen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (831, 'Mosehøj', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (832, 'Mosekærvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (833, 'Mosestien', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (834, 'Mosesvinget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (835, 'Mosevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (837, 'Mosevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (838, 'Mosevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (839, 'Mosevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (840, 'Muldager', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (841, 'Murkærvænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (842, 'Muslingevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (843, 'Mæremosevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (844, 'Møllebakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (845, 'Møllebakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (846, 'Mølledammen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (847, 'Mølleengen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (848, 'Møllehaven', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (849, 'Møllehegnet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (850, 'Møllehøj', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (852, 'Møllehøjen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (853, 'Møllehøjvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (854, 'Mølleparken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (855, 'Møllestien', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (856, 'Møllestien', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (857, 'Møllestræde', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (858, 'Møllevangen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (859, 'Møllevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (860, 'Møllevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (862, 'Møllevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (863, 'Mønten', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (864, 'Møntporten', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (865, 'Møntstrædet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (866, 'Mørkebjergvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (867, 'Mågevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (868, 'Mågevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (869, 'Mågevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (870, 'Mågevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (871, 'Månevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (872, 'Månevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (874, 'Nakkedamsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (875, 'Nattergalevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (877, 'Nialsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (878, 'Nikolajsensvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (879, 'Nordhøj', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (880, 'Nordkajen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (881, 'Nordmandshusene', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (882, 'Nordmandsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (884, 'Nordmandsvænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (885, 'Nordre Pakhusvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (887, 'Nordskovhusvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (888, 'Nordskovvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (889, 'Nordsvinget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (890, 'Nordsøgårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (891, 'Nordvangen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (892, 'Nordvejen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (894, 'Nordvænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (896, 'Ny Østergade', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (897, 'Ny Øvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (898, 'Nybrovej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (899, 'Nybrovænge', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (900, 'Nygaardsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (901, 'Nygade', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (902, 'Nygårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (903, 'Nytoften', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (904, 'Nyvang', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (905, 'Nyvangshusene', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (906, 'Nyvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (908, 'Nyvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (909, 'Nøddekrogen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (910, 'Nøddevang', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (912, 'Nøddevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (913, 'Nørhaven', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (914, 'Nørreparken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (915, 'Nørresvinget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (916, 'Nørrevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (917, 'Odinsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (918, 'Oldvejen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (919, 'Ole Peters Vej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (924, 'Onsved Huse', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (926, 'Onsvedvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (927, 'Oppe-Sundbyvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (928, 'Ordrupdalsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (929, 'Ordrupholmsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (931, 'Orebjerg Alle', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (932, 'Orebjergvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (936, 'Overdrevsstien', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (937, 'Pagteroldvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (938, 'Palnatokesvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (939, 'Parkalle', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (940, 'Parkvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (941, 'Parkvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (942, 'Peberholm', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (943, 'Pedersholmparken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (944, 'Pilealle', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (945, 'Pilehaven', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (946, 'Pilehaven', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (947, 'Pilehegnet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (948, 'Pilevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (949, 'Pilevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (951, 'Planetvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (952, 'Plantagevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (954, 'Plantagevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (955, 'Plantagevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (956, 'Plantagevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (957, 'Platanvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (958, 'Poppelhegnet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (960, 'Poppelstrædet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (961, 'Poppelvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (963, 'Poppelvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (964, 'Poppelvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (965, 'Primulavej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (966, 'Præstegaardsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (967, 'Præstemarken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (968, 'Præstemarken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (969, 'Præstevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (971, 'Påstrupvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (972, 'Ranunkelvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (973, 'Rappendam Have', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (974, 'Rappendamsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (976, 'Ravnsbjergstien', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (977, 'Ravnsbjergvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (978, 'Regnar Lodbrogsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (979, 'Rejestien', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (980, 'Rendebæk Strand', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (981, 'Rendebækvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (982, 'Resedavej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (983, 'Revelinen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (984, 'Ribisvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (985, 'Ringvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (986, 'Roarsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (987, 'Roarsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (988, 'Rolf Krakesvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (989, 'Rolf Krakesvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (990, 'Rollosvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (991, 'Rosenbakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (992, 'Rosendalsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (993, 'Rosenfeldt', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (994, 'Rosenhaven', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (995, 'Rosenvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (996, 'Rosenvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (997, 'Rosenvænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (999, 'Rosenvænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1000, 'Roskildevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1002, 'Roskildevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1003, 'Rugmarken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1004, 'Rugskellet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1005, 'Rugtoften', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1006, 'Rugvænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1007, 'Rugvænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1008, 'Runegaards Alle', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1009, 'Runestien', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1010, 'Rylevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1011, 'Rylevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1012, 'Rævevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1019, 'Røgerupvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1020, 'Røglevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1021, 'Rønnebærvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1022, 'Rønnebærvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1023, 'Rønnevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1025, 'Rønnevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1026, 'Rørbæk Møllevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1027, 'Røriksvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1028, 'Rørsangervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1029, 'Rørsangervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1030, 'Rådhuspassagen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1031, 'Rådhusstræde', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1032, 'Rådhusstrædet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1033, 'Rådhusvænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1035, 'Rågevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1036, 'Sagavej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1037, 'Saltsøgårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1038, 'Saltsøvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1040, 'Sandbergsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1041, 'Sandholmen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1042, 'Sandkærvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1043, 'Sandsporet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1044, 'Sandvejen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1045, 'Saturnvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1047, 'Sct Bernardvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1048, 'Sct Jørgensvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1049, 'Sct Michaelsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1050, 'Sct Nilsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1051, 'Sejrøvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1054, 'Selsøvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1056, 'Servicegaden', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1057, 'Sigerslevvestervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1058, 'Sigerslevøstervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1059, 'Sikavej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1060, 'Sivkærvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1061, 'Sivsangervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1062, 'Skadevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1063, 'Skallekrogen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1064, 'Skansevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1065, 'Skarndalsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1066, 'Skehøjvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1067, 'Skelbæk', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1068, 'Skelvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1073, 'Skibby Old', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1074, 'Skibbyvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1075, 'Skiftestensvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1076, 'Skjoldagervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1077, 'Skjoldsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1079, 'Skolelodden', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1080, 'Skoleparken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1081, 'Skolestien', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1082, 'Skolestrædet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1085, 'Skolevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1086, 'Skolevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1087, 'Skovbakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1088, 'Skovbrynet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1089, 'Skovduevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1090, 'Skovengen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1091, 'Skovfogedvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1092, 'Skovgårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1093, 'Skovkirkevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1094, 'Skovmærkevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1095, 'Skovnæsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1096, 'Skovsangervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1097, 'Skovskadevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1098, 'Skovsneppevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1099, 'Skovspurvevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1100, 'Skovvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1102, 'Skovvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1103, 'Skovvejen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1105, 'Skovvænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1106, 'Skovvænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1107, 'Skriverbakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1108, 'Skrænten', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1109, 'Skrænten', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1112, 'Skuldelevvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1114, 'Skuldsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1115, 'Skyllebakke Havn', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1116, 'Skyllebakkegade', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1117, 'Skyttevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1118, 'Slagslundevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1119, 'Slangerup Overdrev', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1120, 'Slangerup Ås', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1122, 'Slangerupgårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1125, 'Slotsgården', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1126, 'Slåenbakkealle', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1127, 'Slåenbakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1128, 'Slåenbjerghuse', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1129, 'Smallevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1130, 'Smedebakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1131, 'Smedeengen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1132, 'Smedegyden', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1133, 'Smedeparken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1134, 'Smedetoften', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1135, 'Snerlevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1136, 'Snogekær', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1137, 'Snorresvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1138, 'Snostrupvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1139, 'Solbakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1140, 'Solbakkevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1141, 'Solbærvænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1142, 'Solhøjstræde', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1143, 'Solhøjvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1144, 'Solsikkevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1145, 'Solsortevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1146, 'Solsortevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1147, 'Solsortevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1148, 'Solvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1149, 'Solvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1151, 'Solvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1152, 'Solvænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1153, 'Sportsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1154, 'Spurvevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1155, 'Spurvevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1156, 'Spurvevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1157, 'Stagetornsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1158, 'Stakhaven', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1159, 'Stationsparken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1161, 'Stationsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1162, 'Stationsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1163, 'Stationsvænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1164, 'Stenager', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1165, 'Stendyssen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1166, 'Stendyssevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1168, 'Stenledsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1169, 'Stenværksvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1174, 'Stjernevang', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1175, 'Store Rørbækvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1176, 'Storgårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1178, 'Storkevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1179, 'Stormgårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1180, 'Strandager', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1181, 'Strandbakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1182, 'Strandbakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1183, 'Strandbovej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1184, 'Stranddyssen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1185, 'Strandengen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1186, 'Strandengen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1187, 'Strandgaardsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1188, 'Strandgangen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1189, 'Strandgårds Alle', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1190, 'Strandhaven', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1191, 'Strandhøj', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1192, 'Strandhøjen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1193, 'Strandhøjsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1194, 'Strandjægervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1195, 'Strandkanten', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1196, 'Strandkrogen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1197, 'Strandkærvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1198, 'Strandleddet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1199, 'Strandlinien', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1200, 'Strandlunden', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1201, 'Strandlystvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1202, 'Strandlystvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1203, 'Strandmarksvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1204, 'Strandstien', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1205, 'Strandstræde', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1206, 'Strandsvinget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1207, 'Strandtoften', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1208, 'Strandvangen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1209, 'Strandvangen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1210, 'Strandvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1211, 'Strandvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1212, 'Strandvejen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1213, 'Strandvænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1215, 'Strudhøj', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1216, 'Strædet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1218, 'Strædet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1219, 'Strædet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1221, 'Stubbevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1222, 'Stybes Alle', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1223, 'Stærevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1224, 'Stærevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1225, 'Stærevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1226, 'Stålager', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1229, 'Sundbylillevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1230, 'Sundbyvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1231, 'Sundparken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1232, 'Svaldergade', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1233, 'Svalevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1234, 'Svanemosevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1235, 'Svanestien', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1236, 'Svanevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1237, 'Svanevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1239, 'Svanholm Alle', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1241, 'Svend Tveskægsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1242, 'Svestrupvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1243, 'Svineholm', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1244, 'Svinget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1248, 'Sydkajen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1250, 'Sydmarken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1251, 'Syrenbakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1254, 'Syrenvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1255, 'Syrenvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1256, 'Syrenvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1257, 'Sævilsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1258, 'Søbovej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1260, 'Søgade', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1261, 'Søgårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1262, 'Søgårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1263, 'Søhestevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1264, 'Søhøj', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1265, 'Søkærvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1266, 'Sølvkærvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1267, 'Sømer Skovvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1268, 'Sønderby Bro', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1271, 'Sønderbyvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1272, 'Søndergade', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1275, 'Sønderparken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1277, 'Sønderstrædet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1278, 'Søndervangen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1280, 'Søndervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1281, 'Søstjernevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1282, 'Søtungevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1283, 'Søvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1284, 'Søvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1285, 'Tagetesvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1286, 'Teglværksvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1287, 'Ternevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1288, 'Thomsensvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1289, 'Thorfinsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1290, 'Thorsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1291, 'Thyrasvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1292, 'Thyrasvænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1293, 'Thyravej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1294, 'Timianstræde', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1295, 'Tingdyssevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1296, 'Tjørnevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1297, 'Tjørnevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1298, 'Tjørnevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1299, 'Tjørnevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1300, 'Toftegaardsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1301, 'Toftehøj', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1302, 'Toftekrogen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1303, 'Klosterbakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1304, 'Toftevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1306, 'Toftevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1307, 'Toftevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1308, 'Toldmose', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1309, 'Tollerupparken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1310, 'Tornebakke', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1311, 'Tornsangervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1312, 'Tornvig Olsens Vej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1316, 'Torpevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1317, 'Torvet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1318, 'Torøgelgårdsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1319, 'Traneagervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1320, 'Tranevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1322, 'Tranevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1323, 'Trekanten', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1324, 'Troldhøj', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1325, 'Trymsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1326, 'Tuevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1327, 'Tulipanvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1328, 'Tulipanvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1329, 'Tunøvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1330, 'Tvebjergvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1331, 'Tværstræde', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1332, 'Tværvang', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1333, 'Tværvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1335, 'Tværvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1336, 'Tørslevvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1337, 'Tørveagervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1338, 'Tøvkærsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1339, 'Tårnvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1341, 'Uffesvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1342, 'Uffesvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1343, 'Uggeløse Skov', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1344, 'Uglevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1346, 'Ulf Jarlsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1347, 'Ullemosevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1348, 'Ulriksvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1349, 'Urtebækvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1350, 'Urtehaven', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1353, 'Vagtelvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1354, 'Valmuevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1356, 'Valmuevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1357, 'Valmuevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1358, 'Valnøddevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1359, 'Vandtårnsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1360, 'Vandværksvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1361, 'Vandværksvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1362, 'Vangedevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1363, 'Vangevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1364, 'Varehusvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1365, 'Varmedalsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1366, 'Vasevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1367, 'Ved Diget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1368, 'Ved Gadekæret', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1369, 'Ved Gadekæret', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1370, 'Ved Grædehøj', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1371, 'Ved Kignæs', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1372, 'Ved Kilden', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1373, 'Ved Kirken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1374, 'Ved Mosen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1375, 'Ved Nørreparken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1376, 'Ved Skellet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1377, 'Ved Stranden', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1378, 'Ved Vigen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1379, 'Ved Åen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1428, 'Vellerupvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1429, 'Venslev Huse', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1433, 'Venslev Strand', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1434, 'Venslev Søpark', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1435, 'Venslevleddet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1437, 'Ventevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1438, 'Ventevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1439, 'Vermundsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1440, 'Vermundsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1441, 'Vestergaardsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1442, 'Vestergade', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1444, 'Vestermoseparken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1445, 'Vestervangsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1447, 'Vestervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1448, 'Vestervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1450, 'Vibevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1451, 'Vibevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1453, 'Vibevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1454, 'Vibevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1455, 'Vibevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1456, 'Vidarsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1457, 'Viermosevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1458, 'Vifilsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1460, 'Vigvejen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1461, 'Vikingevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1462, 'Vildbjergvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1463, 'Vildrosevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1464, 'Vinkelstien', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1465, 'Vinkelvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1466, 'Vinkelvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1467, 'Vinkelvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1469, 'Vinkelvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1470, 'Violbakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1472, 'Violvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1474, 'Violvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1475, 'Vænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1476, 'Vænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1477, 'Vængetvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1478, 'Vølundsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1480, 'Yderagervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1481, 'Ydermosevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1482, 'Ydunsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1483, 'Ymersvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1484, 'Æblehaven', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1485, 'Æblevang', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1486, 'Ægholm', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1487, 'Ægirsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1490, 'Ørnestens Vænge', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1491, 'Ørnevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1492, 'Ørnevænget', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1493, 'Ørnholmvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1497, 'Østbyvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1498, 'Østergaardsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1499, 'Østergade', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1500, 'Østergade', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1501, 'Østerled', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1502, 'Østersvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1503, 'Østersvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1505, 'Østervej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1506, 'Østkajen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1509, 'Øvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1510, 'Åbjergvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1511, 'Åbrinken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1512, 'Ådalsparken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1513, 'Ådalsvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1514, 'Ågade', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1515, 'Ågårdsstræde', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1516, 'Ålestien', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1518, 'Åskrænten', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1519, 'Åvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1520, 'Åvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1521, 'Lundehusene', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1522, 'Meransletten', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1523, 'Stenøvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1524, 'Rønøvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1525, 'Hyldeholmvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1526, 'Eskilsøvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1527, 'Grevinde Danners Vej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1528, 'Carls Berlings Vej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1529, 'Frederik VII''s Vej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1530, 'Arveprins Frederiks Vej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1531, 'Prins Carls Vej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1532, 'Juliane Maries Vej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1533, 'Christian IV''s Vej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1534, 'Josnekær', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1535, 'Gammel Draabyvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1536, 'Raasigvangen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1537, 'Snogedam', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1538, 'Pedershave Alle', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1539, 'Rørengen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1540, 'Siliciumvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1541, 'Stensbjergvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1542, 'Stensbjerghøj', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1543, 'Haldor Topsøe Park', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1544, 'Svanholm Møllevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1545, 'Svanholm Gods', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1546, 'Camarguevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1547, 'Obvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1548, 'Nilvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1549, 'Okavangovej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1550, 'Mekongvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1551, 'Deltavej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1552, 'Svanholm Skovhavevej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1553, 'Granbakken', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1554, 'Skovbrynet', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1555, 'Slap-a-vej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1556, 'Paradisvej', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1557, 'Grønningen', 1, '0', 3300, 250);
INSERT INTO greg.d_basis_vejnavn VALUES (1558, 'Slangeruphaver', 1, '0', 3300, 250);