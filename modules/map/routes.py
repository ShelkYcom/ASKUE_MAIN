from flask import Blueprint, render_template, jsonify
import pandas as pd
import os

map_bp = Blueprint('map', __name__, url_prefix='/map', template_folder='templates')

EXCEL_FILE_PATH = 'statuses.xlsx'

def load_data_from_excel():
    if not os.path.exists(EXCEL_FILE_PATH):
        return []
    df = pd.read_excel(EXCEL_FILE_PATH)
    return df.to_dict('records')

@map_bp.route('/')
def index():
    return render_template('map/index.html')

@map_bp.route('/api/objects')
def get_objects():
    data = load_data_from_excel()
    return jsonify(data)