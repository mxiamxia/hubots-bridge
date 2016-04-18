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

module.exports = (robot) ->

  robot.respond /(.*)/i, (msg) ->
    text = msg.match[1]
    userid = msg.envelope.user?.id
    console.log 'userid=' + userid
    msg.http(config.HUBOT_SKY)
    .headers('Content-Type': 'application/json')
    .query({'userid': userid, 'input': text})
    .post() (err, res, body) ->
      if err
        res.send 'Skype service is not available'
      console.log('returned result=' + body)
      msg.send body


  robot.router.post "/rocket/message", (req, res) ->
    query = querystring.parse(url.parse(req.url).query)
    text = query.input
    id = query.userid
    console.log('Received skype message=' + text)
    console.log('Received skype id=' + id)
    ep = new EventProxy();
    room = 'GENERAL'
    if text is 'login'
      loginAction(id, robot)
      .then((result) ->
        return updateRobotId(id, result)
      ).then((result1) ->
          console.log('init env====================' + result1)
          question = id + ': ' + text + '\n'
          robot.messageRoom room, question+result1
          res.send result1
        )
    else
      ep.fail (err)->
        logger.error 'Failed to retreive data from Redis server', err

      ep.all 'cache', (value) ->
        console.log('cached value=' + JSON.stringify(value))
        if value?
          conversationAction(value, text)
          .then((result) ->
            console.log('conversation result=' + result)
            question = id + ': ' + text + '\n'
            robot.messageRoom room, question+result
            res.send result
          )
        else
          loginAction(id, robot)
          .then((result) ->
            console.log('conversation result=' + result)
            cache.set(id, result)
            question = id + ': ' + text + '\n'
            response = 'Login sucessfully with sid ' + result
            robot.messageRoom room, question+response
            res.send response
          )
      cache.get id, (err, value) ->
        ep.emit 'cache', value

  robot.error (err, res) ->
    robot.logger.error "DOES NOT COMPUTE"

    if res?
      res.reply "DOES NOT COMPUTE"

  robot.router.get "/rocket/test", (req, res) ->
    query = querystring.parse(url.parse(req.url).query)
    room = query.room if query.room
    console.log('http listener rocket=' + room)

loginAction= () ->
  deferred = Q.defer()
  console.log('login input=' + JSON.stringify(TEMP.cmLogin))
  console.log('login url=' + config.CM_URL)
  options = {
    uri: config.CM_URL,
    method: 'POST',
    json: TEMP.cmLogin
  }
  request options, (err, response, body) ->
    if(err)
      console.log('login request err=' + err)
    console.log('login body=' + JSON.stringify(body))
    if body.status.code is not '0000'
      deferred.resolve('Login fail')
      return deferred.promise
    deferred.resolve body
  deferred.promise
#  robot.http(config.CM_URL)
#  .headers('Content-Type' : 'application/json')
#  .query(request: input)
#  .post() (err, res, body) ->
#    console.log('login msg===' + id)
#    console.log('login body===' + body)
#    result = JSON.parse(body)
#    if result.status.code is not '0000'
#        deferred.resolve('Login fail')
#        return deferred.promise
#    sessionId = result.body.result.sessionId?
#    console.log('sessionid=' + sessionId)
#    result['extras'] = {'id': id, 'robotjid': ''}
#    console.log 'login result' + JSON.stringify(result)
#    deferred.resolve(result)



conversationAction= (value, sentence) ->
  deferred = Q.defer()
  input = TEMP.cmConversation

  input.header.sessionId = value.body.result.sessionId
  input.body.msg = sentence
  input.body.username = value.body.result.username
  input.body.robotjid = value.robotjid
  if value.questionid?
    input.body.questionid = value.questionid
  console.log('conversation input===' + JSON.stringify(input))
  options = {
    uri: config.CM_URL,
    method: 'POST',
    json: input
  }
  request options, (err, response, body) ->
    if(err)
      console.log('conversation request err=' + err)
    console.log('conversation body=' + JSON.stringify(body))
    deferred.resolve('successful')
  deferred.promise

#  robot.http(config.CM_URL)
#  .headers('Content-Type' : 'application/json')
#  .query(request: input)
#  .post() (err, res, body) ->
#    parser.parseString body, (err, result) ->
#      console.log('stringfied response===' +JSON.stringify(result))
#      unless result.response.body[0].question
#        if result.response.body[0].statement
#          deferred.resolve result.response.body[0].statement[0]
#        deferred.resolve 'no response returned'
#        return deferred.promise
#
#      response = result.response.body[0]?.question[0]?
#      if typeof result.response.body[0].question[0] is 'string'
#        response = result.response.body[0].question[0]
#      else
#        if result.response.body[0].question[0].xul?
#          for k,v of result.response.body[0].question[0].xul[0]
#            json = result.response.body[0].question[0].xul[0]
#            response = json[k][0].question[0]._
#            if json[k][0].submit?
#              reply = json[k][0].submit[0].$.reply
#            response += '\nReply Hint: \n ' + reply
#      console.log('response===' + response)
#      unless response
#        deferred.resolve 'no response returned'
#      deferred.resolve response
#  deferred.promise

updateRobotId= (id, value) ->
  ep = new EventProxy();
  deferred = Q.defer()
  if value?
    console.log('listener cached value=' + JSON.stringify(value))
    input = TEMP.cmListener
    input.header.sessionId = value.body.result.sessionId
    input.body.username = value.body.result.username
    options = {
      uri: config.CM_URL,
      method: 'POST',
      json: input
    }
    console.log('listener robotjid input' + JSON.stringify(input))
    request options, (err, response, body) ->
      if(err)
        console.log('update robotid request err=' + err)
      console.log('listener body=' + JSON.stringify(body))
      value.robotjid = body.body.result.robotjid
      input.body.robotjid = body.body.result.robotjid

      optionsDialog = {
        uri: config.CM_URL,
        method: 'POST',
        json: input
      }
      console.log('listener dialog input' + JSON.stringify(input))
      request optionsDialog, (err2, response2, body2) ->
        if(err2)
          console.log('update dialog request err=' + err2)
        console.log('listener dialog body=' + JSON.stringify(body2))
        if body2.body.result.msg[0].info.xur.response.message?
          console.log ('dialog=' + body2.body.result.msg[0].info.xur.response.message['@value'])
          dialog = body2.body.result.msg[0].info.xur.response.message['@value']
          questionid = body2.body.result.msg[0].info.xur.response.message['@questionid']
          deferred.resolve dialog
          value.questionid = questionid
          cache.set(id, value)
  else
    deferred.resolve 'login fail'
  deferred.promise






