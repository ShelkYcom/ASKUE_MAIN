DROP VIEW IF EXISTS v_coords_presence;

CREATE VIEW v_coords_presence AS
SELECT
  a.obj_name                    AS name,        -- из отчёта (столбец A)
  p.id                          AS point_id,    -- null если точки нет
  p.lat, p.lon,
  CASE WHEN p.lat IS NOT NULL AND p.lon IS NOT NULL THEN 1 ELSE 0 END AS has_coords
FROM ais_objects a
LEFT JOIN points p
  ON lower(trim(p.name)) = lower(trim(a.obj_name));
