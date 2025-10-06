from flask import Blueprint, render_template

# Создаем Blueprint для модуля заявок
requests_bp = Blueprint('requests', __name__, url_prefix='/requests', template_folder='templates')

@requests_bp.route('/')
def index():
    return render_template('requests/index.html')

# Заглушки для будущих функций
@requests_bp.route('/create')
def create_request():
    return 'Форма создания заявки (скоро)'

@requests_bp.route('/list')
def requests_list():
    return 'Список заявок (скоро)'