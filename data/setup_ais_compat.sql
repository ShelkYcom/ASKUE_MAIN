-- setup_ais_compat.sql
-- Совместимо со старыми версиями SQLite (без ON CONFLICT ... DO UPDATE)

PRAGMA journal_mode=WAL;

-- Сырые данные из отчёта (A,B,D,E,F,H)
CREATE TABLE IF NOT EXISTS ais_raw (
  A TEXT,  -- obj_name
  B TEXT,
  D TEXT,
  E TEXT,  -- note
  F TEXT,
  H TEXT,  -- last_poll raw
  imported_at TEXT DEFAULT (datetime('now'))
);

-- Нормализованная таблица
CREATE TABLE IF NOT EXISTS ais_objects (
  obj_name        TEXT PRIMARY KEY, -- A
  colB            TEXT,             -- B
  colD            TEXT,             -- D
  note            TEXT,             -- E
  colF            TEXT,             -- F
  last_poll_dt    TEXT,             -- ISO-8601
  imported_at     TEXT DEFAULT (datetime('now'))
);

-- Ручные пометки "отключен"
CREATE TABLE IF NOT EXISTS manual_disabled (
  obj_name    TEXT PRIMARY KEY,
  disabled    INTEGER NOT NULL CHECK (disabled IN (0,1)),
  reason      TEXT,
  updated_at  TEXT DEFAULT (datetime('now'))
);

-- Временное представление base с нормализацией даты dd.mm.yyyy[ HH:MM[:SS]]
DROP VIEW IF EXISTS _ais_base;
CREATE TEMP VIEW _ais_base AS
SELECT
  trim(A) AS obj_name,
  B       AS colB,
  D       AS colD,
  E       AS note,
  F       AS colF,
  CASE
    WHEN H GLOB '[0-3][0-9].[0-1][0-9].[1-2][0-9][0-9][0-9]*'
    THEN
      substr(H,7,4) || '-' || substr(H,4,2) || '-' || substr(H,1,2) ||
      CASE
        WHEN length(H) > 10
        THEN ' ' ||
             printf('%02d', CAST(substr(H,12,2) AS INT)) || ':' ||
             printf('%02d', CAST(substr(H,15,2) AS INT)) ||
             CASE WHEN length(H) >= 19
                  THEN ':' || printf('%02d', CAST(substr(H,18,2) AS INT))
                  ELSE '' END
        ELSE '' END
    ELSE NULL
  END AS last_poll_dt_iso
FROM ais_raw;

-- Обновляем существующие записи
UPDATE ais_objects
SET
  colB = (SELECT colB FROM _ais_base b WHERE b.obj_name = ais_objects.obj_name),
  colD = (SELECT colD FROM _ais_base b WHERE b.obj_name = ais_objects.obj_name),
  note = (SELECT note FROM _ais_base b WHERE b.obj_name = ais_objects.obj_name),
  colF = (SELECT colF FROM _ais_base b WHERE b.obj_name = ais_objects.obj_name),
  last_poll_dt = (SELECT last_poll_dt_iso FROM _ais_base b WHERE b.obj_name = ais_objects.obj_name),
  imported_at = datetime('now')
WHERE obj_name IN (SELECT obj_name FROM _ais_base);

-- Вставляем новые записи
INSERT OR IGNORE INTO ais_objects(obj_name, colB, colD, note, colF, last_poll_dt)
SELECT b.obj_name, b.colB, b.colD, b.note, b.colF, b.last_poll_dt_iso
FROM _ais_base b
LEFT JOIN ais_objects a ON a.obj_name = b.obj_name
WHERE a.obj_name IS NULL;

-- Представление статусов
DROP VIEW IF EXISTS v_ais_status;
CREATE VIEW v_ais_status AS
SELECT
  a.obj_name,
  a.last_poll_dt,
  a.note,
  CASE WHEN md.disabled = 1
       THEN 1
       ELSE CASE WHEN instr(lower(COALESCE(a.note,'')),'отключ') > 0
                 THEN 1 ELSE 0 END
  END AS is_disabled,
  CASE
    WHEN (CASE WHEN md.disabled = 1 THEN 1
               ELSE CASE WHEN instr(lower(COALESCE(a.note,'')),'отключ') > 0
                         THEN 1 ELSE 0 END
          END) = 1
      THEN 'disabled'
    WHEN a.last_poll_dt IS NULL
      THEN 'broken'
    WHEN datetime(a.last_poll_dt) < datetime('now','-24 hours')
      THEN 'broken'
    ELSE 'working'
  END AS status_for_map
FROM ais_objects a
LEFT JOIN manual_disabled md USING (obj_name);
