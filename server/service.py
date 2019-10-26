from pyquery import PyQuery as pq
import urllib3, re, db, requests, configparser
from datetime import datetime

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


def updateAllCourses():
    '''
    Serviceworker that gets all courses from the usi graz.
    Downloads page, parses it and saves it to mongodb (see config.ini)
    Works out which users should be notified and sends emails to them.
    '''

    allCoursesUrl = 'https://usionline.uni-graz.at/usiweb/myusi.kurse?suche_in=go&sem_id_in=2019W'
    dbc = db.DatabaseConnection()
    now = datetime.now().timestamp()

    d = pq(url=allCoursesUrl, verify=False)
    rows = list(d("table#kursangebot").find('tr').items())

    notificationCandidateCourses = []

    i = 1  # start with second row (first is header)
    while i < len(rows) - 1:
        row = rows[i]
        link = row.find('td.bez').eq(0).children()[0]
        freeText = rows[i + 2].find('td.warenkorbMsg').text()
        try:
            freeInt = int(re.search(r' (\d+) ', freeText).group(1))
        except:
            freeInt = 0

        id_ = row.find('td.nr ').text()
        if id_.find('\n') != -1:
            id_ = id_[:id_.find('\n')]

        course = {
            'id': id_,
            'name': link.text,
            'link':
            'https://usionline.uni-graz.at/usiweb/' + link.attrib['href'],
            'time': row.find('td.zeit').text(),
            'places': {
                'free': freeInt,  # todo regex
                # 'total': int(row.find(''))
            },
            'updated': now,
        }

        # dbc.update('courses', [{"id": course['id']}, {'$set': course}, True])
        # print('Inserted ' + course['name'])

        if course['places']['free'] > 0:
            # only courses that have free places should be checked later (minimal computation)
            notificationCandidateCourses.append(course)

        i += 3

    watchersNotify = []

    for watcher in list(dbc.find('watchers', {}, limit=100)):

        watcherCourses = watcher.pop(
            'courses')  # remove courses eg. ['202', '203']
        watcher['courses'] = []  # reinitialize to [] to expand courseinfo :

        for watcherCourse in watcherCourses:
            # full course info (maybe):
            maybecourse = list(
                filter(lambda c: c['id'] == watcherCourse,
                       notificationCandidateCourses))

            if len(maybecourse) == 0:  # no course with >0 places found
                continue  # go to next watcher course
            else:
                course = maybecourse[0]  # define as course (exists)

            # only iterating courses with >0 places -> always notify in this case
            watcher['courses'].append({
                'id': course['id'],
                'link': course['link'],
                'free': course['places']['free']
            })

        if len(watcher['courses']) > 0 and watcher['verified'] == True:
            # dont notify if no courses (lol) or if not verified
            watchersNotify.append(watcher)

    if not send_notifications(watchersNotify):
        raise Exception('There was an error notifying users.')

    # remove notified users from db
    watchersNotifyEmails = map(lambda w: w['email'], watchersNotify)
    dbc.delete_many('watchers', {'email': {'$in': watchersNotifyEmails}})


def sendmailsmtp(recipients: list, id: str):
    import smtplib

    sender = 'usiwatch@outlook.com'
    assert (type(recipients) == list)

    server = smtplib.SMTP(
        'smtp.office365.com',
        port=587,
        # timeout=10,
    )
    # server.connect('smtp-mail.outlook.com', port=587,)
    server.ehlo()
    server.starttls()
    server.login('usiwatch@outlook.com', ':SwitchhasABXY:')

    for recipient in recipients:
        receivers = [recipient]

        message = """From: Usiwatch <usiwatch@outlook.com>
    Sender: Usiwatch <usiwatch@outlook.com>
    Original-From: Usiwatch <usiwatch@outlook.com>
    Original-Sender: Usiwatch <usiwatch@outlook.com>
    Reply-To: usiwatch@outlook.com
    To: You{0}
    MIME-Version: 1.0
    Content-type: text/html
    Subject: SMTP HTML e-mail test

    This is a test e-mail message.<b>bold</b>
        """.format(recipient)

        # try:
        server.sendmail(sender, receivers, message)

        #     print("Successfully sent email")
        # except smtplib.SMTPException as e:
        #     print("Error: unable to send email")
        #     print(e)

    if server:
        server.quit()


def send_notifications(watchers: list):
    '''
    Takes a list of watchers:
        {   
            'email': email of watcher,
            'courses':
            [{
                'id': Courseid (str),
                'free': free places in course (int),
                'link': link to course
            }]
        }
    
    Sends a notification email to each of them.
    Returns true on success.
    '''
    if len(watchers) == 0:
        return True

    config = configparser.ConfigParser()
    if config.read('config.ini') == []:
        raise FileNotFoundError(
            'Missing config at config.ini. Maybe wrong cwd?')

    url = config['Mail']['url']

    for watcher in watchers:

        kursIds = str(list(
            map(lambda c: c['id'],
                watcher['courses'])))  # get list of [id1, id2, ...]
        kursIdsStr = kursIds[1:len(kursIds) - 1].replace(
            "'", "")  # remove [] from list

        kursKurse = 'einen der Kurse ' + kursIdsStr if len(
            watcher['courses']
        ) > 1 else 'den Kurs ' + watcher['courses'][0]['id']

        text = "<html><b>Hallo und aufgepasst!</b><p>Du hast auf usiwatch.xyz angegeben, \
dass du benachrichtigt werden willst, \
wenn {} frei wird.</p><ul>".format(kursKurse)

        for course in watcher['courses']:
            platzPlätze = 'einen Platz' if course['free'] == 0 else str(
                course['free']) + ' Plätze'

            text += "<li>Kurs {} hat jetzt {} frei. <a href=\"{}\">Link</a>\n</li>" \
                .format(course['id'], platzPlätze, course['link'])

        text += "</ul><p>Wenn du dich beeilst kriegst du vielleicht einen!</p>\n\
<i style=\"font-style:italic;\">Made with ♥ in Austria.</i>\n<hr/>\nTo unsubscribe, click <a href=\"%unsubscribe_url%\">here</a></html>"

        to = watcher['email']

        requests.post(url,
                      data={
                          "from": config['Mail']['address'],
                          "to": to,
                          "subject": "USI Watch Benachrichtigung",
                          "html": text,
                          "text":
                          "Usi Watch sagt: Kurse sind jetzt frei geworden!"
                      })

    return True


if __name__ == "__main__":
    updateAllCourses()
