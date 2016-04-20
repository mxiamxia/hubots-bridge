# Description:
#   Example scripts for you to examine and try out.
#
# Notes:
#   They are commented out by default, because most of them are pretty silly and
#   wouldn't be useful and amusing enough for day to day huboting.
#   Uncomment the ones you want to try and experiment with.
#
#   These are from the scripting documentation: https://github.com/github/hubot/blob/master/docs/scripting.md

config = require '../config'
logger = require '../common/logger'
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
