var Q = require('q');
var config = require('../config');
var cache = require('../common/cache');
var logger = require('../common/logger');
var EventProxy = require('eventproxy');
var TEMP = require('../common/template');
var request = require('request');
var poll = require('../common/poll')

var loginAction = function () {
  var deferred = Q.defer()
  logger.debug('login input=' + JSON.stringify(TEMP.cmLogin))
  logger.debug('login url=' + config.CM_URL)
  var options = {
    uri: config.CM_URL,
    method: 'POST',
    json: TEMP.cmLogin
  };
  request(options, function (err, response, body) {
    if (err) {
      logger.debug('login request err=' + err)
      deferred.resolve('Login fail');
    } else {
      logger.debug('login body=' + JSON.stringify(body))
      if (body.status.code !== '0000') {
        deferred.resolve('Login fail')
        return deferred.promise;
      }
    }
    deferred.resolve(body);
  });
  return deferred.promise;
};


var conversationAction = function (value, sentence) {
  var deferred = Q.defer();
  var input = TEMP.cmConversation;

  input.header.sessionId = value.sessionId;
  input.body.msg = sentence;
  input.body.username = value.username;
  input.body.robotjid = value.robotjid;
  if (typeof value.questionid !== "undefined" && value.questionid !== null) {
    input.body.questionid = value.questionid;
  }
  logger.debug('conversation input===' + JSON.stringify(input));
  var options = {
    uri: config.CM_URL,
    method: 'POST',
    json: input
  };
  request(options, function (err, response, body) {
    if (err) {
      logger.debug('conversation request err=' + err);
    }
    logger.debug('conversation body=' + JSON.stringify(body));
    deferred.resolve('successful');
  });
  return deferred.promise;
};


var updateRobotId = function (id, value) {
  var deferred = Q.defer();
  logger.debug('update Robotid input=' + JSON.stringify(value))
  if (value == 'Login fail') {
    deferred.resolve('login fail')
  } else {
    var input = TEMP.cmListener;
    input.header.sessionId = value.body.result.sessionId;
    input.body.username = value.body.result.username;
    var options = {
      uri: config.CM_URL,
      method: 'POST',
      json: input
    };
    logger.debug('listener robotjid input' + JSON.stringify(input));
    request(options, function (err, response, body) {
      if (err) {
        logger.debug('update robotid request err=' + err)
      }
      logger.debug('listener body=' + JSON.stringify(body));
      input.body.robotjid = body.body.result.robotjid;
      var value = {
        'sessionId': input.header.sessionId,
        'username': input.body.username,
        'robotjid': body.body.result.robotjid,
        'polling': false,
        'listenerInput': input
      };
      cache.set(id, value);
      deferred.resolve(input);
    });
  }
  return deferred.promise;
};

var parsePollingResult = function (id, robot, data, cache_v, socket, room) {
  var msg = data.body.result.msg
  if (typeof msg !== 'undefined' && msg !== null) {
    var message = msg[0].info.xur.response.message;
    if (typeof message !== 'undefined' && message !== null) {
      var dialog = message['@value']
      var questionid = message['@questionid']
      var regex = /<br\s*[\/]?>/gi
      dialog = dialog.replace(regex, "\n")
      logger.debug('retrieved dialog=' + dialog);
      cache_v.questionid = questionid;
      cache.set(id, cache_v);
      if (dialog.indexOf('Sorry your session has timed out') > -1) {
        cache.remove(id);
        poll.stopPoller(id);
      }

      if (typeof socket !== 'undefined' && socket !== null) {
        socket.emit('response', {'userid':id, 'input':dialog});
        robot.messageRoom(room, dialog);
      } else {
        robot.messageRoom(room, dialog);
      }
    }
  }
  else {
    logger.debug('no message retreived from queue')
  }
};

var processMessage = function (id, text, robot, socket, self, room) {

  var ep = new EventProxy();
  if (typeof room == 'undefined' && room == null) {
    room = 'GENERAL'
  }

  ep.fail(function (err) {
    logger.error('Failed to retreive data from Redis server', err);
  });

  cache.get(id, function (err, value) {
    ep.emit('sessionFound', value);
  });

  ep.all('sessionFound', function (value) {
    logger.debug('cached session value=' + JSON.stringify(value));
    if (text === 'quit') {
      if (checkNotNull(value)) {
        if (value.polling) {
          logger.debug('stop polling============');
          poll.stopPoller(id);
        }
        cache.remove(id);
        if (self) {
          robot.messageRoom(room, 'Session is terminated');
        }
        else {
          socket.emit('response', {'userid':id, 'input':'Session is terminated'});
        }
      }
    }
    else if (checkNotNull(value)) {
      conversationAction(value, text)
        .then(function (result) {
          logger.debug('conversation result=' + result);
          if (!self) {
            var question = id + ': ' + text + '\n';
            robot.messageRoom(room, question);
          }
        });
    }
    else {
      loginAction(id, robot)
        .then(function (result) {
          return updateRobotId(id, result);
        }).
      then(function () {
        cache.get(id, function (err, value) {
          logger.debug(id + ' start polling the messages' + JSON.stringify(value));
          if (!value.polling) {
            poll.pollAll(id, robot, socket, room, config.pollInterval, parsePollingResult);
          }
          var question = id + ': ' + text + '\n';
          if (!self) {
            robot.messageRoom(room, question);
          }
        });
      });
    }
  });
}

var checkNotNull = function (obj) {
  if(typeof obj !== 'undefined' && obj !== null) {
    return true;
  } else {
    return false;
  }
}

exports.processMessage = processMessage;

//exports.callback = parsePollingResult;





