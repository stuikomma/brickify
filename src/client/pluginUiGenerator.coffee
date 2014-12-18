$ = require 'jquery'
objectTree = require '../common/objectTree'

jsonEditorConfiguration = {
	theme: 'bootstrap3'
	disable_array_add: true
	disable_array_delete: true
	disable_array_reorder: true
	disable_collapse: true
	disable_edit_json: true
	disable_properties: true
}

pluginUiTemplate = '
			<div class="panel panel-default">
				<div class="panel-heading" role="tab">
					<h3 class="panel-title">
						<a data-toggle="collapse" data-parent="#pluginsContainer"
							 href="#collapse%PLUGINKEY%">%PLUGINNAME%</a>
					</h3>
				</div>
				<div id="collapse%PLUGINKEY%"
						 class="panel-collapse collapse plugincollapse" role="tabpanel">
					<div class="panel-body">
						<div id="pactions%PLUGINKEY%" class="pluginActionsContainer"></div>
						<div id="pcontainer%PLUGINKEY%" class="pluginSettingsContainer"></div>
					</div>
				</div>
			</div>
'

module.exports = class PluginUiGenerator
	constructor: (@bundle) ->
		@editors = {}
		@defaultValues = {}
		@pluginLayouts = []
		@currentlySelectedNode = null
		@$pluginsContainer = $('#pluginsContainer')
		@$pluginsContainer.hide()
		@tabStates = {}
		return

	createPluginUi: (pluginInstance) ->
		# creates the UI for a plugin if it returns a valid ui schema
		jsonEditorConfiguration.schema = pluginInstance.getUiSchema()
		if jsonEditorConfiguration.schema && @$pluginsContainer.length > 0
			pluginName = pluginInstance.name
			pluginKey = pluginName.toLowerCase().replace(/// ///g,'')

			pluginLayout = pluginUiTemplate
			pluginLayout = pluginLayout.replace(///%PLUGINKEY%///g,pluginKey)
			pluginLayout = pluginLayout.replace(///%PLUGINNAME%///g,pluginName)

			$pluginLayout = $(pluginLayout)
			@$pluginsContainer.append($pluginLayout)
			$pluginSettingsContainer = $('#pcontainer' + pluginKey)
			$pluginActionContainer = $('#pactions' + pluginKey)

			@generateActionUi jsonEditorConfiguration.schema, $pluginActionContainer
			@editors[pluginKey] = new JSONEditor(
				$pluginSettingsContainer[0]
				jsonEditorConfiguration
			)
			@defaultValues[pluginKey] = @editors[pluginKey].getValue()

			@editors[pluginKey].on 'change',() =>
				@saveUiToCurrentNode()

			@bindPluginUiEvents $pluginLayout, pluginInstance, pluginKey

			@pluginLayouts.push {
				collapse: $('#collapse' + pluginKey)
				pluginInstance: pluginInstance
			}

			@tabStates[pluginKey] = false

	bindPluginUiEvents: ($pluginLayout, pluginInstance, pluginKey) =>
			# when the panel is collapsed
			$pluginLayout.on 'hidden.bs.collapse', (event) =>
				@tabStates[pluginKey] = false
				@updateSelectedPlugin()

				if pluginInstance.uiDisabled?
					pluginInstance.uiDisabled @currentlySelectedNode

			# when the panel is opened
			$pluginLayout.on 'shown.bs.collapse', (event) =>
				@tabStates[pluginKey] = true
				@updateSelectedPlugin()

				if pluginInstance.uiEnabled?
					pluginInstance.uiEnabled @currentlySelectedNode

	generateActionUi: (schema, $container) ->
		if schema.actions?
			for own key of schema.actions
				title = schema.actions[key].title
				type = schema.actions[key].type or 'primary'
				$btn =
					$('<div class="actionbutton btn btn-' + type + '">' + title + '</div>')
				$btn.click (event) ->
					schema.actions[key].callback @currentlySelectedNode, event
				$container.append $btn

	selectPluginUi: (pluginKey) ->
		# collapse all if key is empty
		if not pluginKey or pluginKey.length == 0
			$('#pluginsContainer .collapse.in').collapse 'hide'

		data = $('#collapse' + pluginKey).data('bs.collapse')
		if data
			data.show()
		else
			$('#collapse' + pluginKey).collapse({
				parent: $('#pluginsContainer')
				toggle: true
			})

	updateSelectedPlugin: () ->
		# don't do anything if we aren't the last panel to close
		# (else: redundant state updates)
		if $('#pluginsContainer .collapsing').length > 0
			return

		# search for the activated (=true) plugin
		currentPlugin = @currentlySelectedNode.pluginData.uiGen.selectedPluginKey
		newPlugin = null

		for own pluginKey of @tabStates
			if @tabStates[pluginKey]
				newPlugin = pluginKey
				break

		if newPlugin and newPlugin != currentPlugin
			@bundle.statesync.performStateAction () =>
				# console.log "selected new plugin " + newPlugin
				@currentlySelectedNode.pluginData.uiGen.selectedPluginKey = pluginKey
		else if not newPlugin
			@bundle.statesync.performStateAction () =>
				# console.log "Deselected any plugin"
				@currentlySelectedNode.pluginData.uiGen.selectedPluginKey = ''

	selectNode: (stateNode) ->
		# is called by the scenegraph plugin when the user selects a model on the
		# left.
		@saveUiToCurrentNode()
		@currentlySelectedNode = stateNode
		@saveDefaultValues stateNode
		@applyNodeValuesToUi()
		@$pluginsContainer.show()
		oldNode = @currentlySelectedNode

		@selectPluginUi @currentlySelectedNode.pluginData.uiGen.selectedPluginKey

	deselectNodes: () ->
		# called when all nodes are deselected
		#console.log 'all nodes deselected'
		@saveUiToCurrentNode()
		@currentlySelectedNode = null
		@$pluginsContainer.hide()

	applyNodeValuesToUi: () =>
		for own key of @editors
			@editors[key].setValue(@currentlySelectedNode.toolsValues[key])

	saveUiToCurrentNode: () =>
		if @currentlySelectedNode
			for own key of @editors
				oldValues = @currentlySelectedNode.toolsValues[key]
				newValues = @editors[key].getValue()

				if JSON.stringify(oldValues) != JSON.stringify(newValues)
					updateNewValues = () =>
						@currentlySelectedNode.toolsValues[key] = newValues
					@bundle.statesync.performStateAction updateNewValues, true

	saveDefaultValues: (node) =>
		if not node.toolsValues
			node.toolsValues = {}
		for key of @editors
			if not node.toolsValues[key]
				node.toolsValues[key] = @defaultValues[key]
		if not node.pluginData.uiGen
			node.pluginData.uiGen = {
				selectedPluginKey: ''
			}
