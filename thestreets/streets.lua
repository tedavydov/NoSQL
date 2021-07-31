local log = require('log')
local fio = require('fio')
local uuid = require('uuid')
local json = require('json')

--[[
    ����� �������� ����� ��������
]]
local function streets(request)
    return { body=fio.open('templates/index.html'):read() }
end

--[[
    ������ ����� ����� � ��������� � �������
]]
local function newplace(request)
    local place = {}
    -- json �� ���������
    local obj = request:json()

    --[[ ���������� ���������� ������������� ��� ������]]
    place['_id'] = uuid.str()
    --[[ ������ ��������� ������� ������� ]]
    place['type'] = obj['type']
    place['geometry.type'] = obj['geometry']['type']
    place['geometry.coordinates'] = obj['geometry']['coordinates']
    place['properties.comment'] = obj['properties']['comment']
    place['properties.rate'] = obj['properties']['rate']

    --[[
        ������ �������� ��� �������
    ]]
    local t, err = box.space.streets:frommap(place)
    if err ~= nil then
        log.error(tostring(err))
        return {code=503, body=tostring(err)}
    end
    --[[
        ��������� ������
    ]]
    box.space.streets:insert(t)

    return { body=json.encode(obj) }
end

--[[
    ������� ��� ���������� ����������
    ����������� ���� ����
]]
local function distance(x, y, x2, y2)
    return math.sqrt(math.pow(x2-x, 2) + math.pow(y2-y, 2))
end

--[[
    ������� ���������� ������� �� �����
    ��������� � ��������� �����
]]
local function places(request)
    local result = {}

    local limit = 1000
    local x = tonumber(request:param('x'))
    local y = tonumber(request:param('y'))
    local dist = tonumber(request:param('distance'))

    x = x or 1
    y = y or 1
    dist = dist or 0.2

    --[[
        ����������� �� ������� ������� � ��������� � ��������� ����� ��������
    ]]
    for _, place in box.space.streets.index.spatial:pairs({x, y}, {iterator='NEIGHBOR'}) do
        -- ���� ������ ��� ����� ������, ��������� ��������
        if distance(x, y, place['geometry.coordinates'][1], place['geometry.coordinates'][2]) > dist then
            break
        end

        -- ������ ������� ( ��� �������� � ��������� ���� - ��������� ���������� �������� ) 
        local rates = tonumber(place['properties.rate'])
        -- ���� ������� �� �������� �� ������� �������� 1 �� ��������� 
        rates = rates or 1

        -- ������ GeoJSON
        local obj = {
            ['_id'] = place['_id'],
            type = place['type'],
            geometry = {
                type = place['geometry.type'],
                coordinates = place['geometry.coordinates'],
            },
            properties = {
                comment = place['properties.comment'],
                rate = place['properties.rate'],
            },
        }
        -- ���� ������� ������ 3 �� ���������� ������ ��� ������ �� ����� 
        if rates > 3 then
            table.insert(result, obj)
            limit = limit - 1
            if limit == 0 then
                break
            end
        end
    end
    return {code=200,
            body=json.encode(result)}
end

--[[
    �������������
]]

box.cfg{}

--[[
    ������ ������� ��� �������� ������� �� �����
]]
box.schema.space.create('streets', {if_not_exists=true})
box.space.streets:format({
        {name="_id", type="string"},
        {name="type", type="string"},
        {name="geometry.type", type="string"},
        {name="geometry.coordinates", type="array"},
        {name="properties.comment", type="string"},
        {name="properties.rate", type="integer"},
})
--[[ ������ ��������� ������ ]]
box.space.streets:create_index('primary', {
                                parts={{field="_id", type="string"}},
                                type = 'TREE',
                                if_not_exists=true,})
--[[ ������ ������ ��� ��������� ]]
box.space.streets:create_index('spatial', {
                                parts = {{ field="geometry.coordinates", type='array'} },
                                type = 'RTREE', unique = false,
                                if_not_exists=true,})

--[[ ����������� http ������ ]]
local httpd = require('http.server').new('0.0.0.0', 8081)
local router = require('http.router').new()
httpd:set_router(router)
router:route({path="/"}, streets)
router:route({path="/newplace"}, newplace)
router:route({path="/places"}, places)

httpd:start()
