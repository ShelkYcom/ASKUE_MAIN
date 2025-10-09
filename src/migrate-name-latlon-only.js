require("dotenv").config();
const Database = require("better-sqlite3");

const db = new Database(process.env.DB_PATH || "./data/app.sqlite");

db.exec("BEGIN");
try {
  // 0) удалить дубли по (name, lat, lon), оставить минимальный id
  db.exec(`
    DELETE FROM points
    WHERE id NOT IN (
      SELECT MIN(id)
      FROM points
      GROUP BY name, lat, lon
    )
  `);

  // 1) снести старые индексы, если были
  db.exec(`DROP INDEX IF EXISTS unique_points_latlon`);
  db.exec(`DROP INDEX IF EXISTS unique_points_name_latlon`);

  // 2) создать единственный нужный уникальный индекс
  db.exec(`
    CREATE UNIQUE INDEX IF NOT EXISTS unique_points_name_lat_lon
    ON points(name, lat, lon)
  `);

  // 3) попытаться убрать лишние колонки lat6/lon6 (если существуют)
  const cols = db.prepare(`PRAGMA table_info(points)`).all().map(c => c.name);
  if (cols.includes("lat6")) {
    try { db.exec(`ALTER TABLE points DROP COLUMN lat6`); } catch {}
  }
  if (cols.includes("lon6")) {
    try { db.exec(`ALTER TABLE points DROP COLUMN lon6`); } catch {}
  }

  db.exec("COMMIT");
  console.log("[OK] Уникальность теперь по (name, lat, lon). Дубли очищены. Лишние колонки удалены (если поддерживается).");
} catch (e) {
  db.exec("ROLLBACK");
  console.error("[ERR] Миграция не удалась:", e.message);
  process.exit(1);
}
