DROP USER IF EXISTS backadm;
CREATE USER backadm SUPERUSER password 'qgis';
ALTER USER backadm set default_transaction_read_only = on;



-- Ryd op i db, hvis qgis_reader allerede eksisterer..
--DROP OWNED BY qgis_reader;
DROP USER IF EXISTS qgis_reader;

-- Opret bruger qgis_reader med password qgis_reader...
CREATE ROLE qgis_reader LOGIN PASSWORD 'qgis_reader' NOSUPERUSER INHERIT NOCREATEDB NOCREATEROLE NOREPLICATION;

-- Adgang til schemaerne greg og greg_hist...
GRANT USAGE ON SCHEMA greg TO qgis_reader;
GRANT USAGE ON SCHEMA greg_history TO qgis_reader;

-- Læserettigheder til qgis_reader på alle eksisterende tabeller...
GRANT SELECT ON ALL TABLES IN SCHEMA greg TO qgis_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA greg_history TO qgis_reader;

-- Læserettigheder til qgis_reader på alle fremtidige tabeller i schemaerne...
ALTER DEFAULT PRIVILEGES IN SCHEMA greg GRANT SELECT ON TABLES TO qgis_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA greg_history GRANT SELECT ON TABLES TO qgis_reader;