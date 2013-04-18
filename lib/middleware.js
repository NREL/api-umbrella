var bufferedRequest = require('./middleware/buffered_request');

module.exports.forwardedIp = require('./middleware/forwarded_ip');
module.exports.apiKeyValidator = require('./middleware/api_key_validator');
module.exports.roleValdiator = require('./middleware/role_validator');
module.exports.rateLimit = require('./middleware/rate_limit');
module.exports.bufferRequest = bufferedRequest.bufferRequest;
module.exports.proxyBufferedRequest = bufferedRequest.proxyBufferedRequest;
