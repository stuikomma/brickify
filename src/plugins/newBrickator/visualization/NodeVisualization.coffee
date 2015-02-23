GeometryCreator = require './GeometryCreator'
THREE = require 'three'
Coloring = require './Coloring'
interactionHelper = require '../../../client/interactionHelper'
VoxelWireframe = require './VoxelWireframe'

# This class represents the visualization of a node in the scene
module.exports = class NodeVisualization
	constructor: (@bundle, @threeNode, @grid) ->
		@voxelsSubnode = new THREE.Object3D()
		@bricksSubnode = new THREE.Object3D()

		@threeNode.add @voxelsSubnode
		@voxelWireframe = new VoxelWireframe(@grid, @threeNode)

		@threeNode.add @bricksSubnode

		@defaultColoring = new Coloring()
		@geometryCreator = new GeometryCreator(@grid)

		@currentlyDeselectedVoxels = []
		@modifiedVoxels = []

	showVoxels: () =>
		@voxelsSubnode.visible = true
		@bricksSubnode.visible = false

	showBricks: () =>
		@bricksSubnode.visible = true
		@voxelsSubnode.visible = false

	hideAll: () =>
		@threeNode.visible = false

	showAll: () =>
		@threeNode.visible  = true

	updateVoxelVisualization: (coloring = @defaultColoring, recreate = false) =>
		# (re)creates voxel visualization.
		# hides disabled voxels, updates material and knob visibility

		if not @voxelsSubnode.children or @voxelsSubnode.children.length == 0 or
		recreate
			@_createVoxelVisualization coloring
			return

		# update materials and show/hide knobs
		for v in @voxelsSubnode.children
			# get material
			material = coloring.getMaterialForVoxel v.gridEntry
			v.setMaterial material
			@_updateVoxel v

		# show not filled lego shape as outline
		outlineVoxels = []
		for v in @modifiedVoxels
			if not v.isEnabled()
				outlineVoxels.push {
					x: v.voxelCoords.x
					y: v.voxelCoords.y
					z: v.voxelCoords.z
				}
		@voxelWireframe.createWireframe outlineVoxels

	_createVoxelVisualization: (coloring) =>
		# clear and create voxel visualization

		@voxelsSubnode.children = []

		for z in [0..@grid.numVoxelsZ - 1] by 1
			for x in [0..@grid.numVoxelsX - 1] by 1
				for y in [0..@grid.numVoxelsY - 1] by 1
					if @grid.zLayers[z]?[x]?[y]?
						voxel = @grid.zLayers[z][x][y]
						material = coloring.getMaterialForVoxel voxel
						threeBrick = @geometryCreator.getVoxel {x: x, y: y, z: z}, material
						@_updateVoxel threeBrick
						@voxelsSubnode.add threeBrick

	_updateVoxel: (threeBrick) =>
		# makes disabled voxels invisible, toggles knob visibility

		if not threeBrick.isEnabled()
			threeBrick.visible = false

		coords = threeBrick.voxelCoords
		if @grid.getVoxel(coords.x, coords.y, coords.z + 1)?.enabled
			threeBrick.setKnobVisibility false
		else
			threeBrick.setKnobVisibility true

	updateBricks: (@bricks) =>
		@updateBrickVisualization()
		return

	updateBrickVisualization: (coloring = @defaultColoring) =>
		@bricksSubnode.children = []

		for brickLayer in @bricks
			layerObject = new THREE.Object3D()
			@bricksSubnode.add layerObject

			for brick in brickLayer
				material = coloring.getMaterialForBrick brick
				threeBrick = @geometryCreator.getBrick brick.position, brick.size, material
				layerObject.add threeBrick

	showBrickLayer: (layer) =>
		for i in [0..@bricksSubnode.children.length - 1] by 1
			if i <= layer
				@bricksSubnode.children[i].visible = true
			else
				@bricksSubnode.children[i].visible = false

		@showBricks()

	highlightVoxel: (event, condition) =>
		# highlights the voxel below mouse and returns it
		voxel = @getVoxel event

		if voxel?
			if @currentlyHighlightedVoxel?
				@currentlyHighlightedVoxel.setHighlight false

			if condition?
				return if not condition(voxel)

			@currentlyHighlightedVoxel = voxel
			voxel.setHighlight true, @defaultColoring.highlightMaterial

		return voxel

	deselectVoxel: (event) =>
		# disables the voxel below mouse
		voxel = @getVoxel event

		if voxel and voxel.isEnabled()
			voxel.disable()
			voxel.setMaterial @defaultColoring.deselectedMaterial
			@currentlyDeselectedVoxels.push voxel

	selectVoxel: (event) =>
		# enables the voxel below mouse
		voxel = @getVoxel event

		if voxel and not voxel.isEnabled()
			voxel.enable()
			voxel.setMaterial @defaultColoring.selectedMaterial

	updateModifiedVoxels: () =>
		# moves all currenly deselected voxels
		# to modified voxels

		for v in @currentlyDeselectedVoxels
			@modifiedVoxels.push v

		@currentlyDeselectedVoxels = []

	createInvisibleSuggestionBricks: () =>
		# out of all voxels that can be enabled, create an
		# invisible layer so that the user can select (raycaster)
		# them and the selected voxel can be highlighted

		newModifiedVoxel = []

		for v in @modifiedVoxels
			# ignore and removed enabled voxel
			if v.isEnabled()
				continue
			newModifiedVoxel.push v

			c = v.voxelCoords

			#check if there is at least one connection to an enabled voxel
			enabledVoxels = @grid.getNeighbours c.x,
				c.y, c.z, (voxel) ->
					return voxel.enabled

			connectedToEnabled = false
			if enabledVoxels.length > 0
				connectedToEnabled = true

			# has this voxel a not selected voxel below
			# (preventing unselectable voxels)
			# could be optimized by not using the (z-)-layer as "below",
			# but the layer the camera is currently facing towards
			freeBelow = true
			if @grid.zLayers[c.z - 1]?[c.x]?[c.y]?
				if  @grid.zLayers[c.z - 1][c.x][c.y].enabled == false
					freeBelow = false

			if freeBelow and connectedToEnabled
				v.setMaterial @defaultColoring.hiddenMaterial
				v.visible = true

		@modifiedVoxels = newModifiedVoxel

	getVoxel: (event) =>
		# returns the first voxel below the mouse cursor
		intersects =
			interactionHelper.getPolygonClickedOn(
				event
				@voxelsSubnode.children
				@bundle.renderer)

		if (intersects.length > 0)
			for intersection in intersects
				obj = intersection.object.parent
			
				if obj.visible and obj.voxelCoords
					return obj

		return null






