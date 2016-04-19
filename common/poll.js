var request = require('request');
var config = require('../config');
var cache = require('./cache');
var logger = require('./logger');
var template = require('./template');
var EventProxy   = require('eventproxy');
var pollerId = null;

var pollAll = function(id, robot, socket, interval, callback) {
  var ep = new EventProxy();
  cache.get(id, function(err, value) {
    ep.emit('ready', value);
  });

  ep.all('ready', function(value) {
    logger.debug('pollAll cached value=' + JSON.stringify(value));
    pollerId = setInterval(function(){pollerFunc(robot, id, value, socket, callback)}, interval);
    value.polling = true;
    cache.set(id, value);
  });

}

var pollerFunc = function(robot, id, value, socket, callback) {
  var options = {
    uri: config.CM_URL,
    method: 'POST',
    json: value.listenerInput
  };
  logger.debug('listener input=' + JSON.stringify(value.listenerInput));
  request(options, function(err, response, body) {
    if (!err && response.statusCode === 200) {
      logger.debug('listener output=' + JSON.stringify(body));
      callback(id, robot, body, value, socket);
    } else {
      logger.debug('listener request failed');
    }
  });
}

//var parsePollResult = function(robot, res, response, id, value) {
//  var msg = response.body.result.msg;
//  if (typeof msg !== "undefined" && msg !== null) {
//    var message = response.body.result.msg[0].info.xur.response.message
//    if(typeof message !== "undefined" && message !== null) {
//      var dialog = message['@value'];
//      var questionid = message['@questionid'];
//      var regex = /<br\s*[\/]?>/gi;
//      dialog = dialog.replace(regex, "\n")
//      logger.debug('retrieved dialog=' + dialog);
//      value.questionid = questionid;
//      cache.set(id, value);
//      robot.messageRoom('GENERAL', dialog);
//      res.send(dialog);
//    }
//  }
//}

var stopPoller = function() {
  clearInterval(pollerId);
}

exports.pollAll = pollAll;
exports.stopPoller = stopPoller;
