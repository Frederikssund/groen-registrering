DROP VIEW IF EXISTS greg.v_maengder_institutioner;

CREATE VIEW greg.v_maengder_institutioner AS

SELECT -- Den samlede flade fordelt på områder og elementer
	b.pg_distrikt_type AS omraadetype,
	b.pg_distrikt_nr AS omraadenr,
	b.pg_distrikt_tekst AS omraade,
	d.element_kode AS elementkode,
	d.element_kode || ' ' || d.element_tekst AS element,
	c.underelement_kode AS underelementkode,
	c.underelement_kode || ' ' || c.underelement_tekst AS underelement,
	0 AS antal,
	0.0 AS laengde,
	SUM(public.ST_Area(a.geometri)) AS areal,
	CASE
		WHEN LEFT(c.underelement_kode,2) LIKE 'HÆ' 
		THEN SUM(public.ST_Area(a.geometri)) + SUM(a.klip_sider * a.hoejde * public.ST_Perimeter(a.geometri)) / 2
		ELSE 0.0
	END AS klippeflade,
	CASE
		WHEN LEFT(c.underelement_kode,2) LIKE 'HÆ'
		THEN c.enhedspris * SUM(public.ST_Area(a.geometri)) + c.enhedspris_klip * (SUM(public.ST_Area(a.geometri)) + SUM(a.klip_sider * a.hoejde * public.ST_Perimeter(a.geometri)) / 2)
		ELSE c.enhedspris * SUM(public.ST_Area(a.geometri))
	END AS pris
FROM greg.t_greg_flader a
LEFT JOIN greg.t_greg_omraader b ON a.arbejdssted = b.pg_distrikt_nr
LEFT JOIN greg.d_basis_underelementer c ON a.underelement_kode = c.underelement_kode
LEFT JOIN greg.d_basis_elementer d ON c.element_kode = d.element_kode
WHERE b.aktiv = 1
GROUP BY omraadetype, omraadenr, omraade, elementkode, element, underelementkode, underelement

UNION ALL

SELECT -- Den samlede mængde i linier fordelt på områder og elementer
	b.pg_distrikt_type AS omraadetype,
	b.pg_distrikt_nr AS omraadenr,
	b.pg_distrikt_tekst AS omraade,
	d.element_kode AS elementkode,
	d.element_kode || ' ' || d.element_tekst AS element,
	c.underelement_kode AS underelementkode,
	c.underelement_kode || ' ' || c.underelement_tekst AS underelement,
	0 AS antal,
	SUM(public.ST_Length(a.geometri)) AS laengde,
	0.0 AS areal,
	CASE
		WHEN c.underelement_kode = 'BL-05-02' 
		THEN SUM(a.hoejde * public.ST_Length(a.geometri))
		ELSE 0.0
	END AS klippeflade,
	CASE
		WHEN c.underelement_kode = 'BL-05-02'
		THEN c.enhedspris * SUM(public.ST_Length(a.geometri)) + c.enhedspris_klip * SUM(a.hoejde * public.ST_Length(a.geometri))
		ELSE c.enhedspris * SUM(public.ST_Length(a.geometri))
	END AS pris
FROM greg.t_greg_linier a
LEFT JOIN greg.t_greg_omraader b ON a.arbejdssted = b.pg_distrikt_nr
LEFT JOIN greg.d_basis_underelementer c ON a.underelement_kode = c.underelement_kode
LEFT JOIN greg.d_basis_elementer d ON c.element_kode = d.element_kode
WHERE b.aktiv = 1
GROUP BY omraadetype, omraadenr, omraade, elementkode, element, underelementkode, underelement

UNION ALL

SELECT -- Det samlede antal punkter fordelt på områder og elementer (Renhold undladt)
	b.pg_distrikt_type AS omraadetype,
	b.pg_distrikt_nr AS omraadenr,
	b.pg_distrikt_tekst AS omraade,
	d.element_kode AS elementkode,
	d.element_kode || ' ' || d.element_tekst AS element,
	c.underelement_kode AS underelementkode,
	c.underelement_kode || ' ' || c.underelement_tekst AS underelement,
	COUNT(a.underelement_kode) AS antal,
	0.0 AS laengde,
	0.0 AS areal,
	0.0 AS klippeflade,
	COUNT(a.underelement_kode) * c.enhedspris AS pris
FROM greg.t_greg_punkter a
LEFT JOIN greg.t_greg_omraader b ON a.arbejdssted = b.pg_distrikt_nr
LEFT JOIN greg.d_basis_underelementer c ON a.underelement_kode = c.underelement_kode
LEFT JOIN greg.d_basis_elementer d ON c.element_kode = d.element_kode
WHERE a.underelement_kode NOT ILIKE 'REN%' AND b.aktiv = 1
GROUP BY omraadetype, omraadenr, omraade, elementkode, element, underelementkode, underelement

UNION ALL

SELECT -- Renhold som arealet af de repsketive områders elementer fratukket 'Anden anvendelse' og 'Vand'
	b.pg_distrikt_type AS omraadetype,
	b.pg_distrikt_nr AS omraadenr,
	b.pg_distrikt_tekst AS omraade,
	d.element_kode AS elementkode,
	d.element_kode || ' ' || d.element_tekst AS element,
	c.underelement_kode AS underelementkode,
	c.underelement_kode || ' ' || c.underelement_tekst AS underelement,
	0 AS antal,
	0.0 AS laengde,
	SUM(e.areal) AS areal,
	0.0 AS klippeflade,
	SUM(e.areal) * c.enhedspris AS pris
FROM greg.t_greg_punkter a
LEFT JOIN greg.t_greg_omraader b ON a.arbejdssted = b.pg_distrikt_nr
LEFT JOIN greg.d_basis_underelementer c ON a.underelement_kode = c.underelement_kode
LEFT JOIN greg.d_basis_elementer d ON c.element_kode = d.element_kode
LEFT JOIN ( SELECT 	arbejdssted, 
					SUM(public.ST_Area(geometri)) AS areal
				FROM greg.t_greg_flader
				WHERE LEFT(underelement_kode, 3) NOT IN ('ANA', 'VA-', 'BE-')
				GROUP BY arbejdssted) e 
		ON b.pg_distrikt_nr = e.arbejdssted
WHERE a.underelement_kode ILIKE 'REN%' AND b.aktiv = 1
GROUP BY omraadetype, omraadenr, omraade, elementkode, element, underelementkode, underelement

ORDER BY omraadetype, omraadenr, underelementkode;

COMMENT ON VIEW greg.v_maengder_institutioner IS 'Udgangspunkt for præsentabel, dog tung rapport i Excel. Benyttes i Mængder ift arealtyper - Rpport - TUNG.xlsm';



DROP VIEW IF EXISTS greg.v_maengder_institutioner2;

CREATE VIEW greg.v_maengder_institutioner2 AS

SELECT -- Den samlede flade fordelt på områder og elementer
	b.pg_distrikt_type AS omraadetype,
	b.pg_distrikt_nr AS omraadenr,
	b.pg_distrikt_tekst AS omraade,
	d.element_kode AS elementkode,
	d.element_kode || ' ' || d.element_tekst AS element,
	c.underelement_kode AS underelementkode,
	c.underelement_kode || ' ' || c.underelement_tekst AS underelement,
	SUM(public.ST_Area(a.geometri)) AS maengde,
	CASE
		WHEN LEFT(c.underelement_kode,2) LIKE 'HÆ'
		THEN SUM(public.ST_Area(a.geometri)) + SUM(a.klip_sider * a.hoejde * public.ST_Perimeter(a.geometri)) / 2
		ELSE 0.0
	END AS klippeflade,
	CASE
		WHEN LEFT(c.underelement_kode,2) LIKE 'HÆ'
		THEN c.enhedspris * SUM(public.ST_Area(a.geometri)) + c.enhedspris_klip * (SUM(public.ST_Area(a.geometri)) + SUM(a.klip_sider * a.hoejde * public.ST_Perimeter(a.geometri)) / 2)
		ELSE c.enhedspris * SUM(public.ST_Area(a.geometri))
	END AS pris
FROM greg.t_greg_flader a
LEFT JOIN greg.t_greg_omraader b ON a.arbejdssted = b.pg_distrikt_nr
LEFT JOIN greg.d_basis_underelementer c ON a.underelement_kode = c.underelement_kode
LEFT JOIN greg.d_basis_elementer d ON c.element_kode = d.element_kode
WHERE b.aktiv = 1
GROUP BY omraadetype, omraadenr, omraade, elementkode, element, underelementkode, underelement

UNION ALL

SELECT -- Den samlede mængde i linier fordelt på områder og elementer
	b.pg_distrikt_type AS omraadetype,
	b.pg_distrikt_nr AS omraadenr,
	b.pg_distrikt_tekst AS omraade,
	d.element_kode AS elementkode,
	d.element_kode || ' ' || d.element_tekst AS element,
	c.underelement_kode AS underelementkode,
	c.underelement_kode || ' ' || c.underelement_tekst AS underelement,
	SUM(public.ST_LENGTH(a.geometri)) AS maengde,
	CASE
		WHEN c.underelement_kode = 'BL-05-02'
		THEN SUM(a.hoejde * public.ST_LENGTH(a.geometri))
		ELSE 0.0
	END AS klippeflade,
	CASE
		WHEN c.underelement_kode = 'BL-05-02' 
		THEN c.enhedspris * SUM(public.ST_LENGTH(a.geometri)) + c.enhedspris_klip * SUM(a.hoejde * public.ST_LENGTH(a.geometri))
		ELSE c.enhedspris * SUM(public.ST_LENGTH(a.geometri))
	END AS pris
FROM greg.t_greg_linier a
LEFT JOIN greg.t_greg_omraader b ON a.arbejdssted = b.pg_distrikt_nr
LEFT JOIN greg.d_basis_underelementer c ON a.underelement_kode = c.underelement_kode
LEFT JOIN greg.d_basis_elementer d ON c.element_kode = d.element_kode
WHERE b.aktiv = 1
GROUP BY omraadetype, omraadenr, omraade, elementkode, element, underelementkode, underelement

UNION ALL

SELECT -- Det samlede antal punkter fordelt på områder og elementer (Renhold undladt)
	b.pg_distrikt_type AS omraadetype,
	b.pg_distrikt_nr AS omraadenr,
	b.pg_distrikt_tekst AS omraade,
	d.element_kode AS elementkode,
	d.element_kode || ' ' || d.element_tekst AS element,
	c.underelement_kode AS underelementkode,
	c.underelement_kode || ' ' || c.underelement_tekst AS underelement,
	COUNT(a.underelement_kode) AS maengde,
	0.0 AS klippeflade,
	COUNT(a.underelement_kode) * c.enhedspris AS pris
FROM greg.t_greg_punkter a
LEFT JOIN greg.t_greg_omraader b ON a.arbejdssted = b.pg_distrikt_nr
LEFT JOIN greg.d_basis_underelementer c ON a.underelement_kode = c.underelement_kode
LEFT JOIN greg.d_basis_elementer d ON c.element_kode = d.element_kode
WHERE a.underelement_kode NOT ILIKE 'REN%' AND b.aktiv = 1
GROUP BY omraadetype, omraadenr, omraade, elementkode, element, underelementkode, underelement

UNION ALL

SELECT -- Renhold som arealet af de repsketive områder fratrukket elementerne 'Anden anvendelse' og 'Vand'
	b.pg_distrikt_type AS omraadetype,
	b.pg_distrikt_nr AS omraadenr,
	b.pg_distrikt_tekst AS omraade,
	d.element_kode AS elementkode,
	d.element_kode || ' ' || d.element_tekst AS element,
	c.underelement_kode AS underelementkode,
	c.underelement_kode || ' ' || c.underelement_tekst AS underelement,
	SUM(e.areal) AS maengde,
	0.0 AS klippeflade,
	SUM(e.areal) * c.enhedspris AS pris
FROM greg.t_greg_punkter a
LEFT JOIN greg.t_greg_omraader b ON a.arbejdssted::integer = b.pg_distrikt_nr
LEFT JOIN greg.d_basis_underelementer c ON a.underelement_kode = c.underelement_kode
LEFT JOIN greg.d_basis_elementer d ON c.element_kode = d.element_kode
LEFT JOIN ( SELECT 	arbejdssted, 
					SUM(public.ST_AREA(geometri)) AS areal
				FROM greg.t_greg_flader
				WHERE LEFT(underelement_kode, 3) NOT IN('ANA', 'VA-', 'BE-')
				GROUP BY arbejdssted) e 
		ON b.pg_distrikt_nr = e.arbejdssted
WHERE a.underelement_kode ILIKE 'REN%' AND b.aktiv = 1
GROUP BY omraadetype, omraadenr, omraade, elementkode, element, underelementkode, underelement

ORDER BY omraadetype, omraadenr, underelementkode;

COMMENT ON VIEW greg.v_maengder_institutioner2 IS 'Udgangspunkt for hurtig rapport i Excel, som er mere overskuelig i en pivottabel. Benyttes i Mængder ift. arealtyper - Overblik.xlsx';