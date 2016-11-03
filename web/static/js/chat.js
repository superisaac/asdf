'use strict';

import $ from 'jquery'
import socket from './socket'

export var Api = {
  getJSON: function(path, args, callback) {
    if(typeof args == 'function') {
      callback = args
      args = {}
    }
    args['stoken'] = window.apiToken
    return $.getJSON(path, args, callback)
  },
  postJSON: function(path, args, callback) {
    if(typeof args == 'function') {
      callback = args;
      args = {}
    }
    if(/\?/.test(path)) {
      path += '&stoken=' + window.apiToken
    } else {
      path += '?stoken=' + window.apiToken
    }
    return $.post(path, args, callback)
  }
}

// method
function leftPad(numStr, n, c) {
  c = c || '0';
  if(typeof numStr != 'string') {
    numStr = numStr.toString()
  }
  while(numStr.length < n) {
    numStr = '0' + numStr
  }
  return numStr
}

// simple text tokenizer
export function Tokenizer(text) {
  this.text = text
}

Tokenizer.prototype.nextToken = function() {
  if(!this.text) return undefined
  let r = /^<([@#])([^<>\n]+)>/.exec(this.text)
  if(r) {
    let symbol = r[1]
    let arr = r[2].split('|')
    this.text = this.text.substr(r[0].length)
    if(symbol == '@') {
      return {
        'kind': 'user',
        'id': parseInt(arr[0]),
        'name': arr[1]
      }
    } else { //if(symbol == '#') {
      return {
        'kind': 'room',
        'id': parseInt(arr[0]),
        'name': arr[1]
      }
    }
  }

  r = /^([^<\n]+|<)/.exec(this.text)
  if(r) {
    let v = r[0]
    this.text = this.text.substr(v.length)
    return {
      kind: 'text',
      text: v
    }
  }

  r = /^\n/.exec(this.text)
  if(r) {
    let v = r[0]
    this.text = this.text.substr(v.length)
    return {
      kind: 'nl',
      text: v
    }
  }

  return null
}

Tokenizer.prototype.tokenList = function() {
  let arr = []
  let token = this.nextToken()
  let lastToken = null
  while(token) {
    if(token.kind != 'text') {
      if(lastToken) {
        arr.push(lastToken)
        lastToken = null
      }
      arr.push(token)
    } else if(lastToken){
      lastToken.text += token.text
    } else {
      lastToken = token
    }
    token = this.nextToken()
  }
  if(lastToken) {
    arr.push(lastToken)
    lastToken = null
  }
  return arr
}

// models
function User(data) {
  this.id = data.id;
  this.name = data.name;
  this.is_admin = data.is_admin;
}

function Room(data) {
  this.id = data.id;
  this.name = data.name;
  this.type = data.type;
  this.user_id = data.user_id;
  this.user_name = data.user_name;
  this.peer_id = data.peer_id;
  this.peer_name = data.peer_name;
  this.peer_start_menu = (data.peer_start_menu || []).slice(0, 5)
  
  if(this.type == 'directmsg') {
    this.fullname = '*' + this.peer_name;
    this.target = '@' + this.peer_name;
  } else {
    this.fullname = this.user_name + '/' + this.name;
    this.target = '#' + this.fullname;
  }
  this.last_msg_id = data.last_msg_id;
  this.first_msg_id = data.first_msg_id;
  this.unreadCount = 0;
}

function Msg(data) {
  this.id = data.id;
  this.user_id = data.user_id;
  this.user_name = data.user_name;
  this.room_id = data.room_id;
  this.room_name = data.room_name;
  this.content = data.content
  this.created_at = new Date(data.created_at)
  this.args = data.args
  this.msgType = (data.args && data.args.msg_type) || "text"
  this.minute = (leftPad(this.created_at.getHours(), 2) +
                 ':' + leftPad(this.created_at.getMinutes() + 1, 2))
  this.dayStr = (leftPad(this.created_at.getYear() + 1900, 4) +
                 '-' + leftPad(this.created_at.getMonth() + 1, 2) +
                 '-' + leftPad(this.created_at.getDate(), 2))
  
  let tokenizer = new Tokenizer(this.content)
  this.html = tokenizer.tokenList().map((token) => {
    switch(token.kind) {
    case 'text':
      //return escape(token.text)
      return token.text
    case 'room':
      return '<a href="javascript:void(0)">#' + token.name + '</a>'
    case 'user':
      return '<a href="javascript:void(0)">@' + token.name + '</a>'
    case 'nl':
      return '<br/>'
    }
  }).join('')
  console.info('html', this.html)
}

Msg.prototype.getUser = function() {
  return new User({id: this.user_id, name: this.user_name});
}

function DaySection(day) {
  this.day = day;
  this.msgs = [];
}

function MsgList(sections) {
  this.sections = sections || [];
}

MsgList.prototype.firstMsg = function() {
  let section = this.sections[0]
  if(section) {
    let msg = section.msgs[0]
    return msg
  }
}

MsgList.prototype.clone = function(msg) {
  return new MsgList(this.sections)
}

MsgList.prototype.unshiftMsg = function(msg) {
  if(this.sections.length == 0) {
    let sec = new DaySection(msg.dayStr)
    sec.msgs.unshift(msg)
    this.sections.unshift(sec)
  } else {
    let sec = this.sections[0]
    if(sec.day == msg.dayStr) {
      sec.msgs.unshift(msg);
    } else {
      let sec = new DaySection(msg.dayStr);
      sec.msgs.unshift(msg);
      this.sections.unshift(sec);
    }
  }  
}

MsgList.prototype.pushMsg = function(msg) {
  if(this.sections.length == 0) {
    let sec = new DaySection(msg.dayStr);
    sec.msgs.push(msg);
    this.sections.push(sec);
  } else {
    let sec = this.sections[this.sections.length - 1];
    if(sec.day == msg.dayStr) {
      sec.msgs.push(msg);
    } else {
      let sec = new DaySection(msg.dayStr);
      sec.msgs.push(msg);
      this.sections.push(sec);
    }
  }  
}

// Vue 
export var chatVM = new Vue({
  el: '#asdf-chat',
  data: {
    currentUser: new User({name: ""}),
    rooms: [],
    msgList: new MsgList(),
    hasOlderMsgs: false,
    roomJoined: true,
    room: new Room({name: "", user_name: ""}),
    members: [],
    channel: null
  },
  watch: {
    msgList: (val, oldval) => {
      setTimeout(() => {
        let d = $('#msg-scroller')
        d.scrollTop(d.prop('scrollHeight'))
      }, 10)
    }
  },
  methods: {
    getProfile: function() {
      // Get current user
      let vm = this
      Api.getJSON('/api/profile', (data) => {
        if(data.ok) {
          vm.currentUser = new User(data.user);
          vm.listenUserChannel()
        } else {
          console.error(data.error)
        }
      })
      return this
    },

    openSelect: function(reply_id, val) {
      let params = {
        target: "#" + this.room.id,
        reply: reply_id,
        template: 'select',
        action: val
      }
      Api.postJSON('/api/chat.postGadgetAction', params, (data) => {
        if(data.ok) {
          console.info('post event', params, data)
        } else {
          console.error(data.error)
        }
      })
    },

    openSubmit: function(e) {
      let form = $(e.target)
      e.stopPropagation()
      e.preventDefault()

      $(':input[name=target]', form).val('#' + this.room.id)
      let formData = form.serialize()
      Api.postJSON('/api/chat.postGadgetAction', formData, (data) => {
        if(data.ok) {
          console.info('post event', params, data)
        } else {
          console.error(data.error)
        }
      })
    },
    
    openAssistant: function() {
      this.openRoom("@system/assist")
    },

    listenUserChannel: function() {
      let vm = this
      if(!this.channel) {
        this.channel = socket.channel("user:" + vm.currentUser.id, {})
        this.channel.join()
          .receive("ok", resp => { console.log("Joined successfully", resp) })
          .receive("error", resp => { console.log("Unable to join", resp) })

        this.channel.on('new_msg', (body) => {
          let msg = new Msg(body.message);
          let room = vm.getRoomFromList(msg.room_id)
          if(room) {
            // update roomlist
            room.last_msg_id = msg.id            
            vm.rooms = vm.rooms.sort((a, b) => {
              return b.last_msg_id - a.last_msg_id
            }).slice(0)
            
            if(vm.room.fullname == room.fullname) {
              // is current room
              let msgList = vm.msgList.clone()
              msgList.pushMsg(msg)
              vm.msgList = msgList
            } else {
              room.unreadCount++;
            }
          } else {
            vm.getJoinedRooms(false)
          }
        })
        this.channel.on('profile_changed', (data) => {
          if(!vm.currentUser || vm.currentUser.id == data.user_id) {
            vm.getProfile()
            vm.getJoinedRooms(false)
          }
        })
        this.channel.on('data_changed', () => {
          vm.getProfile()
          vm.getJoinedRooms(false)
        })
      }
    },


    getRoomFromList: function(room_id) {
      for(let i=0; i<this.rooms.length; i++) {
        let room = this.rooms[i];
        if(room.id == room_id) {
          return room
        }
      }
    },

    roomClicked: function(roomName) {
      for(var i=0; i<this.rooms.length; i++) {
        let room = this.rooms[i];
        if(room.fullname == roomName) {
          if(room.fullname != this.room.fullname) {
            this.openRoom(room);
          }
          break;
        }
      }
    },

    getJoinedRooms: function(openFirst) {
      let vm = this
      openFirst = openFirst || false
      // Get room list
      Api.getJSON('/api/room.joined', (data) => {
        if(data.ok) {
          vm.rooms = data.rooms.map((roomData) => {
            return new Room(roomData)
          })
          if(openFirst || vm.rooms.length > 0) {
            let room = vm.rooms[0]
            vm.openRoom(room)
          }
        }
      })
      return this
    },

    openOlderMsgs: function() {
      let room = this.room
      let vm = this
      let firstMsg = this.msgList.firstMsg()
      let params = {room: '#' + room.id}
      if (firstMsg) {
        params.max_id = firstMsg.id
      }
      Api.getJSON(
        '/api/chat.history',
        params, (data) => {
          if(data.ok) {
            let room = new Room(data.room)
            vm.room = room
            data.msgs.forEach((msgData) => {
              let msg = new Msg(msgData);
              vm.msgList.unshiftMsg(msg)
            });

            vm.setHasOlderMsgs()
          } else {
            console.error(data.error)
          }
        })
    },
    
    getRoomMembers: function(room) {
      let vm = this
      Api.getJSON('/api/room.members',
                  {room: '#' + room.id},
                  (data) => {
                    console.info('members', data)
                    if(data.ok) {
                      vm.members = data.users
                    } else {
                      console.error(data.error)
                    }
                  })
    },

    openRoom: function(roomOrName){
      let vm = this
      let roomId = (typeof roomOrName == "string")?roomOrName:('#' + roomOrName.id)
      
      let params = {
        room: roomId
      }
        //let params = {room: '#' + room.id}
      vm.hasOlderMsgs = false

      Api.getJSON(
        '/api/chat.history',
        params, (data) => {
          if(data.ok) {
            vm.roomJoined = true
            let room = new Room(data.room)
            vm.room = room
            var msgList = new MsgList();
            data.msgs.reverse().forEach((msgData) => {
              let msg = new Msg(msgData);
              msgList.pushMsg(msg)
            });
            vm.msgList = msgList
            room.unreadCount = 0
            vm.setHasOlderMsgs()
            this.getRoomMembers(room)
          } else if(data.error == 'room_not_joined') {
            vm.roomJoined = false
            vm.msgList = new MsgList()
          } else {
            console.error(data.error)
          }
        })
    }, // end of openRoom()

    setHasOlderMsgs: function() {
      let fm = this.msgList.firstMsg()
      if(fm && this.room) {
        this.hasOlderMsgs = fm.id > this.room.first_msg_id
      } else {
        this.hasOlderMsgs = false
      }      
    },

    senderKeyUp: function(e) {
      let vm = this
      if(e.keyCode == 13 && !e.ctrlKey && !e.metaKey) {
        var text = $('#msg-sender input#text').val();
        if(text && vm.room) {
          $('#msg-sender input#text').val('')
          this.eatText(text)
        }
      }
    },

    eatText: function(text) {
      let r = /^(\/(\w+)\s+)?([\s\S]*)$/.exec(text)
      let command = r[2]
      let vm = this
      if(command == 'join') {
        let roomName = r[3]
        if(!/^#/.test(roomName)) {
          roomName = '#' + roomName
        }
        Api.postJSON('/api/room.join',
                     {room: roomName},
                     (data) => {
                       if(data.ok) {
                         vm.getJoinedRooms(true)
                       } else {
                         console.error(data.error)
                       }
                     })
      } else if(command == 'msg') {
        let arr = r[3].split(' ')
        let userName = arr[0]
        let rest = arr.slice(1).join(' ')
        Api.postJSON('/api/chat.postMessage',
                     {target: '@' + userName,
                      text: rest},
                     (data) => {
                       console.info('post direct msg', data);
                     })
      } else {
        Api.postJSON('/api/chat.postMessage',
                     {target: vm.room.target,
                      text: text},
                     (data) => {
                       //console.info('post message', data);
                     })
      }
    } // end of eatText
  }
})

export var ready = function() {
  function adjustComponents() {
    let headerHeight = $('#msg-header').outerHeight(true)
    let senderHeight = $('#msg-sender').outerHeight(true)
    let windowHeight = Math.max($(window).height(), 600);
    $('#msg-body').height(windowHeight - headerHeight - senderHeight - 12);
  }
  
  $(window).resize(adjustComponents);
  setTimeout(adjustComponents, 200)
  
  chatVM.getProfile()
  chatVM.getJoinedRooms(true)
}
