# Description:
#   Remind to someone something
#
# Commands:
#   hubot remind me in # s|m|h|d to <something> - Set a reminder (e.g. 5m for five minutes)
#   hubot reminders - Show active reminders
#   hubot reminders forget <id> - Remove a given reminder

cronJob = require('cron').CronJob
moment = require('moment')

JOBS = {}

createNewJob = (robot, pattern, user, message) ->
  id = Math.floor(Math.random() * 1000000) while !id? || JOBS[id]
  job = registerNewJob robot, id, pattern, user, message
  robot.brain.data.things[id] = job.serialize()
  id

registerNewJobFromBrain = (robot, id, pattern, user, message) ->
  registerNewJob(robot, id, pattern, user, message)

registerNewJob = (robot, id, pattern, user, message) ->
  job = new Job(id, pattern, user, message)
  job.start(robot)
  JOBS[id] = job

unregisterJob = (robot, id)->
  if JOBS[id]
    JOBS[id].stop()
    delete robot.brain.data.things[id]
    delete JOBS[id]
    return yes
  no

handleNewJob = (robot, msg, user, pattern, message) ->
    id = createNewJob robot, pattern, user, message
    msg.send "Will do."

module.exports = (robot) ->
  robot.brain.data.things or= {}

  # The module is loaded right now
  robot.brain.on 'loaded', ->
    for own id, job of robot.brain.data.things
      console.log id
      registerNewJobFromBrain robot, id, job...

  robot.respond /reminders/i, (msg) ->
    text = ''
    for id, job of JOBS
      room = job.user.reply_to || job.user.room
      if room == msg.message.user.reply_to or room == msg.message.user.room
        text += "#{id}: @#{room} to \"#{job.message} at #{job.pattern}\"\n"
    if text.length > 0
      msg.send text
    else
      msg.send "No reminders!"

  robot.respond /reminders forget (\d+)/i, (msg) ->
    reqId = msg.match[1]
    for id, job of JOBS
      if (reqId == id)
        if unregisterJob(robot, reqId)
          msg.send "Reminder #{id} removed..."
        else
          msg.send "Sorry, couldn't find that reminder."

  robot.respond /remind me in (\d+) ?(s|m|h|d|seconds|minutes|hours|days) to (.*)/i, (msg) ->
    at = msg.match[1]
    timeWord = msg.match[2]
    something = msg.match[3]
    users = [msg.message.user]

    switch timeWord
      when 's' then timeWord = 'second'
      when 'm' then timeWord = 'minute'
      when 'h' then timeWord = 'hour'
      when 'd' then timeWord = 'day'

    handleNewJob robot, msg, users[0], moment().add(at, timeWord).toDate(), something



class Job
  constructor: (id, pattern, user, message) ->
    @id = id
    @pattern = pattern
    # cloning user because adapter may touch it later
    clonedUser = {}
    clonedUser[k] = v for k,v of user
    @user = clonedUser
    @message = message

  start: (robot) ->
    @cronjob = new cronJob(@pattern, =>
      @sendMessage robot, ->
      unregisterJob robot, @id
    )
    @cronjob.start()

  stop: ->
    @cronjob.stop()

  serialize: ->
    [@pattern, @user, @message]

  sendMessage: (robot) ->
    envelope = user: @user, room: @user.room
    message = @message
    if @user.mention_name
      message = "@#{envelope.user.mention_name}: " + @message
    else
      message = "@#{envelope.user.name}: " + @message
    robot.send envelope, message

