-- update_points_status_2d.sql
DROP VIEW IF EXISTS v_ais_last_poll;
CREATE VIEW v_ais_last_poll AS
SELECT
  trim(A) AS name,
  CASE
    WHEN H GLOB '[0-3][0-9].[0-1][0-9].[1-2][0-9][0-9][0-9]*'
    THEN
      substr(H,7,4)||'-'||substr(H,4,2)||'-'||substr(H,1,2) ||
      CASE WHEN length(H) > 10
           THEN ' '||printf('%02d',CAST(substr(H,12,2) AS INT))||':'||
                        printf('%02d',CAST(substr(H,15,2) AS INT))
           ELSE '' END
    ELSE NULL
  END AS last_poll_iso
FROM ais_raw;

UPDATE points
SET status = CASE
  WHEN (SELECT datetime(last_poll_iso) FROM v_ais_last_poll v WHERE v.name = points.name) IS NULL
    THEN 'broken'
  WHEN (SELECT datetime(last_poll_iso) FROM v_ais_last_poll v WHERE v.name = points.name) < datetime('now','-48 hours')
    THEN 'broken'
  ELSE 'works'
END;
