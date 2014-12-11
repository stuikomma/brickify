###
# @module renderer
###

THREE = require 'three'
OrbitControls = require('three-orbit-controls')(THREE)
Stats = require 'stats-js'

module.exports = class Renderer
	constructor: (@pluginHooks) ->
		@scene = null
		@camera = null
		@threeRenderer = null

	localRenderer: (timestamp) =>
			@stats?.begin()
			@threeRenderer.render @.scene, @.camera
			@pluginHooks.on3dUpdate timestamp
			@stats?.end()
			requestAnimationFrame @localRenderer

	addToScene: (node) ->
		@scene.add node

	getDomElement: () ->
		return @threeRenderer.domElement

	windowResizeHandler: () ->
		if not @staticRendererSize
			@camera.aspect = @size().width / @size().height
			@camera.updateProjectionMatrix()
			@threeRenderer.setSize @size().width, @size().height

		@threeRenderer.render @scene, @camera

	init: (globalConfig) ->
		@setupSize globalConfig
		@setupRenderer globalConfig
		@setupScene globalConfig
		@setupLighting globalConfig
		@setupCamera globalConfig
		@setupControls globalConfig
		@setupFPSCounter() if process.env.NODE_ENV is 'development'
		requestAnimationFrame @localRenderer

	setupSize: (globalConfig) ->
		if not globalConfig.staticRendererSize
			@staticRendererSize = false
		else
			@staticRendererSize = true
			@staticRendererWidth = globalConfig.staticRendererWidth
			@staticRendererHeight = globalConfig.staticRendererHeight

	size: ->
		if @staticRendererSize
			return {width: @staticRendererWidth, height: @staticRendererHeight}
		else
			return {width: window.innerWidth, height: window.innerHeight}

	setupRenderer: (globalConfig) ->
		@threeRenderer = new THREE.WebGLRenderer(
			alpha: true
			antialias: true
			preserveDrawingBuffer: true
		)

		@threeRenderer.setSize @size().width, @size().height
		@threeRenderer.setClearColor 0xf6f6f6, 1
		@threeRenderer.domElement.setAttribute 'id', 'canvas'
		document
		.getElementById(globalConfig.renderAreaId)
		.appendChild @threeRenderer.domElement

	setupScene: (globalConfig) ->
		@scene = new THREE.Scene()
		# Scene rotation because orbit controls only works
		# with up vector of 0, 1, 0
		sceneRotation = new THREE.Matrix4()
		sceneRotation.makeRotationAxis(
			new THREE.Vector3( 1, 0, 0 ),
			(-Math.PI / 2)
		)
		@scene.applyMatrix(sceneRotation)
		@scene.fog = new THREE.Fog(
			0xffffff
			globalConfig.cameraNearPlane
			globalConfig.cameraFarPlane
		)

	setupCamera: (globalConfig) ->
		@camera = new THREE.PerspectiveCamera(
			globalConfig.fov,
			(@size().width / @size().height),
			globalConfig.cameraNearPlane,
			globalConfig.cameraFarPlane
		)
		@camera.position.set(
			globalConfig.axisLength
			globalConfig.axisLength + 10
			globalConfig.axisLength / 2
		)
		@camera.up.set(0, 1, 0)
		@camera.lookAt(new THREE.Vector3(0, 0, 0))

	setupControls: (globalConfig) ->
		@controls = new OrbitControls(@camera, @threeRenderer.domElement)
		@controls.target.set(0, 0, 0)

	setupFPSCounter: () ->
		@stats = new Stats()
		# 0 means FPS, 1 means ms per frame
		@stats.setMode(0)
		@stats.domElement.style.position = 'absolute'
		@stats.domElement.style.right = '0px'
		@stats.domElement.style.bottom = '0px'
		document.body.appendChild(@stats.domElement)

	setupLighting: (globalConfig) ->
		ambientLight = new THREE.AmbientLight(0x404040)
		@scene.add ambientLight

		directionalLight = new THREE.DirectionalLight(0xffffff)
		directionalLight.position.set 0, 20, 30
		@scene.add directionalLight

		directionalLight = new THREE.DirectionalLight(0x808080)
		directionalLight.position.set 20, 0, 30
		@scene.add directionalLight
