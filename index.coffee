express = require 'express'
SocketServer = require('ws').Server
request = require 'request'
path = require 'path'
_ = require 'underscore'
cache = require 'memory-cache'

server = express()
	.use (req, res) => 
		res.header 'Access-Control-Allow-Origin', '*'
		res.header 'Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept'
		res.sendFile path.join __dirname, 'index.html'
	.listen 3000, () =>
		console.log 'Listening on port 3000'

wss = new SocketServer {server}
clients = []

wss.on 'connection', (ws) =>
	console.log 'Client connected'
	clients.push ws
	ws.onmessage = (e) =>
		obj = JSON.parse e.data
		switch obj.type
			when 'chatEvent'
				for client in clients
					client.send JSON.stringify obj
				updateLogs obj
			when 'exchangeCandidates'
				for client in clients
					client.send JSON.stringify obj
			when 'exchangeDescription'
				for client in clients
					client.send JSON.stringify obj
			when 'startStream'
				ws.id = 'streamer'
				cache.put 'stream', true
				readyForExchange()
			when 'endStream'
				ws.id = null
				cache.del 'stream'
				closeComms()
			when 'startView'
				ws.id = 'viewer'
				cache.put 'viewer', true
				readyForExchange()
			when 'endView'
				ws.id = null
				cache.del 'viewer'
				closeComms()
			when 'isStreamActive'
				ws.send JSON.stringify
					type: 'isStreamActive'
					answer: cache.get 'stream'
			when 'hasViewer'
				ws.send JSON.stringify
					type: 'hasViewer'
					answer: cache.get 'viewer'
			else
				console.error 'Unrecognized message type'
	ws.on 'close', () => 
		if ws.id is 'streamer' then cache.del 'stream'
		if ws.id is 'viewer' then cache.del 'viewer'
		console.log 'Client disconnected'
		clients = _.without clients, ws

readyForExchange = () ->
	if cache.get('stream') and cache.get('viewer')
		for client in clients
			client.send JSON.stringify
				type: 'readyForExchange'

closeComms = () ->
	for client in clients
		client.send JSON.stringify
			type: 'closeComms'

updateLogs = (obj) ->
	request
		method: 'POST'
		url: 'https://fathomless-retreat-96857.herokuapp.com/updateLog/'
		headers:
			'content-type': 'application/x-www-form-urlencoded'
		form:
			name: obj.name
			userId: obj.userId
			time: obj.time
			message: obj.message
		, (err, res, body) ->
			if err
				console.error err
			else
				console.log res.body
