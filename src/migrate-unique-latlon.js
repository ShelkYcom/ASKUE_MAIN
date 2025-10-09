require("dotenv").config();
const Database = require("better-sqlite3");

const db = new Database(process.env.DB_PATH || "./data/app.sqlite");

// 1) Добавим колонки lat6/lon6 (если их ещё нет)
const cols = db.prepare(`PRAGMA table_info(points)`).all().map(c => c.name);
db.exec("BEGIN");
try {
  if (!cols.includes("lat6")) db.exec(`ALTER TABLE points ADD COLUMN lat6 REAL`);
  if (!cols.includes("lon6")) db.exec(`ALTER TABLE points ADD COLUMN lon6 REAL`);

  // 2) Заполним lat6/lon6 округлением до 6 знаков
  db.exec(`
    UPDATE points
    SET lat6 = ROUND(lat, 6),
        lon6 = ROUND(lon, 6)
    WHERE lat6 IS NULL OR lon6 IS NULL
  `);

  // 3) Удалим дубли, оставив минимальный id для каждой пары (lat6,lon6)
  db.exec(`
    DELETE FROM points
    WHERE id NOT IN (
      SELECT MIN(id)
      FROM points
      GROUP BY lat6, lon6
    )
  `);

  // 4) Уникальный индекс на (lat6, lon6)
  db.exec(`
    CREATE UNIQUE INDEX IF NOT EXISTS unique_points_latlon
    ON points(lat6, lon6)
  `);

  db.exec("COMMIT");
  console.log("[OK] Миграция завершена: добавлены lat6/lon6, дубли удалены, индекс создан.");
} catch (e) {
  db.exec("ROLLBACK");
  console.error("[ERR] Миграция не удалась:", e.message);
  process.exit(1);
}
