require("dotenv").config();
const Database = require("better-sqlite3");

const db = new Database(process.env.DB_PATH || "./data/app.sqlite");

db.exec("BEGIN");
try {
  // 1) колонки lat6/lon6 (если вдруг нет)
  const cols = db.prepare(`PRAGMA table_info(points)`).all().map(c => c.name);
  if (!cols.includes("lat6")) db.exec(`ALTER TABLE points ADD COLUMN lat6 REAL`);
  if (!cols.includes("lon6")) db.exec(`ALTER TABLE points ADD COLUMN lon6 REAL`);

  // 2) заполнить нормализованные координаты
  db.exec(`
    UPDATE points
    SET lat6 = ROUND(lat, 6),
        lon6 = ROUND(lon, 6)
    WHERE lat6 IS NULL OR lon6 IS NULL
  `);

  // 3) удалить дубли по (name, lat6, lon6), оставив минимальный id
  db.exec(`
    DELETE FROM points
    WHERE id NOT IN (
      SELECT MIN(id)
      FROM points
      GROUP BY name, lat6, lon6
    )
  `);

  // 4) заменить уникальный индекс: было (lat6,lon6) -> стало (name,lat6,lon6)
  db.exec(`DROP INDEX IF EXISTS unique_points_latlon`);
  db.exec(`
    CREATE UNIQUE INDEX IF NOT EXISTS unique_points_name_latlon
    ON points(name, lat6, lon6)
  `);

  db.exec("COMMIT");
  console.log("[OK] Уникальность теперь по (name, lat6, lon6). Дубли очищены.");
} catch (e) {
  db.exec("ROLLBACK");
  console.error("[ERR] Миграция не удалась:", e.message);
  process.exit(1);
}
