DROP VIEW IF EXISTS greg.v_aendring_flader;

CREATE VIEW greg.v_aendring_flader AS

SELECT
	*
FROM greg.f_tot_flader((x));

COMMENT ON VIEW greg.v_aendring_flader IS 'Ændringsoversigt med tilhørende geometri. Defineret som (x) dage.';



DROP VIEW IF EXISTS greg.v_aendring_linier;

CREATE VIEW greg.v_aendring_linier AS

SELECT
	*
FROM greg.f_tot_linier((x));

COMMENT ON VIEW greg.v_aendring_linier IS 'Ændringsoversigt med tilhørende geometri. Defineret som (x) dage.';



DROP VIEW IF EXISTS greg.v_aendring_punkter;

CREATE VIEW greg.v_aendring_punkter AS

SELECT
	*
FROM greg.f_tot_punkter((x));

COMMENT ON VIEW greg.v_aendring_punkter IS 'Ændringsoversigt med tilhørende geometri. Defineret som (x) dage.';