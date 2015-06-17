log = require 'loglevel'

Brick = require './Brick'
arrayHelper = require './arrayHelper'
Random = require './Random'

###
# @class BrickLayouter
###

class BrickLayouter
	constructor: (@pseudoRandom = false, @debugMode = false) ->
		Random.usePseudoRandom @pseudoRandom

	initializeBrickGraph: (grid) ->
		grid.initializeBricks()
		return Promise.resolve grid

	# main while loop condition:
	# any brick can still merge --> use heuristic:
	# keep a counter, break if last number of unsuccessful tries > (some number
	# or some % of total bricks in object)
	# !! Expects bricks to layout to be a Set !!
	layoutByGreedyMerge: (grid, bricksToLayout) =>
		numRandomChoices = 0
		numRandomChoicesWithoutMerge = 0
		numTotalInitialBricks = 0

		if not bricksToLayout?
			bricksToLayout = grid.getAllBricks()
			bricksToLayout.chooseRandomBrick = grid.chooseRandomBrick

		numTotalInitialBricks += bricksToLayout.size
		maxNumRandomChoicesWithoutMerge = numTotalInitialBricks

		return Promise.resolve {grid: grid} unless numTotalInitialBricks > 0

		loop
			brick = @_chooseRandomBrick bricksToLayout
			if !brick?
				return Promise.resolve {grid: grid}

			numRandomChoices++
			mergeableNeighbors = @_findMergeableNeighbors brick

			if !@_anyDefinedInArray(mergeableNeighbors)
				numRandomChoicesWithoutMerge++
				if numRandomChoicesWithoutMerge >= maxNumRandomChoicesWithoutMerge
					log.debug " - randomChoices #{numRandomChoices}
											withoutMerge #{numRandomChoicesWithoutMerge}"
					break # done with initial layout
				else
					continue # randomly choose a new brick

			@_mergeLoop brick, mergeableNeighbors, bricksToLayout

		return Promise.resolve {grid: grid}


	finalLayoutPass: (grid) =>
		bricksToLayout = grid.getAllBricks()
		finalPassMerges = 0
		bricksToLayout.forEach (brick) =>
			return unless brick?
			mergeableNeighbors = @_findMergeableNeighbors brick
			if @_anyDefinedInArray(mergeableNeighbors)
				finalPassMerges++
				@_mergeLoop brick, mergeableNeighbors, bricksToLayout

		log.debug 'Final pass merged ', finalPassMerges, ' times.'
		return Promise.resolve {grid: grid}

	_mergeLoop: (brick, mergeableNeighbors, bricksToLayout) =>
		while(@_anyDefinedInArray(mergeableNeighbors))
			mergeIndex = @_chooseNeighborsToMergeWith mergeableNeighbors
			neighborsToMergeWith = mergeableNeighbors[mergeIndex]

			@_mergeBricksAndUpdateGraphConnections brick,
				neighborsToMergeWith, bricksToLayout

			if @debugMode and not brick.isValid()
				log.warn 'Invalid brick: ', brick
				log.warn '> Using pseudoRandom:', @pseudoRandom
				log.warn '> current seed:', Random.getSeed()

			mergeableNeighbors = @_findMergeableNeighbors brick

		return brick

	###
	# Split up all supplied bricks into single bricks and relayout locally. This
	# means that all supplied bricks and their neighbors will be relayouted.
	#
	# @param {Set<Brick>} bricks bricks that should be split
	###
	splitBricksAndRelayoutLocally: (bricks, grid, splitNeighbors = true) =>
		bricksToSplit = new Set()

		bricks.forEach (brick) ->
			# add this brick to be split
			bricksToSplit.add brick

			if splitNeighbors
				# get neighbors in same z layer
				neighbors = brick.getNeighborsXY()
				# add them all to be split as well
				neighbors.forEach (nBrick) -> bricksToSplit.add nBrick

		newBricks = @_splitBricks bricksToSplit

		bricksToBeDeleted = new Set()

		newBricks.forEach (brick) ->
			brick.forEachVoxel (voxel) ->
				# delete bricks where voxels are disabled (3d printed)
				if not voxel.enabled
					# remove from relayout list
					bricksToBeDeleted.add brick
					# delete brick from structure
					brick.clear()

		bricksToBeDeleted.forEach (brick) ->
			newBricks.delete brick

		@layoutByGreedyMerge grid, newBricks
		.then ->
			return {
				removedBricks: bricksToSplit
				newBricks: newBricks
			}

	# splits each brick in bricks to split, returns all newly generated
	# bricks as a set
	_splitBricks: (bricksToSplit) ->
		newBricks = new Set()

		bricksToSplit.forEach (brick) ->
			splitGenerated = brick.splitUp()
			splitGenerated.forEach (brick) ->
				newBricks.add brick

		return newBricks

	_anyDefinedInArray: (mergeableNeighbors) ->
		return mergeableNeighbors.some (entry) -> entry?

	# chooses a random brick out of the set
	_chooseRandomBrick: (setOfBricks) ->
		if setOfBricks.size == 0
			return null

		if setOfBricks.chooseRandomBrick?
			return setOfBricks.chooseRandomBrick()

		rnd = Random.next(setOfBricks.size)

		iterator = setOfBricks.entries()
		brick = iterator.next().value[0]
		while rnd > 0
			brick = iterator.next().value[0]
			rnd--

		return brick

	# Searches for mergeable neighbours in [x-, x+, y-, y+] direction
	# and returns an array out of arrays of IDs for each direction
	_findMergeableNeighbors: (brick) =>
		mergeableNeighbors = []

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
		mergeableNeighbors.push @_findMergeableNeighborsInDirection(
			brick
			Brick.direction.Ym
			(obj) -> return obj.x
			(obj) -> return obj.y
		)
		mergeableNeighbors.push @_findMergeableNeighborsInDirection(
			brick
			Brick.direction.Yp
			(obj) -> return obj.x
			(obj) -> return obj.y
		)

		return mergeableNeighbors

	###
	# Checks if brick can merge in the direction specified.
	#
	# @param {Brick} brick the brick whose neighbors to check
	# @param {Number} dir the merge direction as specified in Brick.direction
	# @param {Function} widthFn the function to determine the brick's width
	# @param {Function} lengthFn the function to determine the brick's height
	# @return {Array<Brick>} Bricks in the merge direction if this brick can merge
	# in this dir undefined otherwise.
	# @see Brick
	###
	_findMergeableNeighborsInDirection: (brick, dir, widthFn, lengthFn) ->
		neighborsInDirection = brick.getNeighbors(dir)
		if neighborsInDirection.size > 0
			# check that the neighbors together don't exceed this brick's width
			width = 0
			neighborsInDirection.forEach (neighbor) ->
				width += widthFn neighbor.getSize()

			# if they have the same width, check ...?
			if width == widthFn(brick.getSize())
				minWidth = widthFn brick.getPosition()

				maxWidth = widthFn(brick.getPosition())
				maxWidth += widthFn(brick.getSize()) - 1

				length = null

				invalidSize = false
				neighborsInDirection.forEach (neighbor) ->
					length ?= lengthFn neighbor.getSize()

					if widthFn(neighbor.getPosition()) < minWidth
						invalidSize = true

					nw = widthFn(neighbor.getPosition()) + widthFn(neighbor.getSize()) - 1
					if nw > maxWidth
						invalidSize = true

					if lengthFn(neighbor.getSize()) != length
						invalidSize = true

				if invalidSize
					return null

				if Brick.isValidSize(widthFn(brick.getSize()), lengthFn(brick.getSize()) +
				length, brick.getSize().z)
					return neighborsInDirection
				else
					return null

	# Returns the index of the mergeableNeighbors sub-set-in-this-array,
	# where the bricks have the most connected neighbors.
	# If multiple sub-arrays have the same number of connected neighbors,
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
			return element.num == maxConnections

		randomOfLargest = largestConnections[Random.next(largestConnections.length)]
		return randomOfLargest.index

	_mergeBricksAndUpdateGraphConnections: (
		brick, mergeNeighbors, bricksToLayout ) ->

		mergeNeighbors.forEach (neighborToMergeWith) ->
			bricksToLayout.delete neighborToMergeWith
			brick.mergeWith neighborToMergeWith

		return brick


	optimizeLayoutStability: (grid) =>
		passes = 0

		bricks = grid.getAllBricks()
		log.debug '\t# of bricks: ', bricks.size

		components = @findConnectedComponents bricks
		minComponents = components.length
		log.debug '\t# of components: ', components.length

		bricksToSplit = @findBricksToSplit components, bricks
		log.debug '\t# of bricks to split: ', bricksToSplit.size

		@splitBricksAndRelayoutLocally bricksToSplit, grid, false

		loop
			passes++

			bricks = grid.getAllBricks()
			bricks.forEach (brick) ->
				brick.component = null

			components = @findConnectedComponents bricks
			if components.length < minComponents
				minComponents = components.length
			log.debug '\t# of components: ', components.length

			bricksToSplit = @findBricksToSplit components, bricks
			log.debug '\t# of bricks to split: ', bricksToSplit.size

			if components.length <= minComponents and bricksToSplit.size == 0
				break
			else if passes == 100
				break
			else #if components.length > minComponents
				@splitBricksAndRelayoutLocally bricksToSplit, grid, false

		log.debug '\tfinished optimization after ', passes , 'passes'
		return Promise.resolve grid

	findConnectedComponents: (bricks) =>
		id = 0
		components = []

		bricks.forEach (brick) =>
			return if brick.component != null
			components[id] = new Set()

			queue = new Set([brick])
			while queue.size != 0
				currentBrick = queue.values().next().value
				# process current brick
				currentBrick.component = id
				components[id].add currentBrick
				queue.delete currentBrick
				# add all connected Bricks to the
				conBricks = currentBrick.connectedBricks()
				conBricks.forEach (conBrick) ->
					queue.add conBrick if conBrick.component == null

			id++

		return components

	findBricksToSplit: (components, bricks) =>
		bricksToSplit = new Set()

		bricks.forEach (brick) ->
			neighborsXY = brick.getNeighborsXY()
			neighborsXY.forEach (neighbor) ->
				if neighbor.component != brick.component
					bricksToSplit.add neighbor
					bricksToSplit.add brick

		return bricksToSplit





module.exports = BrickLayouter
