###
  #Lego Board Plugin#

  Creates a lego board as a workspace surface to help people align models
  to the lego grid
###

THREE = require 'three'
threeConverter = require '../../client/threeConverter'
modelCache = require '../../client/modelLoading/modelCache'
globalConfig = require '../../common/globals.yaml'
RenderTargetHelper = require '../../client/rendering/renderTargetHelper'
stencilBits = require '../../client/rendering/stencilBits'

module.exports = class LegoBoard
	# Store the global configuration for later use by init3d
	init: (@bundle) ->
		@globalConfig = @bundle.globalConfig
		return

	# Load the board
	init3d: (@threejsNode) =>
		@highQualMode = false
		@usePipeline = false
		@isVisible = true
		@isScreenshotMode = no

		@_initMaterials()

		# Create baseplate with 5 faces in each direction
		box = new THREE.BoxGeometry(400, 400, 8, 5, 5)
		@baseplateBox = new THREE.Mesh(box, @baseplateMaterial)
		@baseplateBox.translateZ -4
		@threejsNode.add @baseplateBox

		# Create studs
		@studsContainer = new THREE.Object3D()
		@threejsNode.add @studsContainer
		@studsContainer.visible = false

		modelCache
		.request('1336affaf837a831f6b580ec75c3b73a')
		.then (model) ->
			return model.getObject()
		.then (modelObject) =>
			geo = threeConverter.toStandardGeometry modelObject
			for x in [-160..160] by 80
				for y in [-160..160] by 80
					object = new THREE.Mesh(geo, @studMaterial)
					object.translateX x
					object.translateY y
					@studsContainer.add object

		# Create scene for pipeline
		@pipelineScene = @bundle.renderer.getDefaultScene()

	_initMaterials: =>
		studTexture = THREE.ImageUtils.loadTexture('img/baseplateStud.png')
		studTexture.wrapS = THREE.RepeatWrapping
		studTexture.wrapT = THREE.RepeatWrapping
		studTexture.repeat.set 50, 50

		@baseplateMaterial = new THREE.MeshLambertMaterial(
			color: globalConfig.colors.basePlate
		)
		@baseplateTexturedMaterial = new THREE.MeshLambertMaterial(
			map: studTexture
		)
		@currentBaseplateMaterial = @baseplateTexturedMaterial

		@baseplateTransparentMaterial = new THREE.MeshLambertMaterial(
				color: globalConfig.colors.basePlate
				opacity: 0.4
				transparent: true
		)

		@studMaterial = new THREE.MeshLambertMaterial(
				color: globalConfig.colors.basePlateStud
		)

	on3dUpdate: =>
		# This check is only important if we don't use the pipeline
		return if @usePipeline or @isScreenshotMode

		# Check if the camera is below z=0. if yes, make the plate transparent
		# and hide studs
		if not @bundle?
			return

		camera = @bundle.renderer.camera

		if camera.position.z < 0
			@baseplateBox.material = @baseplateTransparentMaterial
			@studsContainer.visible = false
		else
			@baseplateBox.material = @currentBaseplateMaterial
			@studsContainer.visible = true if @highQualMode

	onPaint: (threeRenderer, camera, target) =>
		return if not @isVisible or @isScreenshotMode

		# Recreate textures if either they havent been generated yet or
		# the screen size has changed
		if not (@renderTargetsInitialized? and
		RenderTargetHelper.renderTargetHasRightSize(
			@pipelineSceneTarget.renderTarget, threeRenderer
		))
			if @pipelineSceneTarget?
				RenderTargetHelper.deleteRenderTarget @pipelineSceneTarget, threeRenderer

			@pipelineSceneTarget = RenderTargetHelper.createRenderTarget(
				threeRenderer, null, null, 1.0
			)
			@renderTargetsInitialized = true

		# Render board
		threeRenderer.render(
			@pipelineScene, camera, @pipelineSceneTarget.renderTarget, true
		)

		gl = threeRenderer.context

		# Render baseplate transparent if cam looks from below
		if camera.position.z < 0
			# One fully transparent render pass
			@pipelineSceneTarget.blendingMaterial.uniforms.opacity.value = 0.4
			threeRenderer.render @pipelineSceneTarget.quadScene, camera, target, false
		else
			# One default opaque pass
			@pipelineSceneTarget.blendingMaterial.uniforms.opacity.value = 1
			threeRenderer.render @pipelineSceneTarget.quadScene, camera, target, false

			# Render one pass transparent, where visible object or shadow is
			# (= no lego)
			gl.enable(gl.STENCIL_TEST)
			gl.stencilFunc(gl.EQUAL, 0x00, stencilBits.legoMask)
			gl.stencilOp(gl.KEEP, gl.KEEP, gl.KEEP)
			gl.stencilMask(0x00)

			@pipelineSceneTarget.blendingMaterial.uniforms.opacity.value = 0.4

			gl.disable(gl.DEPTH_TEST)
			threeRenderer.render @pipelineSceneTarget.quadScene, camera, target, false
			gl.enable(gl.DEPTH_TEST)

			gl.disable(gl.STENCIL_TEST)

	toggleVisibility: =>
		@threejsNode.visible = !@threejsNode.visible
		@isVisible = !@isVisible

	setFidelity: (fidelityLevel, availableLevels, options) =>
		if options.screenshotMode?
			@isScreenshotMode = options.screenshotMode
			@threejsNode.visible = @isVisible and not @isScreenshotMode

		# Determine whether to show or hide studs
		if fidelityLevel > availableLevels.indexOf 'DefaultMedium'
			@highQualMode = true

			# Show studs
			@studsContainer.visible = true
			# Remove texture because we have physical studs
			@baseplateBox.material = @baseplateMaterial

			@currentBaseplateMaterial = @baseplateMaterial
		else
			@highQualMode = false

			# Hide studs
			@studsContainer.visible = false
			# Change baseplate material to stud texture
			@baseplateBox.material = @baseplateTexturedMaterial

			@currentBaseplateMaterial = @baseplateTexturedMaterial

		# Determine whether to use the pipeline or not
		if fidelityLevel >= availableLevels.indexOf 'PipelineLow'
			if not @usePipeline
				@usePipeline = true

				# Move lego board and studs from threeNode to pipeline scene
				@threejsNode.remove @baseplateBox
				@threejsNode.remove @studsContainer

				@pipelineScene.add @baseplateBox
				@pipelineScene.add @studsContainer
		else
			if @usePipeline
				@usePipeline = false

				# Move lego board and studs from pipeline to threeNode
				@pipelineScene.remove @baseplateBox
				@pipelineScene.remove @studsContainer

				@threejsNode.add @baseplateBox
				@threejsNode.add @studsContainer
