DROP VIEW IF EXISTS greg.v_historik_punkter;

CREATE VIEW greg.v_historik_punkter AS

SELECT
	*
FROM greg.f_dato_punkter(int,int,int);

COMMENT ON VIEW  IS 'Simulering af registreringen på en bestemt dato. Format: dd-MM-yyyy.';



DROP VIEW IF EXISTS greg.v_historik_linier;

CREATE VIEW greg.v_historik_linier AS

SELECT
	*
FROM greg.f_dato_linier(int,int,int);

COMMENT ON VIEW  IS 'Simulering af registreringen på en bestemt dato. Format: dd-MM-yyyy.';



DROP VIEW IF EXISTS greg.v_historik_flader;

CREATE VIEW greg.v_historik_flader AS

SELECT
	*
FROM greg.f_dato_flader(int,int,int);

COMMENT ON VIEW  IS 'Simulering af registreringen på en bestemt dato. Format: dd-MM-yyyy.';