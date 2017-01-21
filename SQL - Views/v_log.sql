DROP VIEW IF EXISTS greg.v_log_xxxx;

CREATE VIEW greg.v_log_xxxx AS

SELECT 	
	*
FROM greg.f_aendring_log (xxxx);

COMMENT ON VIEW greg.v_log_xxxx IS 'Ændringslog, som registrerer alle handlinger indenfor et givent år (xxxx). Benyttes i Ændringslog.xlsx';