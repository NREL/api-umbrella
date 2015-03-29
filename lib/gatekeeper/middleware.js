var bufferedRequest = require('./middleware/buffered_request');

module.exports.forwardedIp = require('./middleware/forwarded_ip');
module.exports.basicAuth = require('./middleware/basic_auth');
module.exports.apiKeyValidator = require('./middleware/api_key_validator');
module.exports.apiMatcher = require('./middleware/api_matcher');
module.exports.apiSettings = require('./middleware/api_settings');
module.exports.httpsRequirements = require('./middleware/https_requirements');
module.exports.roleValdiator = require('./middleware/role_validator');
module.exports.ipValidator = require('./middleware/ip_validator');
module.exports.refererValidator = require('./middleware/referer_validator');
module.exports.rateLimit = require('./middleware/rate_limit');
module.exports.bufferRequest = bufferedRequest.bufferRequest;
module.exports.proxyBufferedRequest = bufferedRequest.proxyBufferedRequest;
module.exports.rewriteRequest = require('./middleware/rewrite_request');
