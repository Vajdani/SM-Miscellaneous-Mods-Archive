
ChallengePlayer = class( nil )

function ChallengePlayer.server_onCreate( self )
	self.sv = {}
	self:sv_init()
end

function ChallengePlayer.server_onRefresh( self )
	self:sv_init()
end

function ChallengePlayer.sv_init( self ) end

function ChallengePlayer.server_onDestroy( self ) end

function ChallengePlayer.client_onCreate( self )
	self.cl = {}
	self:cl_init()
	--Slide start
    self.slideDirCount = 1
    self.slideDir = nil
    self.slideForce = sm.vec3.new( 300 , 300, 0 )
	self.canSlide = true
end

function ChallengePlayer:client_onFixedUpdate( dt )
	if sm.localPlayer.getPlayer():getCharacter() ~= nil then
		self.playerChar = sm.localPlayer.getPlayer():getCharacter()
		if sm.localPlayer.getPlayer():getCharacter() ~= nil then
			self.playerChar = sm.localPlayer.getPlayer():getCharacter()
			self.playerPos = self.playerChar:getWorldPosition()
			self.playerVel = self.playerChar:getVelocity()
		end
		
		if self.playerChar:isCrouching() and self.playerChar:isOnGround() and self.slideForce.x > 0 and self.slideForce.y > 0 then
			self.slideCheck = sm.vec3.new( self.playerVel.x, self.playerVel.y, 0 )
		
			if (math.abs(self.slideCheck.x) > 1 or math.abs(self.slideCheck.y) > 1) and self.canSlide then
				if self.slideDirCount > 0 then
					self.slideDir = self.slideCheck
					--sm.vec3.new(sm.localPlayer.getDirection().x, sm.localPlayer.getDirection().y, 0)
					self.slideDirCount = self.slideDirCount - 1
					self.network:sendToServer("sv_adjustMoveSpeed", { plych = self.playerChar, speed = 0.25 })
				end

				self.network:sendToServer("sv_applySlideForce", { plych = self.playerChar, force = self.slideForce * self.slideDir:normalize() })
				
				if sm.physics.raycast( self.playerPos, self.playerPos + (self.slideDir * sm.vec3.new(1, 1, 0))) then
					self.slideForce = sm.vec3.zero()
				else
					self.slideForce = sm.vec3.new((self.slideForce.x - dt*100), (self.slideForce.y - dt*100), 10)
				end
			else
				self.canSlide = false
			end
			
		elseif not self.playerChar:isCrouching() then
			self.slideDirCount = 1
			self.slideDir = nil
			self.slideForce = sm.vec3.new( 300, 300, 0 )
			self.canSlide = true
			
			self.network:sendToServer("sv_adjustMoveSpeed", { plych = self.playerChar, speed = 1 })
		end
	end
end

function ChallengePlayer:sv_applySlideForce( args )
    sm.physics.applyImpulse( args.plych, args.force )
end

function ChallengePlayer:sv_adjustMoveSpeed( args )
	args.plych:setMovementSpeedFraction( args.speed )
end
--Slide end

function ChallengePlayer.client_onRefresh( self )
	self:cl_init()
end

function ChallengePlayer.cl_init(self) end

function ChallengePlayer.client_onUpdate( self, dt ) end

function ChallengePlayer.client_onInteract( self, character, state ) end

function ChallengePlayer.server_onFixedUpdate( self, dt ) end

function ChallengePlayer.server_onProjectile( self, hitPos, hitTime, hitVelocity, projectileName, attacker, damage ) end

function ChallengePlayer.server_onMelee( self, hitPos, attacker, damage, power ) end

function ChallengePlayer.server_onExplosion( self, center, destructionLevel ) end

function ChallengePlayer.server_onCollision( self, other, collisionPosition, selfPointVelocity, otherPointVelocity, collisionNormal  ) end

function ChallengePlayer.sv_e_staminaSpend( self, stamina ) end

function ChallengePlayer.sv_e_receiveDamage( self, damageData ) end

function ChallengePlayer.sv_e_respawn( self ) end

function ChallengePlayer.sv_e_debug( self, params ) end

function ChallengePlayer.sv_e_eat( self, edibleParams ) end

function ChallengePlayer.sv_e_feed( self, params ) end

function ChallengePlayer.sv_e_setRefiningState( self, params ) end

function ChallengePlayer.sv_e_onLoot( self, params ) end

function ChallengePlayer.sv_e_onStayPesticide( self ) end

function ChallengePlayer.sv_e_onEnterFire( self ) end

function ChallengePlayer.sv_e_onStayFire( self ) end

function ChallengePlayer.sv_e_onEnterChemical( self ) end

function ChallengePlayer.sv_e_onStayChemical( self ) end

function ChallengePlayer.sv_e_startLocalCutscene( self, cutsceneInfoName ) end

function ChallengePlayer.client_onCancel( self ) end

function ChallengePlayer.client_onReload( self ) end

function ChallengePlayer.server_onShapeRemoved( self, removedShapes ) end