def clearOID(res):
    if type(res) == dict:
        res.pop('_id')
    elif type(res) == list:
        for r in res:
            r.pop('_id')
    else:
        raise TypeError('nooo why bad type??')
    return res