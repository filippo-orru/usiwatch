import requests
# import certifi

# http = urllib3.PoolManager(cert_reqs='CERT_REQUIRED', ca_certs=certifi.where())

req = requests.get(
    'https://usionline.uni-graz.at/usiweb/myusi.kurse?suche_in=go&sem_id_in=2019W&kursnr_in=405'
)

if req.ok:

    if 'Keine Plätze mehr verfügbar' in req.text:
        print('sad stuff')
    else:
        print('go get it my boy')