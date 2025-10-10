DROP VIEW IF EXISTS v_points_not_in_report;
CREATE VIEW v_points_not_in_report AS
SELECT p.id, p.name, p.lat, p.lon
FROM v_norm_points p
LEFT JOIN v_norm_ais a ON a.n_name = p.n_name
WHERE p.has_coords = 1
  AND a.n_name IS NULL;
