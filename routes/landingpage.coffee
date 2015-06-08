path = require 'path'

module.exports.getLandingpage = (request, response) ->
	response.render(
		path.join('landingpage','landingpage'),
		page: 'landing'
	)

module.exports.getContribute = (request, response) ->
	response.render(
		path.join('landingpage','contribute'),
		pageTitle: 'Contribute'
	)

module.exports.getTeam = (request, response) ->
	response.render(
		path.join('landingpage','team'),
		pageTitle: 'Team'
	)

module.exports.getImprint = (request, response) ->
	response.render(
		path.join('landingpage','imprint'),
		pageTitle: 'Imprint'
	)

module.exports.getEducators = (request, response) ->
	response.render(
		path.join('landingpage','educators')
		{
			page: 'landing',
			pageTitle: 'Educators'
		}
	)
