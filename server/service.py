from pyquery import PyQuery as pq
import urllib3, re, db, requests
from datetime import datetime

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
allCoursesUrl = 'https://usionline.uni-graz.at/usiweb/myusi.kurse?suche_in=go&sem_id_in=2019W'
dbc = db.DatabaseConnection()

d = pq(url=allCoursesUrl, verify=False)
rowsIter = d("table#kursangebot").find('tr').items()

i = 1
rows = list(rowsIter)
courses = []
now = datetime.now().timestamp()

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
        'link': 'usionline.uni-graz.at/usiweb/' + link.attrib['href'],
        'time': row.find('td.zeit').text(),
        'places': {
            'free': freeInt,  # todo regex
            # 'total': int(row.find(''))
        },
        'updated': now,
    }
    print('Inserting ' + course['name'])
    dbc.update('courses', [{"id": course['id']}, {'$set': course}, True])

    # courses.append(course)
    i += 3
    # print(row.find('a').eq(0).text())

# logfile = open("log/service.log", "a")
# logfile.write('{0} - service.py - [INFO] scraped successfully\n'.format(
#     datetime.now().isoformat()))
