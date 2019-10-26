def clearOID(res):
    if type(res) == dict:
        if '_id' in res:
            res.pop('_id')

    elif type(res) == list:
        res = list(map(clearOID, res))

    return res