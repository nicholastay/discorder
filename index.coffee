Discord = require 'discord.io'
startsWith = require 'lodash.startswith'
filter = require 'lodash.filter'
strftime = require 'strftime'
lame = require 'lame'
sanitizeFilename = require 'sanitize-filename'
path = require 'path'
fs = require 'fs-extra'
{config} = require './config'

discord = new Discord
    autorun: true
    email: config.discord.email
    password: config.discord.password

discord.on 'ready', -> console.log 'Logged into Discord as: ' + discord.username

recording = {status: false, server: null, channel: null}
recordTo = path.resolve (config.recordLocation or __dirname)
recTrigger = config.triggers?.record + ' ' or '!rec ' # Check for extra spaces as it checks if somethings after already
stopTrigger = config.triggers?.stop or '!stop'
discord.on 'message', (user, userID, channelID, message, rawEvent) ->
    msg = message.toLowerCase()
    if startsWith msg, recTrigger
        # Record
        return sendMessage userID, "Already recording (in #{recording.channel.name} [#{recording.server.name}])." if recording.status
        channelToJoin = message.substring recTrigger.length, message.length
        return sendMessage userID, 'No voice channel specified to join.' if not channelToJoin
        currentServerID = discord.serverFromChannel channelID
        server = discord.servers[currentServerID]
        # Use lodash filter to filter an object
        channels = filter server.channels, (channel) -> return channel.name is channelToJoin and channel.type is 'voice'
        return sendMessage userID, 'Invalid voice channel to join.' if channels.length < 1
        channel = channels[0]
        console.log 'Joining and starting recording in channel: ' + channel.name
        discord.joinVoiceChannel channel.id, ->
            discord.getAudioContext
                channel: channel.id
                stereo: true
            , (stream) ->
                sendMessage userID, "Started recording in #{channel.name} (#{server.name})."
                saveFileName = sanitizeFilename "#{channel.name}_(#{server.name})_#{strftime '%Y-%m-%d_%H-%M-%S'}".replace(/ /g, '_'), {replacement: '_'}
                writeStream = fs.createWriteStream path.join recordTo, (saveFileName + '.raw')
                recording = {status: true, server: server, channel: channel, filename: saveFileName, wstream: writeStream}
                stream.on 'incoming', (ssrc, buffer) ->
                    writeStream.write buffer
    else if startsWith msg, stopTrigger
        # Stop recording
        return sendMessage userID, 'Not currently recording anything.' if not recording.status
        sendMessage userID, "Stopping recording in #{recording.channel.name} (#{recording.server.name})."
        discord.leaveVoiceChannel recording.channel.id
        recording.wstream.end()
        # Encode with lame the raw pcm stream
        encoder = new lame.Encoder
            # In settings
            channels: 2
            bitDepth: 16
            sampleRate: 44100

            # Out settings
            bitRate: 128
            outSampleRate: 22050
            mode: lame.STEREO
        console.log 'Recording ended, encoding dumped raw data to lame mp3 format...'
        readStream = fs.createReadStream path.join recordTo, (recording.filename + '.raw')
        writeStream = fs.createWriteStream path.join recordTo, (recording.filename + '.mp3')
        readStream.pipe encoder
        encoder.pipe writeStream
        console.log 'Encoded file and now deleting tempfile'
        fs.removeSync path.join recordTo, (recording.filename + '.raw')
        recording = {status: false, server: null, channel: null}

# Wrapper sendMessage so dont have to send an object
sendMessage = (to, message) ->
    discord.sendMessage
        to: to
        message: message