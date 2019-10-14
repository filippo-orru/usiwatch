from flask import Flask, jsonify, request, make_response
import db, helpers as hlp

app = Flask(__name__)

api = "/api/"

dbc = db.DatabaseConnection()

# return render_template('index.html')

# @app.route(api + 'watch', methods=['POST'])
# def watch():
#     return ""


@app.route(api + 'examples', methods=['GET'])
def examples():

    results = list(
        dbc.aggregate('courses', [{
            "$match": {
                "places.free": 0
            }
        }, {
            "$sample": {
                "size": 10
            }
        }]))
    # results = list(dbc.find('courses', {"places.free": {"$eq": 0}}, 5))
    results = hlp.clearOID(results)

    return jsonify(results)


@app.route(api + 'search/<query>', methods=['GET'])
def search(query):
    re = r'.*' + query + r'.*'

    results = list(
        dbc.find(
            'courses',
            {"name": {
                "$regex": re,
                "$options": "i"
            }},
            limit=25,
        ))
    for result in results:
        result.pop('_id')

    return jsonify(results)


@app.route(api + 'watching', methods=['GET', 'DELETE'])
def watching():
    try:
        email = request.get_json(silent=True)['email']

        if len(email) > 0:
            pass

        else:
            raise ValueError

    except (TypeError, KeyError, ValueError):
        return make_response(jsonify({"message": "email invalid"}), 400)

    if request.method == 'GET':
        watchingl = list(dbc.find('watching', {'email': email}))

        return jsonify(watchingl)

    else:
        dbc.delete_many('watching', {'email': email})
        return jsonify({'message': 'Deleted all entries for ' + email})


@app.route(api + 'watch', methods=['POST', 'DELETE'])
def watch():
    try:
        email = request.get_json(silent=True)['email']
        id_ = request.get_json(silent=True)['id']

        if len(id_) > 0 and len(email) > 0:
            pass

        else:
            raise ValueError

        int(id_)
    except (TypeError, KeyError, ValueError):
        return make_response(jsonify({"message": "email or id invalid"}), 400)

    if request.method == 'POST':
        if len(list(dbc.find('watching', {'email': email, 'id': id_}))) > 0:
            return make_response(jsonify({'message': 'already exists'}), 409)

        dbc.insert_one('watching', {'email': email, 'id': id_})

        return jsonify({'message': 'Inserted ' + id_ + ' for ' + email})

    elif request.method == 'DELETE':
        existing = list(dbc.find('watching', {'email': email, 'id': id_}))

        if len(existing) > 0:
            dbc.delete('watching', {'email': email, 'id': id_})

            return jsonify({'message': 'Deleted ' + id_ + ' for ' + email})
        else:
            return jsonify(
                {'message': 'Could not find ' + id_ + ' for ' + email}, 404)

    return


if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5001, debug=True)
