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

parser = new xml2js.Parser()

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
    console.log('recieved skype message=' + text)
    console.log('recieved skype id=' + id)
    ep = new EventProxy();
    room = 'GENERAL'
    if text is 'login'
      loginCM(id, robot)
      .then((result) ->
        cache.set(id, result)
        question = id + ': ' + text + '\n'
        response = 'Login sucessfully with sid ' + result.body.result.sessionId
        robot.messageRoom room, question+response
        res.send response
      )
    else
      ep.fail (err)->
        logger.error 'Failed to retreive data from Redis server', err

      ep.all 'cache', (value) ->
        console.log('cached value=' + JSON.stringify(value))
        if value?
          sendToCM(value text, robot)
          .then((result) ->
            console.log('conversation result=' + result)
            question = id + ': ' + text + '\n'
            robot.messageRoom room, question+result
            res.send result
          )
        else
          loginCM(id, robot)
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

loginCM= (id, robot) ->
  deferred = Q.defer()
  console.log('login=' + JSON.stringify(TEMP.cmLogin))
  input = JSON.stringify(TEMP.cmLogin)
  robot.http(config.CM_URL)
  .headers('Content-Type' : 'application/json')
  .query(request: input)
  .post() (err, res, body) ->
    console.log('login msg===' + id)
    console.log('login body===' + body)
    result = JSON.parse(body)
    if result.status.code is not '0000'
        deferred.resolve('Login fail')
        return deferred.promise
    sessionId = result.body.result.sessionId?
    console.log('sessionid=' + sessionId)
    result['profile'] = {'id': id}
    console.log 'login result' + JSON.stringify(result)
    unless sessionId
      deferred.resolve('Login fail')
    deferred.resolve(result)
  deferred.promise

sendToCM= (value, sentence, robot) ->
  deferred = Q.defer()
  session = value.body.result.sessionId
  id = value.profile.id
  input = util.format TEMP.cmConversation, session, id, sentence
  console.log('conversation input===' + input)
  response = ''
  robot.http(config.CM_URL)
  .headers('Content-Type' : 'application/xml')
  .query(request: input)
  .post() (err, res, body) ->
    parser.parseString body, (err, result) ->
      console.log('stringfied response===' +JSON.stringify(result))
      unless result.response.body[0].question
        if result.response.body[0].statement
          deferred.resolve result.response.body[0].statement[0]
        deferred.resolve 'no response returned'
        return deferred.promise

      response = result.response.body[0]?.question[0]?
      if typeof result.response.body[0].question[0] is 'string'
        response = result.response.body[0].question[0]
      else
        if result.response.body[0].question[0].xul?
          for k,v of result.response.body[0].question[0].xul[0]
            json = result.response.body[0].question[0].xul[0]
            response = json[k][0].question[0]._
            if json[k][0].submit?
              reply = json[k][0].submit[0].$.reply
            response += '\nReply Hint: \n ' + reply
      console.log('response===' + response)
      unless response
        deferred.resolve 'no response returned'
      deferred.resolve response
  deferred.promise


