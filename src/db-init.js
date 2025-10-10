require("dotenv").config();
const Database = require("better-sqlite3");
const fs = require("fs");
const path = require("path");

const dbPath = process.env.DB_PATH || "./data/app.sqlite";

// создаём папку data, если её нет
fs.mkdirSync(path.resolve(__dirname, "..", "data"), { recursive: true });

// создаём/открываем БД
const db = new Database(dbPath, { fileMustExist: false });

// включаем WAL для стабильного параллельного чтения
db.pragma("journal_mode = WAL");

// базовая схема
db.exec(`
CREATE TABLE IF NOT EXISTS points (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ext_id TEXT,
  name TEXT NOT NULL,
  lat REAL NOT NULL,
  lon REAL NOT NULL,
  voltage_kv REAL,
  status TEXT,
  updated_at TEXT DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_points_coords ON points(lat, lon);
CREATE INDEX IF NOT EXISTS idx_points_name ON points(name);
`);

console.log("SQLite инициализировано:", dbPath);
