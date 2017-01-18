DROP VIEW IF EXISTS greg.v_oversigt_elementer;

CREATE VIEW greg.v_oversigt_elementer AS

SELECT 	
	c.hovedelement_kode AS h_element_kode,
	c.hovedelement_tekst,
	b.element_kode,
	b.element_tekst,
	a.underelement_kode AS u_element_kode,
	a.underelement_tekst AS underlement_tekst,
	a.objekt_type
FROM greg.d_basis_underelementer a
LEFT JOIN greg.d_basis_elementer b ON a.element_kode = b.element_kode
LEFT JOIN greg.d_basis_hovedelementer c ON b.hovedelement_kode = c.hovedelement_kode
WHERE a.aktiv = 1 AND b.aktiv = 1 AND c.aktiv = 1

ORDER BY
	CASE 
		WHEN c.hovedelement_kode ILIKE 'GR' 
		THEN 10
		WHEN c.hovedelement_kode ILIKE 'BL' 
		THEN 20
		WHEN c.hovedelement_kode ILIKE 'BU' 
		THEN 30
		WHEN c.hovedelement_kode ILIKE 'HÆ' 
		THEN 40
		WHEN c.hovedelement_kode ILIKE 'TR' 
		THEN 50
		WHEN c.hovedelement_kode ILIKE 'VA' 
		THEN 60
		WHEN c.hovedelement_kode ILIKE 'BE' 
		THEN 70
		WHEN c.hovedelement_kode ILIKE 'UD' 
		THEN 80
		WHEN c.hovedelement_kode ILIKE 'ANA' 
		THEN 90
		WHEN c.hovedelement_kode ILIKE 'REN' 
		THEN 100
		ELSE 85 END, 
	b.element_kode, 
	a.underelement_kode;

COMMENT ON VIEW greg.v_oversigt_elementer IS 'Elementoversigt. Benyttes i Lister.xlsx';



DROP VIEW IF EXISTS greg.v_oversigt_elementer_2;

CREATE VIEW greg.v_oversigt_elementer_2 AS

SELECT 	
	underelement_kode || ' ' || underelement_tekst AS underelement,
	enhedspris,
	enhedspris_klip,
	pris_enhed
FROM greg.d_basis_underelementer a
LEFT JOIN greg.d_basis_elementer b ON a.element_kode = b.element_kode
LEFT JOIN greg.d_basis_hovedelementer c ON b.hovedelement_kode = c.hovedelement_kode
WHERE RIGHT(underelement_kode, 2) NOT LIKE '00' AND a.aktiv = 1 AND b.aktiv = 1 AND c.aktiv = 1

ORDER BY underelement_kode;

COMMENT ON VIEW greg.v_oversigt_elementer_2 IS 'Elementoversigt. Benyttes i Mængder ift arealtyper - Rpport - TUNG.xlsm';