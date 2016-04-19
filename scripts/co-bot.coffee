# Description:
#   Example scripts for you to examine and try out.
#
# Notes:
#   They are commented out by default, because most of them are pretty silly and
#   wouldn't be useful and amusing enough for day to day huboting.
#   Uncomment the ones you want to try and experiment with.
#
#   These are from the scripting documentation: https://github.com/github/hubot/blob/master/docs/scripting.md

xml2js = require 'xml2js'
util = require 'util'
url = require 'url'
Q = require 'q'
querystring = require 'querystring'
config = require '../config'
cache = require '../common/cache'
logger = require '../common/logger'
EventProxy   = require 'eventproxy'
TEMP = require '../common/template'
request = require 'request'
poll = require '../common/poll'
io_socket = require 'socket.io'

module.exports = (robot) ->

  io =  io_socket robot.server

  io.on 'connection', (socket) ->
    logger.debug('socket id=' + socket.id)

    socket.on 'new message', (data) ->
      logger.debug('received data=' + JSON.stringify(data))
      id = data.userid
      text = data.input
      processMessage id, text, robot, socket

  robot.respond /(.*)/i, (msg) ->
    text = msg.match[1]
    userid = msg.envelope.user?.id
    logger.debug 'userid=' + userid
    msg.http(config.HUBOT_SKY)
    .headers('Content-Type': 'application/json')
    .query({'userid': userid, 'input': text})
    .post() (err, res, body) ->
      if err
        res.send 'Skype service is not available'
      logger.debug('returned result=' + body)
      msg.send body

  robot.error (err, res) ->
    robot.logger.error "DOES NOT COMPUTE"
    if res?
      res.reply "DOES NOT COMPUTE"

loginAction= () ->
  deferred = Q.defer()
  logger.debug('login input=' + JSON.stringify(TEMP.cmLogin))
  logger.debug('login url=' + config.CM_URL)
  options = {
    uri: config.CM_URL,
    method: 'POST',
    json: TEMP.cmLogin
  }
  request options, (err, response, body) ->
    if(err)
      logger.debug('login request err=' + err)
      deferred.resolve 'Login fail'
    logger.debug('login body=' + JSON.stringify(body))
    if body.status.code is not '0000'
      deferred.resolve('Login fail')
      return deferred.promise
    deferred.resolve body
  deferred.promise

conversationAction= (value, sentence) ->
  deferred = Q.defer()
  input = TEMP.cmConversation

  input.header.sessionId = value.sessionId
  input.body.msg = sentence
  input.body.username = value.username
  input.body.robotjid = value.robotjid
  if value.questionid?
    input.body.questionid = value.questionid
  logger.debug('conversation input===' + JSON.stringify(input))
  options = {
    uri: config.CM_URL,
    method: 'POST',
    json: input
  }
  request options, (err, response, body) ->
    if(err)
      logger.debug('conversation request err=' + err)
    logger.debug('conversation body=' + JSON.stringify(body))
    deferred.resolve('successful')
  deferred.promise

updateRobotId= (id, value) ->
  deferred = Q.defer()
  logger.debug('update Robotid input=' + JSON.stringify(value))
  if value is 'Login fail'
    deferred.resolve 'login fail'
  else
    input = TEMP.cmListener
    input.header.sessionId = value.body.result.sessionId
    input.body.username = value.body.result.username
    options = {
      uri: config.CM_URL,
      method: 'POST',
      json: input
    }
    logger.debug('listener robotjid input' + JSON.stringify(input))
    request options, (err, response, body) ->
      if(err)
        logger.debug('update robotid request err=' + err)
      logger.debug('listener body=' + JSON.stringify(body))
      input.body.robotjid = body.body.result.robotjid
      value = {
        'sessionId': input.header.sessionId,
        'username': input.body.username,
        'robotjid': body.body.result.robotjid,
        'polling': false,
        'listenerInput': input
      }
      cache.set(id, value)
      deferred.resolve input
  deferred.promise

parsePollingResult = (id, robot, data, cache_v, socket) ->
  msg = data.body.result.msg
  if msg
    message = data.body.result.msg[0].info.xur.response.message
    if message
      dialog = message['@value']
      questionid = message['@questionid']
      regex = /<br\s*[\/]?>/gi
      dialog = dialog.replace(regex, "\n")
      logger.debug('retrieved dialog=' + dialog);
      cache_v.questionid = questionid;
      cache.set(id, cache_v);
      robot.messageRoom('GENERAL', dialog);
      socket.emit 'response', dialog
  else
    logger.debug 'no message retreived from queue'


processMessage = (id, text, robot, socket) ->
  ep = new EventProxy();
  room = 'GENERAL'

  ep.fail (err)->
    logger.error 'Failed to retreive data from Redis server', err

  cache.get id, (err, value) ->
    ep.emit 'sessionFound', value

  ep.all 'sessionFound', (value) ->
    logger.debug('cached session value=' + JSON.stringify(value))

    if text is 'quit'
      if value?
        cache.remove(id)
        if value.polling
          poll.stopPoller
      socket.emit 'response', 'Your session is ended'
    else if value?
      conversationAction(value, text)
      .then((result) ->
        logger.debug('conversation result=' + result)
        question = id + ': ' + text + '\n'
        robot.messageRoom room, question
      )
    else
      loginAction(id, robot)
      .then((result) ->
        return updateRobotId(id, result)
      ).then(() ->
        cache.get id, (err, value) ->
          logger.debug(id + ' start polling the messages' + JSON.stringify(value))
          if not value.polling
            logger.debug 'start polling'
            poll.pollAll(id, robot, socket, config.pollInterval, parsePollingResult);
        question = id + ': ' + text + '\n'
        robot.messageRoom room, question
      )








