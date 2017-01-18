DROP VIEW IF EXISTS greg.v_geom_contain;

CREATE VIEW greg.v_geom_contain AS

SELECT 
	a.versions_id::text || b.versions_id::text AS versions_id, 
	a.versions_id AS id,
	a.geometri 
FROM greg.t_greg_flader a, greg.t_greg_flader b
WHERE a.versions_id <> b.versions_id AND ST_Contains(b.geometri,a.geometri);

COMMENT ON VIEW greg.v_geom_contain IS 'Kontrol: Elementer inde i andre elementer.';



DROP VIEW IF EXISTS greg.v_geom_outside_l;

CREATE VIEW greg.v_geom_outside_l AS

SELECT 
	a.* 
FROM greg.t_greg_linier a
LEFT JOIN greg.t_greg_omraader b ON a.arbejdssted = b.pg_distrikt_nr
WHERE ST_Disjoint(a.geometri, b.geometri);

COMMENT ON VIEW greg.v_geom_outside_l IS 'Kontrol: Linier udenfor områdegrænse';



DROP VIEW IF EXISTS greg.v_geom_outside_p;

CREATE VIEW greg.v_geom_outside_p AS

SELECT 
	a.* 
FROM greg.t_greg_punkter a
LEFT JOIN greg.t_greg_omraader b ON a.arbejdssted = b.pg_distrikt_nr
WHERE ST_Disjoint(a.geometri, b.geometri);

COMMENT ON VIEW greg.v_geom_outside_p IS 'Kontrol: Punkter udenfor områdegrænse';