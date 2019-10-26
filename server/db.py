from pymongo import MongoClient, ASCENDING, DESCENDING, errors as pmgerrs
import configparser


class DatabaseConnection():
    _client = None
    _db = None

    def __init__(self, path: str = 'config.ini'):
        # if path.find('/') == -1:
        # path = './' + path

        print('DEBUG: Creating new connection to database')

        config = configparser.ConfigParser()
        config.read(path)

        if not config or config.sections() == []:
            raise FileNotFoundError('Could not find ' + path)
        # print(config.sections())

        url = config['Mongodb']['url']
        database = config['Mongodb']['database']

        self._client = MongoClient(url)
        self._db = self._client.get_database(database)

    def fromParams(self, address, database):
        print('DEBUG: Creating new connection to database')
        self._client = MongoClient(address)
        self._db = self._client.get_database(database)

    def __del__(self):
        print('DEBUG: Trying to close connection to db')
        try:
            if self._client:
                self._client.close()
            if self._db:
                self._db = None
            print('SUCCESS: Closed connection to db')
        except TypeError:
            print('ERROR: Failed to close connection to db')
            pass

    def get_client(self, collection):
        '''
        returns the client for the given collection
        '''
        return self._db[collection]

    def insert_one(self, collection, mdbInput):
        '''
        input: ( collection, { entry })
        '''
        return self._db[collection].insert_one(mdbInput)

    def insert_many(self, collection, mdbInput):
        return self._db[collection].insert_many(mdbInput)

    def find(self,
             collection,
             query,
             limit=1,
             offset=0,
             sort=None,
             projection=None,
             keepId=False):
        '''
        Example: find('users', {"age": {"$gt": 5}}, 5, 1)
        Will find 5 users with age > 5, skipping the first one
        '''
        if sort:
            sortField = sort[0]
            sortDir = ASCENDING if sort[1] == 1 else DESCENDING
            result = self._db[collection].find(
                query,
                projection).skip(offset).limit(limit).sort(sortField, sortDir)
        else:
            result = self._db[collection].find(
                query, projection).skip(offset).limit(limit)

        # if '_id' in result:
        #     result
        return result

    def update(self, collection, query):
        '''
        Example: update('users', [
            {"age": 18},
            {"$set": {"candrink": "true"}},
            upsert=True])
        '''
        return self._db[collection].update(*query)

    def update_many(self, collection, query):
        return self._db[collection].update_many(*query)

    def delete(self, collection, query):
        '''
        Example: delete('users', {"age": {"$lt": 18}})
        '''
        return self._db[collection].delete_one(query)

    def delete_many(self, collection, query):
        return self._db[collection].delete_many(query)

    def drop(self, collection):
        return self._db[collection].drop()

    def aggregate(self, collection, pipeline):
        return self._db[collection].aggregate(pipeline)