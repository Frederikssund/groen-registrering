DROP VIEW IF EXISTS greg.v_maengder_underelementer_omraader;

CREATE VIEW greg.v_maengder_underelementer_omraader AS

SELECT
	b.pg_distrikt_nr || ' ' || b.pg_distrikt_tekst AS omraade,
	c.underelement_kode,
	c.underelement_tekst AS underelement,
	0 AS antal,
	0.0 AS laengde,
	SUM(ST_Area(a.geometri)) AS areal,
	CASE
		WHEN LEFT(c.underelement_kode,2) LIKE 'HÆ'
		THEN SUM(ST_Area(a.geometri)) + SUM(a.klip_sider * a.hoejde * ST_Perimeter(a.geometri)) / 2
		ELSE 0.0
	END AS klippeflade
FROM greg.t_greg_flader a
LEFT JOIN greg.t_greg_omraader b ON a.arbejdssted = b.pg_distrikt_nr
LEFT JOIN greg.d_basis_underelementer c ON a.underelement_kode = c.underelement_kode
WHERE b.aktiv = 1
GROUP BY omraade, c.underelement_kode, underelement

UNION ALL

SELECT
	b.pg_distrikt_nr || ' ' || b.pg_distrikt_tekst AS omraade,
	c.underelement_kode,
	c.underelement_tekst AS underelement,
	0 AS antal,
	SUM(ST_Length(a.geometri)) AS laengde,
	0.0 AS areal,
	CASE
		WHEN c.underelement_kode = 'BL-05-02'
		THEN SUM(ST_Length(a.geometri) * a.hoejde)
		ELSE 0.0
	END AS klippeflade
FROM greg.t_greg_linier a
LEFT JOIN greg.t_greg_omraader b ON a.arbejdssted = b.pg_distrikt_nr
LEFT JOIN greg.d_basis_underelementer c ON a.underelement_kode = c.underelement_kode
WHERE b.aktiv = 1
GROUP BY omraade, c.underelement_kode, underelement

UNION ALL

SELECT
	b.pg_distrikt_nr || ' ' || b.pg_distrikt_tekst AS omraade,
	c.underelement_kode,
	c.underelement_tekst AS underelement,
	COUNT(a.underelement_kode) AS antal,
	0.0 AS laengde,
	0.0 AS areal,
	0.0 AS klippeflade
FROM greg.t_greg_punkter a
LEFT JOIN greg.t_greg_omraader b ON a.arbejdssted = b.pg_distrikt_nr
LEFT JOIN greg.d_basis_underelementer c ON a.underelement_kode = c.underelement_kode
WHERE b.aktiv = 1 AND a.underelement_kode NOT ILIKE 'REN%'
GROUP BY omraade, c.underelement_kode, underelement

UNION ALL

SELECT
	b.pg_distrikt_nr || ' ' || b.pg_distrikt_tekst AS omraade,
	c.underelement_kode,
	c.underelement_tekst AS underelement,
	0 AS antal,
	0.0 AS laengde,
	SUM(e.areal) AS areal,
	0.0 AS klippeflade
FROM greg.t_greg_punkter a
LEFT JOIN greg.t_greg_omraader b ON a.arbejdssted = b.pg_distrikt_nr
LEFT JOIN greg.d_basis_underelementer c ON a.underelement_kode = c.underelement_kode
LEFT JOIN (	SELECT	arbejdssted,
					SUM(ST_Area(geometri)) AS areal
				FROM greg.t_greg_flader
				WHERE LEFT(underelement_kode, 3) NOT IN ('ANA', 'VA-')
				GROUP BY arbejdssted) e 
			ON b.pg_distrikt_nr = e.arbejdssted
WHERE a.underelement_kode ILIKE 'REN%' AND b.aktiv = 1
GROUP BY omraade, c.underelement_kode, underelement

ORDER BY omraade, underelement_kode;

COMMENT ON VIEW greg.v_maengder_underelementer_omraader IS 'Oversigt over mængder. Benyttes i Mængdekort.xlsm';