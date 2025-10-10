UPDATE points
SET status = CASE
  WHEN datetime(v.last_poll_iso) IS NULL THEN 'broken'
  WHEN datetime(v.last_poll_iso) < datetime('now','-24 hours') THEN 'broken'
  ELSE 'works'
END
FROM v_ais_last_poll v
WHERE v.name = points.name;
