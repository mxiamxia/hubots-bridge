/**
 * Created by min on 4/12/16.
 */


var config = {
  MODE_ENV: 'DEV', //DEV
  ROCKET_URL: 'www.cyberobject.com:3000',
  CM_URL: 'http://192.168.254.196:18481/ntelagent-chat-web-mobile/HttpService',
  HUBOT_SKY: 'http://localhost:8092/skype/message',
  HUBOT_ROCKET: 'http://localhost:8093/rocket/message',
  redis_host: 'localhost',
  redis_port: 6379,
  redis_db: 0,
  pollInterval: 1000,

  debug: true
}

if (config.MODE_ENV === 'TEST') {
  config.CM_URL = 'http://192.168.254.116:3030/cm';
} else {
  config.CM_URL = 'http://192.168.254.196:18081/ntelagent-chat-web-mobile/HttpService';
}

module.exports = config
