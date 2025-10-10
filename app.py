from flask import Flask, render_template, jsonify
import pandas as pd
import os, sqlite3
from datetime import datetime, timedelta

# Импортируем модули
from modules.map.routes import map_bp
from modules.requests.routes import requests_bp

DB_PATH = os.environ.get('DB_PATH', './data/app.sqlite')


def _connect():
    con = sqlite3.connect(DB_PATH)
    con.row_factory = sqlite3.Row
    return con


def _parse_last_poll(s: str):
    """Пытаемся распарсить дату из H (включая возможные форматы из Excel)."""
    if not s:
        return None
    s = str(s).strip()
    # Excel-серийный номер (целое число дней от 1899-12-30)
    if s.isdigit():
        origin = datetime(1899, 12, 30)
        return origin + timedelta(days=int(s))
    # Популярные текстовые форматы
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M",
                "%d.%m.%Y %H:%M:%S", "%d.%m.%Y %H:%M", "%d.%m.%Y"):
        try:
            return datetime.strptime(s, fmt)
        except ValueError:
            pass
    return None


def _status_by_last_poll(dt: datetime):
    if not dt:
        return "broken"
    return "works" if (datetime.now() - dt) <= timedelta(days=2) else "broken"


def create_app():
    app = Flask(__name__)
    app.config['SECRET_KEY'] = 'ваш-секретный-ключ'

    # Регистрируем модули
    app.register_blueprint(map_bp)
    app.register_blueprint(requests_bp)

    # Главная страница
    @app.route('/')
    def index():
        return render_template('index.html')

    # 💡 Наш новый маршрут переносим сюда
    @app.get("/map/api/object/<path:object_name>/connections")
    def api_object_connections(object_name):
        """
        Возвращает список присоединений для объекта с именем = A,
        с полями:
          connection (B), ip (D), name (E), device (F), last_poll (H), status
        """
        q = """
            SELECT
                TRIM(B) AS connection,
                TRIM(D) AS ip,
                TRIM(E) AS name,
                TRIM(F) AS device,
                TRIM(H) AS last_poll
            FROM ais_raw
            WHERE TRIM(A) = TRIM(?)
            ORDER BY connection COLLATE NOCASE
        """
        with _connect() as con:
            rows = [dict(r) for r in con.execute(q, (object_name,)).fetchall()]

        for r in rows:
            dt = _parse_last_poll(r.get("last_poll"))
            r["status"] = _status_by_last_poll(dt)

        return jsonify({
            "object": object_name,
            "count": len(rows),
            "connections": rows
        })

    return app


app = create_app()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=True)
