require("dotenv").config();
const xlsx = require("xlsx");
const fs = require("fs");
const path = require("path");
const Database = require("better-sqlite3");

const dbPath = process.env.DB_PATH || "./data/app.sqlite";
const args = process.argv.slice(2);

// Аргументы: [excelPath] [--replace]
const inputPath = args.find(a => !a.startsWith("--")) || "./data/statuses.xlsx";
const doReplace = args.includes("--replace");

if (!fs.existsSync(inputPath)) {
  console.error(`Файл не найден: ${inputPath}
Использование:
  node ./src/import-from-excel.js ./data/statuses.xlsx [--replace]`);
  process.exit(1);
}

const db = new Database(dbPath);
db.pragma("journal_mode = WAL");

if (doReplace) {
  db.exec("DELETE FROM points");
  console.log("[INFO] Таблица points очищена (--replace).");
}

const wb = xlsx.readFile(inputPath, { cellDates: false });
const sheetName = wb.SheetNames[0];
const sheet = wb.Sheets[sheetName];
if (!sheet) {
  console.error(`[ОШИБКА] В файле нет первого листа. Листы: ${wb.SheetNames.join(", ")}`);
  process.exit(1);
}
const rows = xlsx.utils.sheet_to_json(sheet, { defval: null });

// ожидаемые колонки: name, lat, lon, status
const toNum = (v) => {
  if (v == null || v === "") return NaN;
  if (typeof v === "number") return v;
  if (typeof v === "string") return Number(v.replace(",", ".").replace(/\s+/g, "").trim());
  return Number(v);
};

const insert = db.prepare(`
  INSERT OR IGNORE INTO points
    (ext_id, name, lat, lon, voltage_kv, status)
  VALUES
    (@ext_id, @name, @lat, @lon, @voltage_kv, @status)
`);

let inserted = 0, skipped = 0;
let firstSkipReason = null;

const trx = db.transaction(items => {
  for (const r of items) {
    const name = r["name"];
    const lat = toNum(r["lat"]);
    const lon = toNum(r["lon"]);
    const status = r["status"] != null ? String(r["status"]) : null;

    if (!Number.isFinite(lat) || !Number.isFinite(lon)) {
      skipped++;
      if (!firstSkipReason) {
        firstSkipReason = { row: r, reason: `lat/lon не число (lat='${r["lat"]}', lon='${r["lon"]}')` };
      }
      continue;
    }

    const info = insert.run({
      ext_id: null,
      name: name ? String(name) : "Без названия",
      lat, lon,
      voltage_kv: null,
      status
    });

    if (info.changes > 0) inserted += 1; // дубль name+lat+lon → 0
  }
});

trx(rows);

console.log(`[OK] Excel: "${path.basename(inputPath)}", лист: "${sheetName}"`);
console.log(`[OK] Прочитано строк из Excel: ${rows.length}`);
console.log(`[OK] Вставлено (без дублей name+lat+lon): ${inserted}`);
console.log(`[OK] Пропущено (плохие координаты): ${skipped}`);
if (firstSkipReason) {
  console.log(`[ПРИМЕР ПРОПУЩЕННОЙ] Причина: ${firstSkipReason.reason}`);
  console.log(firstSkipReason.row);
}
console.log(`[OK] База: ${dbPath}`);

