class Voxel
	constructor: (@position, dataEntrys = []) ->
		@dataEntrys = dataEntrys
		@brick = false
		@enabled = true
		@definitelyUp = false
		@definitelyDown = false
		@neighbors = {
			Zp: null
			Zm: null
			Xp: null
			Xm: null
			Yp: null
			Ym: null
		}

	isLego: =>
		return @enabled

	makeLego: =>
		@enabled = true

	make3dPrinted: =>
		@enabled = false

	@sizeFromVoxels: (voxels) =>
		size = {}
		voxels.forEach (voxel) =>
			#init values
			size.maxX ?= size.minX ?= voxel.position.x
			size.maxY ?= size.minY ?= voxel.position.y
			size.maxZ ?= size.minZ ?= voxel.position.z

			size.minX = voxel.position.x if size.minX > voxel.position.x
			size.minY = voxel.position.y if size.minY > voxel.position.y
			size.minZ = voxel.position.z if size.minZ > voxel.position.z

			size.maxX = voxel.position.x if size.maxX < voxel.position.x
			size.maxY = voxel.position.y if size.maxY < voxel.position.y
			size.maxZ = voxel.position.z if size.maxZ < voxel.position.z

		size = {
			x: (size.maxX - size.minX) + 1
			y: (size.maxY - size.minY) + 1
			z: (size.maxZ - size.minZ) + 1
		}

		return size


module.exports = Voxel
