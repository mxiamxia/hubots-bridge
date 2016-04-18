var config = require('../config');

var env = process.env.NODE_ENV || "development"


var log4js = require('log4js');
log4js.configure({
  appenders: [
    { type: 'console' },
    { type: 'file', filename: 'logs/co_hubot.log', category: 'rocket' }
  ]
});

var logger = log4js.getLogger('rocket');
logger.setLevel(config.debug && env !== 'test' ? 'DEBUG' : 'ERROR')

module.exports = logger;
