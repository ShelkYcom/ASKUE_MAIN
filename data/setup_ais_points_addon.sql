-- setup_ais_points_addon.sql
CREATE VIEW IF NOT EXISTS v_map_points AS
SELECT
  p.id,
  p.name,
  p.lat,
  p.lon,
  p.voltage_kv,
  p.status               AS points_status_raw,
  s.status_for_map,
  s.is_disabled,
  s.last_poll_dt,
  datetime('now')        AS generated_at
FROM points p
LEFT JOIN v_ais_status s
  ON s.obj_name = p.name;

CREATE VIEW IF NOT EXISTS v_missing_coords AS
SELECT a.obj_name, a.last_poll_dt, a.note
FROM ais_objects a
LEFT JOIN points p
  ON p.name = a.obj_name
WHERE p.name IS NULL OR p.lat IS NULL OR p.lon IS NULL
ORDER BY a.obj_name;

CREATE VIEW IF NOT EXISTS v_map_points_geojson AS
SELECT json_object(
  'type','FeatureCollection',
  'features', json_group_array(
    json_object(
      'type','Feature',
      'geometry', json_object(
        'type','Point',
        'coordinates', json_array(p.lon, p.lat)
      ),
      'properties', json_object(
        'id', p.id,
        'name', p.name,
        'voltage_kv', p.voltage_kv,
        'status', s.status_for_map,
        'is_disabled', s.is_disabled,
        'last_poll_dt', s.last_poll_dt
      )
    )
  )
) AS geojson
FROM points p
LEFT JOIN v_ais_status s ON s.obj_name = p.name
WHERE p.lat IS NOT NULL AND p.lon IS NOT NULL;
