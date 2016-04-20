# Description:
#   Example scripts for you to examine and try out.
#
# Notes:
#   They are commented out by default, because most of them are pretty silly and
#   wouldn't be useful and amusing enough for day to day huboting.
#   Uncomment the ones you want to try and experiment with.
#
#   These are from the scripting documentation: https://github.com/github/hubot/blob/master/docs/scripting.md

Q = require 'q'
config = require '../config'
cache = require '../common/cache'
logger = require '../common/logger'
EventProxy   = require 'eventproxy'
TEMP = require '../common/template'
request = require 'request'
poll = require '../common/poll'
io_socket = require 'socket.io'
cm = require '../core/conversation'


module.exports = (robot) ->

  io =  io_socket robot.server

  io.on 'connection', (socket) ->
    logger.debug('socket id=' + socket.id)

    socket.on 'new message', (data) ->
      logger.debug('received data=' + JSON.stringify(data))
      id = data.userid
      text = data.input
      self = false
      cm.processMessage id, text, robot, socket, self, null

  robot.respond /(.*)/i, (msg) ->
    text = msg.match[1]
    id = msg.envelope.user?.id
    room = msg.envelope.room
#    logger.debug 'received msg=' + JSON.stringify(msg.envelope)
    logger.debug 'room of message = ' + room
    self = true
    cm.processMessage id, text, robot, null, self, room

  robot.error (err, res) ->
    robot.logger.error "DOES NOT COMPUTE"
    if res?
      res.reply "DOES NOT COMPUTE"

#loginAction= () ->
#  deferred = Q.defer()
#  logger.debug('login input=' + JSON.stringify(TEMP.cmLogin))
#  logger.debug('login url=' + config.CM_URL)
#  options = {
#    uri: config.CM_URL,
#    method: 'POST',
#    json: TEMP.cmLogin
#  }
#  request options, (err, response, body) ->
#    if(err)
#      logger.debug('login request err=' + err)
#      deferred.resolve 'Login fail'
#    logger.debug('login body=' + JSON.stringify(body))
#    if body.status.code is not '0000'
#      deferred.resolve('Login fail')
#      return deferred.promise
#    deferred.resolve body
#  deferred.promise
#
#conversationAction= (value, sentence) ->
#  deferred = Q.defer()
#  input = TEMP.cmConversation
#
#  input.header.sessionId = value.sessionId
#  input.body.msg = sentence
#  input.body.username = value.username
#  input.body.robotjid = value.robotjid
#  if value.questionid?
#    input.body.questionid = value.questionid
#  logger.debug('conversation input===' + JSON.stringify(input))
#  options = {
#    uri: config.CM_URL,
#    method: 'POST',
#    json: input
#  }
#  request options, (err, response, body) ->
#    if(err)
#      logger.debug('conversation request err=' + err)
#    logger.debug('conversation body=' + JSON.stringify(body))
#    deferred.resolve('successful')
#  deferred.promise
#
#updateRobotId= (id, value) ->
#  deferred = Q.defer()
#  logger.debug('update Robotid input=' + JSON.stringify(value))
#  if value is 'Login fail'
#    deferred.resolve 'login fail'
#  else
#    input = TEMP.cmListener
#    input.header.sessionId = value.body.result.sessionId
#    input.body.username = value.body.result.username
#    options = {
#      uri: config.CM_URL,
#      method: 'POST',
#      json: input
#    }
#    logger.debug('listener robotjid input' + JSON.stringify(input))
#    request options, (err, response, body) ->
#      if(err)
#        logger.debug('update robotid request err=' + err)
#      logger.debug('listener body=' + JSON.stringify(body))
#      input.body.robotjid = body.body.result.robotjid
#      value = {
#        'sessionId': input.header.sessionId,
#        'username': input.body.username,
#        'robotjid': body.body.result.robotjid,
#        'polling': false,
#        'listenerInput': input
#      }
#      cache.set(id, value)
#      deferred.resolve input
#  deferred.promise
#
#parsePollingResult = (id, robot, data, cache_v, socket, room) ->
#  msg = data.body.result.msg
#  if msg
#    message = data.body.result.msg[0].info.xur.response.message
#    if message
#      dialog = message['@value']
#      questionid = message['@questionid']
#      regex = /<br\s*[\/]?>/gi
#      dialog = dialog.replace(regex, "\n")
#      logger.debug('retrieved dialog=' + dialog);
#      cache_v.questionid = questionid;
#      cache.set(id, cache_v);
#      if dialog.indexOf('Sorry your session has timed out') > -1
#        cache.remove(id)
#      if socket?
#        resp = {
#          'userid': id,
#          'input': dialog,
#          'source': 'mattermost'
#        }
#        socket.emit 'response', resp
#        robot.messageRoom(room, dialog);
#      else
#        robot.messageRoom room, dialog
#  else
#    logger.debug 'no message retreived from queue'
#
#
#processMessage = (id, text, robot, socket, self, room) ->
#  ep = new EventProxy();
#  if not room
#    room = 'GENERAL'
#
#  ep.fail (err)->
#    logger.error 'Failed to retreive data from Redis server', err
#
#  cache.get id, (err, value) ->
#    ep.emit 'sessionFound', value
#
#  ep.all 'sessionFound', (value) ->
#    logger.debug('cached session value=' + JSON.stringify(value))
#
#    if text is 'quit'
#      if value?
#        if value.polling
#          poll.stopPoller
#          logger.debug 'polling value ===========' + value.polling
#        cache.remove(id)
#      if self
#        robot.messageRoom room, 'Session is terminated'
#      else
#        resp = {
#          'userid': id,
#          'input': 'Session is terminated',
#          'source': 'mattermost'
#        }
#        socket.emit 'response', resp
#    else if value?
#      conversationAction(value, text)
#      .then((result) ->
#        logger.debug('conversation result=' + result)
#        if not self
#          question = '@' + id + ': ' + text + '\n'
#          robot.messageRoom room, question
#      )
#    else
#      loginAction(id, robot)
#      .then((result) ->
#        return updateRobotId(id, result)
#      ).then(() ->
#        cache.get id, (err, value) ->
#          logger.debug(id + ' start polling the messages' + JSON.stringify(value))
#          if not value.polling
#            poll.pollAll(id, robot, socket, room, config.pollInterval, parsePollingResult);
#        question = '@' + id + ': ' + text + '\n'
#        if not self
#          robot.messageRoom room, question
#      )
#
#
#
#
#
#
#

