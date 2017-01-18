DROP VIEW IF EXISTS greg.v_oversigt_litra;

CREATE VIEW greg.v_oversigt_litra AS

SELECT
	c.pg_distrikt_nr || ' ' || c.pg_distrikt_tekst AS omraade,
	a.underelement_kode,
	b.underelement_tekst,
	a.litra,
	a.hoejde
FROM greg.t_greg_flader a
LEFT JOIN greg.d_basis_underelementer b ON a.underelement_kode = b.underelement_kode
LEFT JOIN greg.t_greg_omraader c ON a.arbejdssted = c.pg_distrikt_nr
WHERE c.aktiv = 1 AND a.litra IS NOT NULL
GROUP BY omraade, a.underelement_kode, b.underelement_tekst, a.litra, a.hoejde

UNION ALL

SELECT
	c.pg_distrikt_nr || ' ' || c.pg_distrikt_tekst AS omraade,
	a.underelement_kode,
	b.underelement_tekst,
	a.litra,
	a.hoejde
FROM greg.t_greg_linier a
LEFT JOIN greg.d_basis_underelementer b ON a.underelement_kode = b.underelement_kode
LEFT JOIN greg.t_greg_omraader c ON a.arbejdssted = c.pg_distrikt_nr
WHERE c.aktiv = 1 AND a.litra IS NOT NULL
GROUP BY omraade, a.underelement_kode, b.underelement_tekst, a.litra, a.hoejde

UNION ALL

SELECT
	c.pg_distrikt_nr || ' ' || c.pg_distrikt_tekst AS omraade,
	a.underelement_kode,
	b.underelement_tekst,
	a.litra,
	a.hoejde
FROM greg.t_greg_punkter a
LEFT JOIN greg.d_basis_underelementer b ON a.underelement_kode = b.underelement_kode
LEFT JOIN greg.t_greg_omraader c ON a.arbejdssted = c.pg_distrikt_nr
WHERE c.aktiv = 1 AND a.litra IS NOT NULL
GROUP BY omraade, a.underelement_kode, b.underelement_tekst, a.litra, a.hoejde

ORDER BY omraade, underelement_kode, litra;

COMMENT ON VIEW greg.v_oversigt_litra IS 'Oversigt over litra og højder. Benyttes i mængdekort.xlsm.';