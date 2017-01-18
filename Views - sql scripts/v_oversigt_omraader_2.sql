DROP VIEW IF EXISTS greg.v_oversigt_omraade_2;

CREATE VIEW greg.v_oversigt_omraade_2 AS

SELECT 	
	CASE
		WHEN a.pg_distrikt_tekst IS NULL 
		THEN a.pg_distrikt_nr::bpchar
		ELSE a.pg_distrikt_nr || ' ' || a.pg_distrikt_tekst
	END AS omraade,
	a.postnr || ' ' || c.distriktnavn AS distrikt,
	CASE
		WHEN a.vejnr IS NOT NULL
		THEN b.vejnavn || ' ' || a.vejnr
		ELSE b.vejnavn
	END AS adresse,
	a.pg_distrikt_type AS arealtype
FROM greg.t_greg_omraader a
LEFT JOIN greg.d_basis_vejnavn b ON a.vejkode = b.vejkode
LEFT JOIN greg.d_basis_postdistrikter c ON a.postnr = c.postdistrikt
WHERE a.aktiv = 1

ORDER BY a.pg_distrikt_nr;

COMMENT ON VIEW greg.v_oversigt_omraade_2 IS 'Områdeoversigt. Benyttes i Lister.xlsx';