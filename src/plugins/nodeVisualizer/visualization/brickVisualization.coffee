GeometryCreator = require './GeometryCreator'
THREE = require 'three'
Coloring = require './Coloring'
StabilityColoring = require './StabilityColoring'
interactionHelper = require '../../../client/interactionHelper'
VoxelWireframe = require './VoxelWireframe'
VoxelSelector = require '../VoxelSelector'

###
# This class provides visualization for Voxels and Bricks
# @class BrickVisualization
###
class BrickVisualization
	constructor: (
		@bundle,  @brickThreeNode, @brickShadowThreeNode, @defaultColoring) ->

		@csgSubnode = new THREE.Object3D()
		@brickThreeNode.add @csgSubnode
	
		@bricksSubnode = new THREE.Object3D()
		@brickThreeNode.add @bricksSubnode

		@stabilityColoring = new StabilityColoring()

		@printVoxels = []

		@isStabilityView = false

	initialize: (@grid) =>
		@voxelWireframe = new VoxelWireframe(
			@bundle, @grid, @brickShadowThreeNode, @defaultColoring
		)
		@geometryCreator = new GeometryCreator(@grid)
		@voxelSelector = new VoxelSelector @

	showCsg: (newCsgMesh) =>
		@csgSubnode.children = []
		return if not newCsgMesh?

		@csgSubnode.add newCsgMesh
		newCsgMesh.material = @defaultColoring.csgMaterial

		@csgSubnode.visible = true

	hideCsg: =>
		@csgSubnode.visible = false

	hideVoxelAndBricks: =>
		@bricksSubnode.visible = false

	showVoxelAndBricks: =>
		@bricksSubnode.visible  = true

	# updates brick and voxel visualization
	updateVisualization: (coloring = @defaultColoring, recreate = false) =>
		# throw out all visual bricks that have no valid linked brick
		for layer in @bricksSubnode.children
			deletionList = []
			for visualBrick in layer.children
				if not visualBrick.brick? or not visualBrick.brick.isValid()
					deletionList.push visualBrick

			for delBrick in deletionList
				# remove from scenegraph
				layer.remove delBrick
				# delete reference from datastructure brick
				if delBrick.brick?
					delBrick.brick.setVisualBrick null

		# Recreate visible bricks for all bricks in the datastructure that 
		# have no linked brick

		# sort layerwise for build view
		brickLayers = []
		@grid.getAllBricks().forEach (brick) ->
			z = brick.getPosition().z
			brickLayers[z] ?= []

			if not brick.getVisualBrick()?
				brickLayers[z].push brick

		for z, brickLayer of brickLayers
			# create layer object if it does not exist
			if not @bricksSubnode.children[z]?
				layerObject = new THREE.Object3D()
				@bricksSubnode.add layerObject

			layerObject = @bricksSubnode.children[z]

			for brick in brickLayer
				# create visual brick
				material = coloring.getMaterialForBrick brick
				threeBrick = @geometryCreator.getBrick(
					brick.getPosition(), brick.getSize(), material
				)

				# link data <-> visuals
				brick.setVisualBrick threeBrick
				threeBrick.brick = brick

				# add to scene graph
				layerObject.add threeBrick
		
		# if this coloring differs from the last used coloring, go through
		# all visible bricks to update their material
		if @_oldColoring? and @_oldColoring != coloring
			for layer in @bricksSubnode.children
				for visualBrick in layer.children
					material = coloring.getMaterialForBrick visualBrick.brick
					visualBrick.setMaterial material
		@_oldColoring = coloring

		# code from updateVoxelVisualization

		@unhighlightBigBrush()

		# show not filled lego shape as outline
		outlineCoords = @printVoxels.map (voxel) -> voxel.voxelCoords
		@voxelWireframe.createWireframe outlineCoords

		# / code from updateVoxelVisualization

		#ToDo: hide studs when brick is completely below other brick

	setPossibleLegoBoxVisibility: (isVisible) =>
		@voxelWireframe.setVisibility isVisible

	setStabilityView: (enabled) =>
		@isStabilityView = enabled
		coloring = if @isStabilityView then @stabilityColoring else @defaultColoring
		@updateVisualization(coloring)

		# Turn off possible lego box during stability view
		if enabled
			@_legoBoxVisibilityBeforeStability = @voxelWireframe.isVisible()
			@voxelWireframe.setVisibility false
		else
			@voxelWireframe.setVisibility @_legoBoxVisibilityBeforeStability

	showBrickLayer: (layer) =>
		for i in [0..@bricksSubnode.children.length - 1] by 1
			if i <= layer
				@bricksSubnode.children[i].visible = true
			else
				@bricksSubnode.children[i].visible = false

		@showBricks()

	# highlights the voxel below mouse and returns it
	highlightVoxel: (event, selectedNode, type, bigBrush) =>
		# invert type, because if we are highlighting a 'lego' voxel
		# we want to display it as 'could be 3d printed'
		voxelType = '3d'
		voxelType = 'lego' if type == '3d'

		highlightMaterial = @defaultColoring.getHighlightMaterial voxelType
		hVoxel = highlightMaterial.voxel
		hBox = highlightMaterial.box

		voxel = @voxelSelector.getVoxel event, {type: type}
		if voxel?
			if @currentlyHighlightedVoxel?
				@currentlyHighlightedVoxel.setHighlight false

			@currentlyHighlightedVoxel = voxel
			voxel.setHighlight true, hVoxel
			@_highlightBigBrush voxel, hBox if bigBrush
		else
			# clear highlight if no voxel is below mouse
			if @currentlyHighlightedVoxel?
				@currentlyHighlightedVoxel.setHighlight false
			@unhighlightBigBrush()

		return voxel


	_highlightBigBrush: (voxel, material) =>
		size = @voxelSelector.getBrushSize true
		dimensions = new THREE.Vector3 size.x, size.y, size.z
		unless @bigBrushHighlight? and
		@bigBrushHighlight.dimensions.equals dimensions
			@brickShadowThreeNode.remove @bigBrushHighlight if @bigBrushHighlight
			@bigBrushHighlight = @geometryCreator.getBrickBox(
				dimensions
				material
			)
			@brickShadowThreeNode.add @bigBrushHighlight

		@bigBrushHighlight.position.copy voxel.position
		@bigBrushHighlight.material = material
		@bigBrushHighlight.visible = true

	unhighlightBigBrush: =>
		@bigBrushHighlight?.visible = false

	# makes the voxel below mouse to be 3d printed
	makeVoxel3dPrinted: (event, selectedNode, bigBrush) =>
		if bigBrush
			mainVoxel = @voxelSelector.getVoxel event, {type: 'lego'}
			mat = @defaultColoring.getHighlightMaterial '3d'
			@_highlightBigBrush mainVoxel, mat.box if mainVoxel?
		voxels = @voxelSelector.getVoxels event, {type: 'lego', bigBrush: bigBrush}
		return null unless voxels

		for voxel in voxels
			voxel.make3dPrinted()
			voxel.visible = false
			coords = voxel.voxelCoords
			voxelBelow = @grid.getVoxel(coords.x, coords.y, coords.z - 1)
			if voxelBelow?.enabled
				voxelBelow.visibleVoxel.setStudVisibility true
		return voxels

	###
	# @return {Boolean} true if anything changed, false otherwise
	###
	makeAllVoxels3dPrinted: (selectedNode) =>
		voxels = @voxelSelector.getAllVoxels(selectedNode)
		anythingChanged = false
		for voxel in voxels
			anythingChanged = anythingChanged || voxel.isLego()
			voxel.make3dPrinted()
			@voxelSelector.touch voxel
		return anythingChanged

	resetTouchedVoxelsToLego: =>
		voxel.makeLego() for voxel in @voxelSelector.touchedVoxels
		@voxelSelector.clearSelection()

	# makes the voxel below mouse to be made out of lego
	makeVoxelLego: (event, selectedNode, bigBrush) =>
		if bigBrush
			mainVoxel = @voxelSelector.getVoxel event, {type: '3d'}
			mat = @defaultColoring.getHighlightMaterial 'lego'
			@_highlightBigBrush mainVoxel, mat.box if mainVoxel?
		voxels = @voxelSelector.getVoxels event, {type: '3d', bigBrush: bigBrush}
		return null unless voxels

		for voxel in voxels
			voxel.makeLego()
			voxel.visible = true
			voxel.setMaterial @defaultColoring.selectedMaterial
		return voxels

	###
	# @return {Boolean} true if anything changed, false otherwise
	###
	makeAllVoxelsLego: (selectedNode) =>
		voxels = @voxelSelector.getAllVoxels(selectedNode)
		everythingLego = true
		for voxel in voxels
			everythingLego = everythingLego && voxel.isLego()
			voxel.makeLego()
			voxel.visible = true
		return !everythingLego

	resetTouchedVoxelsTo3dPrinted: =>
		voxel.make3dPrinted() for voxel in @voxelSelector.touchedVoxels
		@voxelSelector.clearSelection()

	# clears the selection and updates the possibleLegoWireframe
	updateModifiedVoxels: =>
		@printVoxels = @printVoxels
			.concat @voxelSelector.touchedVoxels
			.filter (voxel) -> not voxel.isLego()
		return @voxelSelector.clearSelection()

module.exports = BrickVisualization
