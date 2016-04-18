/**
 * Created by min on 4/13/16.
 */

var moment = require('moment');

var TEMP = {

  loginReq: "<message><header><action value='login' /><userid value='$uid' /><sessionid value=''/><orgid value='cyberobject'/><appid value='ntelagent'/><debug id=''/></header><body><usertype value='customer' /><channel value='CCSA' /></body></message>",
  conversationReq: "<message><header><action value='conversation' /><sessionid value='%s' /><userid value='%s'/><debug id=''/></header><body><message><![CDATA[%s]]></message></body></message>",
  cmLogin: {
    "header": {
      "action": "InitChatEnv",
      "moduleName": "",
      "sessionId": "",
      "ip": "",
      "requestId": "",
      "requestTime": moment().format('MM-DD-YYYY HH:mm:ss a')
    },
    "body": {
      "clientType": "http",
      "appid": "ntelagent",
      "debugid": "",
      "welcome": "connect",
      "dmode": "true"
    },
    "status": {
      "code": "0000",
      "message": "",
      "exception": ""
    }
  },
  cmConversation: {
    "header": {
      "action": "Sender",
      "moduleName": "",
      "sessionId": "", // required
      "ip": "",
      "requestId": "",
      "requestTime": moment().format('MM-DD-YYYY HH:mm:ss a')
    },
    "body": {
      "msg": "", //required - text
      "username": "TNeAMmIp@cyberobject.com", // required
      "appid": "ntelagent",
      "questionid": "",  //optional
      "robotjid": "",  //required
      "dmode": "true"
    },
    "status": {
      "code": "0000",
      "message": "",
      "exception": ""
    }
  },
  cmListener: {
    "header": {
      "action": "Listener",
      "moduleName": "",
      "sessionId": "",  //required
      "ip": "",
      "requestId": "",
      "requestTime": moment().format('MM-DD-YYYY HH:mm:ss a')
    },
    "body": {
      "username": "", //required
      "dmode": "true"
    },
    "status": {
      "code": "0000",
      "message": "",
      "exception": ""
    }
  }
}

module.exports = TEMP
