path = require 'path'

module.exports.getLandingpage = (request, response) ->
	response.render path.join('landingpage','landingpage'), page: 'landing'

module.exports.getContribute = (request, response) ->
	response.render path.join('landingpage','contribute')

module.exports.getTeam = (request, response) ->
	response.render path.join('landingpage','team')

module.exports.getImprint = (request, response) ->
	response.render path.join('landingpage','imprint')

module.exports.getEducators = (request, response) ->
	response.render path.join('landingpage','educators'), page: 'landing'

module.exports.getWebglTest = (request, response) ->
	response.render 'webgltest'
