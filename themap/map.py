# coding: utf-8

from flask import Flask, render_template, request
from bson import json_util
from random import randint

app = Flask(__name__)

from pymongo import MongoClient


##
## Подключение базе данных и доступ к таблице с индексом
##
client = MongoClient()


# Используем базу данных с именем themap
db = client.themap
places = db.places
places.create_index([('geometry', '2dsphere')])


##
## Отдаём фронтенд
##
@app.route('/')
def root():
    return render_template('index.html')


##
## Создаём новый комментарий к базе данных
##
@app.route('/newplace', methods=['POST'])
def newplace():
    content = request.get_json(silent=True, force=True)
    like_rand = randint(0, 5)
    properties = content.get("properties")
    like_in = properties.get("like")
    if like_in:
        like = int(like_in)
        if like > 5:
            like = 5
        elif like < 1:
            like = 1
    else:
        like = int(like_rand)
    properties["like"] = like
    content["properties"] = properties
    place_id = places.insert_one(content).inserted_id
    return json_util.dumps(content)


##
## Возвращаем комментарии, которые географически близки
## к запрашиваемой точке
##
@app.route('/places')
def getplaces():
    lat = request.args.get('lat')
    lng = request.args.get('lng')
    dist = request.args.get('distance')
    if dist is None:
        dist = 4000
    cursor = places.find({
    "geometry": {
        "$nearSphere": {
            "$geometry": {
                "type" : "Point",
                "coordinates" : [ float(lng), float(lat) ]
            },
            "$minDistance": 0,
            "$maxDistance": dist, } } })
    resultset = []
    for place in cursor:
        resultset.append(place)
    return json_util.dumps(resultset)
    
    