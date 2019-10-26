from flask import Flask, jsonify as j, request, make_response as mr
from secrets import token_urlsafe
from configparser import ConfigParser
import db, helpers as hlp, requests

app = Flask(__name__)

api = "/api/"

dbc = db.DatabaseConnection()

# return render_template('index.html')

# @app.route(api + 'watch', methods=['POST'])
# def watch():
#     return ""


@app.route(api + 'login', methods=['POST'])
def login():
    json = request.get_json()

    try:
        email = json['email']
    except:
        return mr(j({'message': 'Missing json'}), 400)

    try:
        watcher = list(dbc.find('watchers', {'email': email}))[0]
    except:
        watcher = {'email': email, 'verified': False, 'courses': []}

    if 'verifyKey' in watcher:
        watcher.pop('verifyKey')

    watcher = hlp.clearOID(watcher)

    return j(watcher)


@app.route(api + 'verify/<key>', methods=['GET'])
def verify(key):
    try:
        watcher = list(dbc.find('watchers', {'verifyKey': key}))[0]
    except:
        return mr("Du bist bereits bestätigt oder der Link ist abgelaufen.",
                  400)


#Melde dich erneut an, dann erhälst du einen neuen.\n
# Solltest du keinen erhalten kannst du versuchen, deine Watchlist zu leeren.",

    watcher.pop('verifyKey')
    watcher['verified'] = True

    dbc.update('watchers', [{'verifyKey': key}, watcher])
    return ("Dein Account wurde bestätigt! Du wirst benachrichtigt.")


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

    return j(results)


@app.route(api + 'search/<query>', methods=['GET', 'POST'])
def search(query):

    re = r'.*' + query + r'.*'

    courses = list(
        dbc.find(
            'courses',
            {
                "$or": [{
                    "name": {
                        "$regex": re,
                        "$options": "i"
                    }
                }, {
                    "id": query
                }]
            },
            limit=25,
        ))

    for course in courses:
        course.pop('_id')

    json_ = request.get_json(silent=True)

    if request.method == 'POST' and json_ != None:
        if 'email' in json_:
            email = json_['email']
            maybeuser = list(dbc.find('watchers', {"email": email}))

            if len(maybeuser) > 0:
                user = maybeuser[0]
                for ucourseid in user['courses']:
                    for course in courses:
                        if ucourseid == course['id']:
                            course['watching'] = True

    return j(courses)


@app.route(api + 'watching', methods=['GET', 'DELETE'])
def watching():
    try:
        email = request.get_json(silent=True)['email']

        if len(email) > 0:
            pass

        else:
            raise ValueError

    except (TypeError, KeyError, ValueError):
        return mr(j({"message": "email invalid"}), 400)

    if request.method == 'GET':
        watchingl = list(dbc.find('watching', {'email': email}))

        return j(watchingl)

    else:
        dbc.delete('watchers', {'email': email})
        return j({'message': 'Deleted all entries for ' + email})


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
        return mr(j({"message": "email or id invalid"}), 400)

    if request.method == 'POST':
        maybewatcher = list(dbc.find('watchers', {'email': email}))

        if len(maybewatcher) > 0:
            watcher = maybewatcher[0]

            if not id_ in watcher['courses']:
                # return mr(j({'message': 'already exists'}), 409)
                # else:
                watcher['courses'].append(id_)

        else:
            newVerifyKey = token_urlsafe(32)
            print('new key for new user :) : ' + newVerifyKey)
            watcher = {
                'email': email,
                'courses': [id_],
                'verified': False,
                'verifyKey': newVerifyKey
            }

            try:
                sendConfirmationEmailToNewUser(watcher)
            except:
                mr(j({"message": "couldnt send new email"}), 500)

        dbc.get_client('watchers').update_one({'email': email},
                                              {'$set': watcher},
                                              upsert=True)

        return j({'message': 'Inserted ' + id_ + ' for ' + email})

    elif request.method == 'DELETE':
        maybewatcher = list(
            dbc.find('watchers', {
                'email': email,
                'courses': id_
            }))

        if len(maybewatcher) == 0:
            return mr(
                j({'message': 'Could not find ' + id_ + ' for ' + email}), 404)

        watcher = maybewatcher[0]
        courses = watcher['courses']

        courses.pop(courses.index(id_))

        # if len(courses) == 0:
        #     dbc.delete('watchers', {'email': email})

        # else:
        watcher['courses'] = courses

        dbc.update('watchers', [{"email": email}, watcher])

        return j({'message': 'Deleted ' + id_ + ' for ' + email})

    return


def sendConfirmationEmailToNewUser(watcher):
    config = ConfigParser()
    config.read('config.ini')
    if config.sections() == []:
        raise FileNotFoundError('missing config.ini')

    verifyLink = 'https://usiwatch.xyz/api/verify/' + watcher['verifyKey']

    requests.post(config['Mail']['url'],
                  data={
                      "from":
                      config['Mail']['address'],
                      "to":
                      watcher['email'],
                      "subject":
                      "USI Watch Account bestätigen",
                      "html":
                      "<html><h3>Hallöchen!</h3>\
<p>Um deine Anmeldung auf Usiwatch für den Kurs {} zu bestätigen \
musst du hier auf den Link klicken!</p><p>Sonst wirst du nicht benachrichtigt.</p>\
<a href=\"{}\">Anmeldung bestätigen</a></html>".format(watcher['courses'][0],
                                                       verifyLink),
                      "text":
                      "Usiwatch Accountbestätigungslink: " + verifyLink
                  })


if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5001, debug=True)