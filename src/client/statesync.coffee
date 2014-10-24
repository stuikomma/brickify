jsondiffpatch = require 'jsondiffpatch'

state = {}
oldState = {}

globalConfigInstance = null
stateUpdateCallbacks = []

exports.state = state

exports.init = (globalConfig) ->
	globalConfigInstance = globalConfig

exports.sync = () ->
	delta = jsondiffpatch.diff oldState, state
	#deep copy
	oldState = JSON.parse JSON.stringify state

	$.post "/statesync", {deltaState: delta, stateSession: globalConfigInstance.stateSession}, (data, textStatus, jqXHR) ->
		#patch state with server changes
		delta = data
		jsondiffpatch.patch state, delta
		#deep copy
		oldState = JSON.parse JSON.stringify state

		for callback in stateUpdateCallbacks
			callback(state, delta)

exports.addUpdateCallback = (callback) ->
	stateUpdateCallbacks.push callback