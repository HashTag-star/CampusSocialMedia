const NodeCache = require('node-cache');

// Standard TTL: 60 seconds, Check period: 120 seconds
const cache = new NodeCache({ stdTTL: 60, checkperiod: 120 });

module.exports = {
    get: (key) => cache.get(key),
    set: (key, value, ttl = 60) => cache.set(key, value, ttl),
    del: (key) => cache.del(key),
    flush: () => cache.flushAll(),
    keys: () => cache.keys()
};
