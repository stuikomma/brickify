log = require 'loglevel'

Brick = require '../Brick'
Voxel = require '../Voxel'
Random = require '../Random'
Layouter = require './Layouter'


###
# @class PlateLayouter
###

class PlateLayouter extends Layouter
	constructor: (pseudoRandom = false) ->
		Random.usePseudoRandom pseudoRandom

	_isBrickLayouter: ->
		return false

	_isPlateLayouter: ->
		return true

	# Searches for mergeable neighbors in [x-, x+, y-, y+] direction
	# and returns an array out of arrays of IDs for each direction
	_findMergeableNeighbors: (brick) =>
		if brick.getSize().z is 3
			return [null, null, null, null]

		mergeableNeighbors = []

		mergeableNeighbors.push @_findMergeableNeighborsInDirection(
			brick
			Brick.direction.Yp
			(obj) -> return obj.x
			(obj) -> return obj.y
		)
		mergeableNeighbors.push @_findMergeableNeighborsInDirection(
			brick
			Brick.direction.Ym
			(obj) -> return obj.x
			(obj) -> return obj.y
		)
		mergeableNeighbors.push @_findMergeableNeighborsInDirection(
			brick
			Brick.direction.Xm
			(obj) -> return obj.y
			(obj) -> return obj.x
		)
		mergeableNeighbors.push @_findMergeableNeighborsInDirection(
			brick
			Brick.direction.Xp
			(obj) -> return obj.y
			(obj) -> return obj.x
		)

		return mergeableNeighbors

	###
	# Checks if brick can merge in the direction specified.
	#
	# @param {Brick} brick the brick whose neighbors to check
	# @param {Number} dir the merge direction as specified in Brick.direction
	# @param {Function} widthFn the function to determine the brick's width
	# @param {Function} lengthFn the function to determine the brick's length
	# @return {Array<Brick>} Bricks in the merge direction if this brick can merge
	# in this dir undefined otherwise.
	# @see Brick
	###
	_findMergeableNeighborsInDirection: (brick, dir, widthFn, lengthFn) ->
		neighbors = brick.getNeighbors(dir)
		return null if neighbors.size is 0

		# Check all requirements for mergeability except validSize
		checkResult = @_checkNeighbors brick, neighbors, widthFn, lengthFn
		return null if checkResult is false

		if Brick.isValidSize(widthFn(brick.getSize()), lengthFn(brick.getSize()) +
				checkResult.length, brick.getSize().z)
			return neighbors

		log.debug 'mergeable but invalid size'

		# If the neighbors are mergeable except for unvalid brick dimensions
		# test the neighbors' neighbors
		firstNeighborsLength = checkResult.length

		neighborsNeighbors = new Set()
		neighbors.forEach (neighbor) ->
			neighbor.getNeighbors(dir).forEach (neighborsNeighbor)
				neighborsNeighbors.add neighborsNeighbor

		# Check the neighbors of the neighbors
		checkResult = @_checkNeighbors brick, neighborsNeighbors, widthFn, lengthFn
		return null if checkResult is false

		if Brick.isValidSize(widthFn(brick.getSize()), lengthFn(brick.getSize()) +
				firstNeighborsLength + checkResult.length, brick.getSize().z)
			log.debug 'merging neighborsNeighbors'
			return DataHelper.union(neighbors, neighborsNeighbors)

		return null

	# Checks all requirements for mergeability except validSize
	_checkNeighbors: (brick, neighbors, widthFn, lengthFn) =>
		# Get the bricks minimal and maximal Position in its width dimension
		minWPos = widthFn(brick.getPosition())
		maxWPos = minWPos + widthFn(brick.getSize()) - 1

		totalNeighborWidth = 0
		individualNeighborLength = null

		neighborIter = neighbors.values()
		while neighbor = neighborIter.next().value
			neighborSize = neighbor.getSize()
			neighborPos = neighbor.getPosition()
			# checks for z dimension
			return false unless neighborSize.z is brick.getSize().z
			return false unless neighborPos.z is brick.getPosition().z
			# checks for position (width dimension)
			# i.e. there cannot be spacing between the neighbors
			return false if widthFn(neighborPos) < minWPos
			neighborMaxWPos = widthFn(neighborPos) + widthFn(neighborSize) - 1
			return false if neighborMaxWPos > maxWPos
			# check if all neighbors have same length
			individualNeighborLength ?= lengthFn(neighborSize)
			return false unless lengthFn(neighborSize) is individualNeighborLength
			# add
			totalNeighborWidth += widthFn(neighborSize)

		# Check that the neighbors combined match this brick's width
		return false unless totalNeighborWidth is widthFn(brick.getSize())

		return {
			mergeable: true,
			length: individualNeighborLength
		}


	# Returns the index of the mergeableNeighbors sub-set-in-this-array,
	# where the bricks have the most connected neighbors.
	# If multiple sub-sets have the same number of connected neighbors,
	# one is randomly chosen
	_chooseNeighborsToMergeWith: (mergeableNeighbors) ->
		numConnections = []
		maxConnections = 0

		for neighborSet, i in mergeableNeighbors
			continue if not neighborSet?

			connectedBricks = new Set()

			neighborSet.forEach (neighbor) ->
				neighborConnections = neighbor.connectedBricks()
				neighborConnections.forEach (brick) ->
					connectedBricks.add brick

			numConnections.push {
				num: connectedBricks.size
				index: i
			}

			maxConnections = Math.max maxConnections, connectedBricks.size

		largestConnections = numConnections.filter (element) ->
			return element.num is maxConnections

		randomOfLargest = largestConnections[Random.next(largestConnections.length)]
		return randomOfLargest.index

	finalLayoutPass: (grid) =>
		bricksToLayout = grid.getAllBricks()
		finalPassMerges = 0
		bricksToLayout.forEach (brick) =>
			return unless brick?
			merged = @_mergeLoop brick, bricksToLayout
			if merged
				finalPassMerges++

		log.debug '\tFinal pass merged ', finalPassMerges, ' times.'
		return Promise.resolve {grid: grid}

module.exports = PlateLayouter
