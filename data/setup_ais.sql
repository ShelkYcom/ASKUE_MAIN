-- setup_ais.sql
-- Минимальная схема БД и представление статуса

PRAGMA journal_mode=WAL;

CREATE TABLE IF NOT EXISTS ais_raw (
  A TEXT,  -- obj_name
  B TEXT,
  D TEXT,
  E TEXT,  -- note (может содержать 'отключен')
  F TEXT,
  H TEXT,  -- last_poll raw
  imported_at TEXT DEFAULT (datetime('now'))
);

-- Основная таблица с нормализованной датой (ISO)
CREATE TABLE IF NOT EXISTS ais_objects (
  obj_name        TEXT PRIMARY KEY, -- A
  colB            TEXT,             -- B
  colD            TEXT,             -- D
  note            TEXT,             -- E
  colF            TEXT,             -- F
  last_poll_dt    TEXT,             -- ISO-8601
  imported_at     TEXT DEFAULT (datetime('now'))
);

-- Ручные пометки отключения
CREATE TABLE IF NOT EXISTS manual_disabled (
  obj_name    TEXT PRIMARY KEY,
  disabled    INTEGER NOT NULL CHECK (disabled IN (0,1)),
  reason      TEXT,
  updated_at  TEXT DEFAULT (datetime('now'))
);

-- Перенос данных из ais_raw в ais_objects с нормализацией даты.
-- Нормализуем формат dd.mm.yyyy[ HH:MM[:SS]] в ISO: yyyy-mm-dd HH:MM:SS
WITH base AS (
  SELECT
    trim(A)       AS obj_name,
    B             AS colB,
    D             AS colD,
    E             AS note,
    F             AS colF,
    H             AS last_poll_raw
  FROM ais_raw
)
INSERT INTO ais_objects(obj_name, colB, colD, note, colF, last_poll_dt)
SELECT
  obj_name, colB, colD, note, colF,
  CASE
    WHEN last_poll_raw GLOB '[0-3][0-9].[0-1][0-9].[1-2][0-9][0-9][0-9]*'
    THEN
      -- dd.mm.yyyy -> yyyy-mm-dd
      substr(last_poll_raw, 7, 4) || '-' || substr(last_poll_raw, 4, 2) || '-' || substr(last_poll_raw, 1, 2) ||
      CASE
        WHEN length(last_poll_raw) > 10
          THEN ' ' || printf('%02d', CAST(substr(last_poll_raw, 12, 2) AS INT)) || ':' ||
                       printf('%02d', CAST(substr(last_poll_raw, 15, 2) AS INT)) ||
                       CASE WHEN length(last_poll_raw) >= 19 THEN ':' || printf('%02d', CAST(substr(last_poll_raw, 18, 2) AS INT)) ELSE '' END
        ELSE ''
      END
    ELSE NULL
  END AS last_poll_dt_iso
FROM base
ON CONFLICT(obj_name) DO UPDATE SET
  colB=excluded.colB,
  colD=excluded.colD,
  note=excluded.note,
  colF=excluded.colF,
  last_poll_dt=excluded.last_poll_dt,
  imported_at=datetime('now');

-- Представление для карты/аналитики
-- Порог 24 часа; можно заменить '-24 hours' на '-72 hours' или '-7 days'
CREATE VIEW IF NOT EXISTS v_ais_status AS
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
