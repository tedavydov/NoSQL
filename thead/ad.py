import redis
from redis.sentinel import Sentinel
from flask import Flask, session, request, make_response
from time import strftime
import uuid

app = Flask(__name__)
app.secret_key = 'super secret key'
app.config['SESSION_TYPE'] = 'filesystem'

sentinel = Sentinel([('localhost', 16379)], socket_timeout=0.1)
master = sentinel.master_for('THEAD_CLUSTER', socket_timeout=0.1)

@app.route('/')
def theanswer():
    day = strftime("%Y-%m-%d")
    # чтение данных сессии
    get_id = session.get('user_id')
    total_visits = session.get('visits')
    if not get_id:  # новый польователь и сессия
        get_id = str(uuid.uuid4())
    idx_key = 'page:index:counter:' + get_id + ':' + day
    master.incr(idx_key)
    # обновление данных сессии
    visits = master.get(idx_key)
    session['visits'] = visits
    session['user_id'] = get_id
    return f'user({get_id}) <br> index({idx_key}) <br><br> counter = {visits}'
