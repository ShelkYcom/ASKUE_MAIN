from flask import Blueprint, render_template, jsonify
import os
import sqlite3  # <-- добавили

map_bp = Blueprint('map', __name__, url_prefix='/map', template_folder='templates')

# Путь к БД (../.. от этого файла -> корень проекта -> data/app.sqlite)
DB_PATH = os.path.join(os.path.dirname(__file__), '..', '..', 'data', 'app.sqlite')
DB_PATH = os.path.normpath(DB_PATH)

def load_data_from_sqlite():
    if not os.path.exists(DB_PATH):
        return []
    con = sqlite3.connect(DB_PATH)
    con.row_factory = sqlite3.Row
    cur = con.execute("""
        SELECT id, name, lat, lon, status
        FROM points
    """)
    rows = [dict(r) for r in cur.fetchall()]
    con.close()
    return rows

@map_bp.route('/')
def index():
    return render_template('map/index.html')

@map_bp.route('/api/objects')
def get_objects():
    data = load_data_from_sqlite()   # <-- теперь из SQLite
    return jsonify(data)