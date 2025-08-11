dofile( "$SURVIVAL_DATA/Scripts/util.lua" )

Kinematic = class( nil )

local TimeStep = 0.025

function Kinematic.server_onCreate( self )
	self.sv = {}

	self.sv.trackDataList, self.sv.trackSettings = self:evaluateNodes( self.params.track )
	self.sv.updateData = {}
	self.sv.updateData.trackIndex = 1
	self.sv.updateData.playForward = true
	self.sv.updateData.moving = false

	self.sv.progressData = { segmentIndex = 1, segmentProgress = 0.0 }
	self.network:setClientData( { track = self.params.track }, 1 )
	self.network:setClientData( self.sv.updateData, 2 )
end

function Kinematic.server_onFixedUpdate( self, timeStep )
	if self.sv == nil then
		return
	end

	local wasMoving = self.sv.updateData.moving
	if self.sv.updateData.moving then

		local previousProgressData = {}
		previousProgressData.segmentIndex = self.sv.progressData.segmentIndex
		previousProgressData.segmentProgress = self.sv.progressData.segmentProgress

		self.sv.updateData, self.sv.progressData = self:trackUpdate( self.sv.trackDataList, self.sv.trackSettings, self.sv.updateData )

		-- Trigger events when traversing nodes
		if self.sv.updateData.moving then
			if self.sv.progressData.segmentIndex ~= previousProgressData.segmentIndex then
				-- Moved to a new node
				local nodeIndex = self.sv.progressData.segmentIndex
				if not self.sv.updateData.playForward then
					nodeIndex = nodeIndex + 1
				end
			end
		else
			-- Stopped at a new node in the next track
			local nodeIndex = self.sv.progressData.segmentIndex
			if not self.sv.updateData.playForward then
				nodeIndex = nodeIndex + 1
			end
		end
	end

	if not self.sv.updateData.moving then
		-- Start moving if not commanded to wait
		local trackData = self.sv.trackDataList[self.sv.updateData.trackIndex]
		if trackData and trackData.nodes and #trackData.nodes >= 1 then
			local requiresInput = ( self.sv.updateData.playForward and trackData.nodes[1].stop ) or ( not self.sv.updateData.playForward and trackData.nodes[#trackData.nodes].stop )
			if not requiresInput and self.sv.trackSettings.loop then
				-- Check the previous node for stop events if looping around
				if self.sv.updateData.playForward then
					if self.sv.updateData.trackIndex == 1 then
						local lastTrackData = self.sv.trackDataList[#self.sv.trackDataList]
						local lastNodeStop = lastTrackData.nodes[#lastTrackData.nodes].stop
						requiresInput = lastNodeStop
					end
				else
					if self.sv.updateData.trackIndex == #self.sv.trackDataList then
						local firstTrackData = self.sv.trackDataList[1]
						local firstNodeStop = firstTrackData.nodes[1].stop
						requiresInput = firstNodeStop
					end
				end
			end
			if not requiresInput then
				self:sv_activate()
			end
		end
	end

	-- Synch stopped kinematic
	if wasMoving and not self.sv.updateData.moving then
		self.network:setClientData( self.sv.updateData, 2 )
	end
end

function Kinematic.sv_activate( self )
	if self.sv.trackDataList and not self.sv.updateData.moving then
		self.sv.updateData.moving = true
		self.sv.updateData.serverTick = sm.game.getServerTick()
		self.network:setClientData( self.sv.updateData, 2 )
	elseif not self.sv.trackDataList then
		print( "Kinematic has no track" )
	end
end

function Kinematic.client_onCreate( self )
	self.cl = {}
	self.cl.updateData = {}
	self.cl.updateData.trackIndex = 1
	self.cl.updateData.playForward = true
	self.cl.updateData.moving = false

	if self.data and self.data.attachedEffect then
		self.cl.attachedEffect = sm.effect.createEffect( self.data.attachedEffect, self.harvestable )
		if self.cl.attachedEffect then
			self.cl.attachedEffect:start()
		end
	end
end

function Kinematic.client_onDestroy( self )
	if self.cl.attachedEffect then
		self.cl.attachedEffect:destroy()
		self.cl.attachedEffect = nil
	end
end

function Kinematic.client_onClientDataUpdate( self, clientData, channel )
	if self.cl == nil then
		self.cl = {}
	end

	if channel == 1 then
		self.cl.trackDataList, self.cl.trackSettings = self:evaluateNodes( clientData.track )
	elseif channel == 2 then
		self.cl.updateData = clientData

		if not sm.isHost then
			-- Kinematic has stopped or started on the server
			-- Set client's transform to the first node's transform
			local trackData = self.cl.trackDataList[self.cl.updateData.trackIndex]
			local arrivalTime = trackData.durations[#trackData.durations]
			local time = self.cl.updateData.playForward and 0 or arrivalTime
			local transform, _ = self:getTransform( time, trackData )
			if transform then
				self.harvestable:setPosition( transform.worldPosition )
				self.harvestable:setRotation( transform.worldRotation )
			end
		end
	end
end

function Kinematic.client_onFixedUpdate( self, timeStep )
	if sm.isHost then
		return
	end

	if self.cl.updateData.moving then
		self.cl.updateData, _ = self:trackUpdate( self.cl.trackDataList, self.cl.trackSettings, self.cl.updateData )
	end
end

function Kinematic.evaluateNodes( self, trackParam )
	local trackSettings = {}
	if not trackParam then
		return nil, trackSettings
	end

	-- Translate track nodes into world space
	local worldTrackList = {}
	local trackIndex = 1
	local worldPosition = self.harvestable.initialPosition
	local worldRotation = self.harvestable.initialRotation
	local trackParamData = trackParam.track
	if trackParamData and trackParamData.track then
		worldTrackList[trackIndex] = {}
		for i, trackNode in ipairs( trackParamData.track ) do
			local trackPos = sm.vec3.new( trackNode.position[1], trackNode.position[2], trackNode.position[3] )
			local trackRotEuler = sm.vec3.new( trackNode.rotation[1], trackNode.rotation[2], trackNode.rotation[3] )
			local trackRotQuat = sm.quat.fromEuler( trackRotEuler )

			local worldTrackNode = {}
			worldTrackNode.position = worldPosition + worldRotation * ( trackPos * self.harvestable:getScale() )
			worldTrackNode.rotation = worldRotation * trackRotQuat
			if trackNode.durationFromSpeed then
				worldTrackNode.speed = trackNode.speed
			else
				worldTrackNode.duration = trackNode.duration
			end
			if trackNode.inheritDuration then
				-- Overwrite duration/speed with the values from the previous node if possible
				local previousNode = worldTrackList[trackIndex][#worldTrackList[trackIndex]]
				if previousNode then
					worldTrackNode.duration = worldTrackList[trackIndex][#worldTrackList[trackIndex]].duration
					worldTrackNode.speed = worldTrackList[trackIndex][#worldTrackList[trackIndex]].speed
				end
			end
			worldTrackNode.easing = trackNode.easing
			if trackNode.event and trackNode.event ~= "" then
				worldTrackNode.event = trackNode.event
			end
			worldTrackNode.delay = trackNode.delay

			local worldTangents = {}
			if trackNode.tangents then
				for _, tangent in ipairs( trackNode.tangents ) do
					local tangentPos = sm.vec3.new( tangent.position[1], tangent.position[2], tangent.position[3] )
					local tangentRotEuler = sm.vec3.new( tangent.rotation[1], tangent.rotation[2], tangent.rotation[3] )
					local tangentRotQuat = sm.quat.fromEuler( tangentRotEuler )

					local worldTangent = {}
					worldTangent.position = worldPosition + worldRotation * ( tangentPos * self.harvestable:getScale() )
					worldTangent.rotation = worldRotation * tangentRotQuat
					worldTangents[#worldTangents+1] = worldTangent
				end
			end
			worldTrackNode.tangents = worldTangents

			worldTrackList[trackIndex][#worldTrackList[trackIndex]+1] = worldTrackNode

			worldTrackNode.stop = trackNode.stop
			if trackNode.stop then
				trackIndex = trackIndex + 1
				worldTrackList[trackIndex] = {}
				worldTrackList[trackIndex][#worldTrackList[trackIndex]+1] = worldTrackNode
			end

		end
	end

	local trackDataList = {}
	for _, nodes in ipairs( worldTrackList ) do
		-- Extract segment information
		local distances = {}
		local durations = {}
		local easings = {}
		local segments = {}
		if nodes and #nodes > 1 then
			for i = 1, #nodes-1 do
				local points = {}
				local rotations = {}
				points[#points+1] = nodes[i].position
				rotations[#rotations+1] = nodes[i].rotation
				for _, tangent in ipairs( nodes[i].tangents ) do
					points[#points+1] = tangent.position
					rotations[#rotations+1] = tangent.rotation
				end
				points[#points+1] = nodes[i+1].position
				rotations[#rotations+1] = nodes[i+1].rotation

				segments[#segments+1] = { points = points, rotations = rotations }
			end

			-- Used for progress calculation
			distances[1] = 0
			for _, segment in ipairs( segments ) do
				local length = EstimateBezierLength( segment.points, 32 )
				distances[#distances+1] = distances[#distances] + length
			end

			durations[1] = 0
			for i = 1, #nodes - 1 do
				local delay = nodes[i].delay or 0.0
				if nodes[i].duration then
					durations[#durations+1] = durations[#durations] + nodes[i].duration + delay
				elseif nodes[i].speed then
					local distanceSegment = distances[i+1] - distances[i]
					local durationFromSpeed = distanceSegment / math.max( nodes[i].speed, FLT_EPSILON )
					durations[#durations+1] = durations[#durations] + durationFromSpeed + delay
				end
				easings[#easings+1] = nodes[i].easing
			end

			local finalDelay = nodes[#nodes].delay or 0.0
			durations[#durations] = durations[#durations] + finalDelay

			local trackData = {}
			trackData.nodes = nodes
			trackData.durations = durations
			trackData.easings = easings
			trackData.distances = distances
			trackData.segments = segments

			trackDataList[#trackDataList+1] = trackData
		end
	end

	if trackParamData then
		trackSettings.loop = trackParamData.loop
	end

	return trackDataList, trackSettings
end

function Kinematic.changeDirection( self, trackDataList, trackIndex, playForward, moving, serverTick )
	if moving then
		-- Calculate a fake starting tick that matches the reversed movement
		local trackData = trackDataList[trackIndex]
		if trackData and trackData.durations and #trackData.durations >= 1 then
			local durations = trackData.durations
			local elapsedTicks = 0
			if serverTick then
				local estimatedServerTick = sm.game.getServerTick()
				elapsedTicks = math.max( estimatedServerTick - serverTick, 0 )
			end

			local arrivalTickTime = math.ceil( durations[#durations] / TimeStep )
			serverTick = serverTick - arrivalTickTime + elapsedTicks * 2
		end
	else
		-- Has arrived, switch back to the previous track
		if playForward then
			trackIndex = ( ( trackIndex - 2 ) % #trackDataList ) + 1
		else
			trackIndex = ( trackIndex % #trackDataList ) + 1
		end
	end

	playForward = not playForward

	return trackIndex, playForward, serverTick
end

function Kinematic.trackUpdate( self, trackDataList, trackSettings, updateData )

	local trackIndex = updateData.trackIndex
	local playForward = updateData.playForward
	local serverTick = updateData.serverTick
	local moving = updateData.moving
	local segmentProgressData = { segmentIndex = 1, segmentProgress = 0.0 }

	local elapsedTicks = 0
	if serverTick then
		local estimatedServerTick = sm.game.getServerTick()
		elapsedTicks = math.max( estimatedServerTick - serverTick, 0 )
	end
	local time = elapsedTicks * TimeStep

	local trackData = trackDataList[trackIndex]
	if trackData and trackData.segments and #trackData.segments >= 1 then

		-- Adjust time when moving backwards
		local arrivalTime = trackData.durations[#trackData.durations]
		if not playForward then
			time = arrivalTime - time
		end

		-- Check if arrived at the end of the current track
		if playForward and time >= arrivalTime then
			moving = false
			local nextTrackIndex = ( trackIndex % #trackDataList ) + 1

			if not trackSettings.loop and nextTrackIndex <= trackIndex then
				-- Change direction
				playForward = not playForward
			else
				-- Switching track, position at the start of the next track
				trackIndex = nextTrackIndex
				trackData = trackDataList[trackIndex]
				time = 0
			end
		elseif not playForward and time <= 0 then
			moving = false
			local nextTrackIndex = ( ( trackIndex - 2 ) % #trackDataList ) + 1

			if not trackSettings.loop and nextTrackIndex >= trackIndex then
				-- Change direction
				playForward = not playForward
			else
				-- Switching track, position at the start of the next track
				trackIndex = nextTrackIndex
				trackData = trackDataList[trackIndex]
				time = trackData.durations[#trackData.durations]
			end
		end

		-- Find placement on the current segment
		local transform
		transform, segmentProgressData = self:getTransform( time, trackData )
		if transform then
			self.harvestable:setPosition( transform.worldPosition )
			self.harvestable:setRotation( transform.worldRotation )
		end
	else
		-- No track found
		moving = false
	end
	updateData.trackIndex = trackIndex
	updateData.playForward = playForward
	updateData.serverTick = serverTick
	updateData.moving = moving
	return updateData, segmentProgressData
end

function Kinematic.getTransform( self, time, trackData )
	local transform
	local segmentProgressData
	local segmentIndex = BinarySearchInterval( trackData.durations, time )
	if segmentIndex then
		segmentIndex =  math.min( math.max( segmentIndex, 1 ), #trackData.segments )
		local fromTime = trackData.durations[segmentIndex]
		local toTime = trackData.durations[segmentIndex+1]
		local easing = trackData.easings[segmentIndex]

		local delay = trackData.nodes[segmentIndex].delay or 0
		local delayedTime = time - delay
		local delayedToTime = toTime - delay

		local finalDelay = trackData.nodes[#trackData.nodes].delay or 0
		if segmentIndex == #trackData.segments then
			delayedToTime = delayedToTime - finalDelay
		end

		local segmentProgress = ( delayedTime - fromTime ) / ( delayedToTime - fromTime )
		segmentProgress = finite( segmentProgress ) and segmentProgress or 1.0
		segmentProgress = math.min( math.max( segmentProgress, 0.0 ), 1.0 )
		segmentProgress = sm.util.easing( easing, segmentProgress )

		local kinematicPosition = BezierPosition( trackData.segments[segmentIndex].points, segmentProgress )
		local kinematicRotation = BezierRotation( trackData.segments[segmentIndex].rotations, segmentProgress )

		transform = { worldPosition = kinematicPosition, worldRotation = kinematicRotation }
		segmentProgressData = { segmentIndex = segmentIndex, segmentProgress = segmentProgress }
	end
	return transform, segmentProgressData
end