Jailroom = Jailroom or {}
Jailroom.Config = Jailroom.Config or {}

Jailroom.Config.jailroom_pos = Vector(-714.7, -3.7, 12224) -- spawn jailing player
Jailroom.Config.jailroom_model = 'models/player/skeleton.mdl' -- model for jailing player
Jailroom.Config.jailroom_maxspeed = 50 -- speed player in jail
Jailroom.Config.max_seconds = 172800 -- 48 hours

local META = FindMetaTable( 'Player' )
function META:IsJailroom()

	return self:GetNWBool( 'Jailroom' )

end

if SERVER then

	util.AddNetworkString( 'Jailroom_send_ply' )

	sql.Query( 'CREATE TABLE IF NOT EXISTS Jailroom( SteamID TEXT PRIMARY KEY, Time NUMBER, Date NUMBER, Reason TEXT, Judge TEXT )' )

	function Jailroom.JailPlayer( ePly, eAdmin, sReason, nSeconds )

		if not IsValid( ePly ) or not ePly:IsPlayer() then print( '[Jailroom] JailPlayer ERROR #01' ) return end

		local is_Jailroom = ePly:IsJailroom()
		if is_Jailroom then print( '[Jailroom] JailPlayer ERROR #02' ) return end

		if not sReason or not isstring( sReason ) then print( '[Jailroom] JailPlayer WARNING #01' ) sReason = 'Причина не указана' end
		if not nSeconds or not isnumber( nSeconds ) then print( '[Jailroom] JailPlayer WARNING #02' ) nSeconds = 60 end
		if ( nSeconds > Jailroom.Config.max_seconds ) then print( '[Jailroom] JailPlayer WARNING #03' ) nSeconds = Jailroom.Config.max_seconds end
		if ( nSeconds <= 0 ) then print( '[Jailroom] JailPlayer WARNING #04' ) nSeconds = 1 end
		nSeconds = math.floor( nSeconds )
		-- Action

		ePly:changeTeam( TEAM_JAILROOM, true ) -- DO NOT TOUCH
		ePly:SetNWBool( 'Jailroom', true )
		ePly:SetNWInt( 'JailroomTime', nSeconds )
		if ePly:InVehicle() then ply:ExitVehicle() end
		ePly:Spawn()
		ePly:StripWeapons()
		ePly:StripAmmo()
		local nick_admin = eAdmin and eAdmin:Nick() or 'CONSOLE'
		ePly:ChatPrint( 'Admin '..nick_admin..' jailed you for a reason: '..sReason )

		timer.Create( 'JailroomPlayer'..ePly:SteamID(), nSeconds, 1, function() Jailroom.RemoveJailPlayerOffline( ePly:SteamID() ) end )

		net.Start( 'Jailroom_send_ply' )
			net.WriteBool( true )
			net.WriteUInt( nSeconds, 16 )
		net.Send( ePly )

		local values = Format( '(%s, %i, %i, %s, %s)', sql.SQLStr( ePly:SteamID() ), nSeconds, os.time(), sql.SQLStr( sReason ), sql.SQLStr( nick_admin ) )
		print( values )
		sql.Query( 'INSERT INTO Jailroom( SteamID, Time, Date, Reason, Judge ) VALUES '..values )

		if eAdmin then eAdmin:ChatPrint( 'You have jailed a player: '..ePly:Nick()..' for a reason: '..sReason..' on the '..nSeconds..' seconds' ) end
		
		print( '[Jailroom] Player '..ePly:SteamID()..' has jailes on '..nSeconds..' sec!' )

	end

	function Jailroom.JailPlayerOffline( sSteamID, eAdmin, nSeconds, sReason )

		if not sSteamID then print( '[Jailroom] JailPlayerOffline ERROR #03' ) return end

		local ply = player.GetBySteamID( sSteamID )
		if ply and IsValid( ply ) then Jailroom.JailPlayer( ply, eAdmin, sReason, nSeconds ) return end

		if ( nSeconds > Jailroom.Config.max_seconds ) then print( '[Jailroom] JailPlayerOffline WARNING #03' ) nSeconds = Jailroom.Config.max_seconds end
		if ( nSecond <= 0 ) then print( '[Jailroom] JailPlayerOffline WARNING #04' ) nSeconds = 1 end
		nSeconds = math.floor( nSeconds )
		
		local judge = eAdmin and eAdmin:Nick() or 'CONSOLE'
		local values = Format( '(%s, %i, %i, %s, %s)', sql.SQLStr( sSteamID ), nSeconds, os.time(), sql.SQLStr( sReason ), sql.SQLStr( judge ) )
		sql.Query( 'INSERT INTO Jailroom( SteamID, Time, Date, Reason, Judge ) VALUES '..values )

		if eAdmin then eAdmin:ChatPrint( 'You have jailed a player '..sSteamID ) end

		print( '[Jailroom] Player '..sSteamID..' has jailed on '..nSeconds..' sec!' )

	end

	function Jailroom.RemoveJailPlayer( ePly, eAdmin )

		local is_Jailroom = ePly:IsJailroom()
		if not is_Jailroom then print( '[Jailroom] RemoveJailPlayer ERROR #04' ) return end

		ePly:SetNWBool( 'Jailroom', false )
		ePly:SetNWInt( 'JailroomTime', 0 )
		ePly:changeTeam( TEAM_CITIZEN, true )
		ePly:Kill()

		net.Start( 'Jailroom_send_ply' )
			net.WriteBool( false )
			net.WriteUInt( 0, 16 )
		net.Send( ePly )

		if timer.Exists( 'JailroomPlayer'..ePly:SteamID() ) then timer.Remove( 'JailroomPlayer'..ePly:SteamID() ) end

		sql.Query( 'DELETE FROM Jailroom WHERE SteamID = '..sql.SQLStr( ePly:SteamID() ) )

		if eAdmin then 
		
			ePly:ChatPrint( 'You have been jailed  '..eAdmin:Nick() ) 
			eAdmin:ChatPrint( 'You unjailed a player:  '..ePly:Nick() )

		end

		print( '[Jailroom] Player '..ePly:SteamID()..' got out of jail!' )

	end

	function Jailroom.RemoveJailPlayerOffline( sSteamID, eAdmin )

		if not sSteamID then print( '[Аямочка] ОШИБКА #03' ) return end

		local ply = player.GetBySteamID( sSteamID )
		if ply and IsValid( ply ) then Jailroom.RemoveJailPlayer( ply, eAdmin ) return end

		sql.Query( 'DELETE FROM Jailroom WHERE SteamID = '..sql.SQLStr( sSteamID ) )

		print( '[Jailroom] Player  '..sSteamID..' got out of jail!' )

	end

	hook.Add( 'PlayerInitialSpawn', 'Jailroom.JailerTheFirstSpawn', function( ePly )

		timer.Simple( 2, function() 

			local steamid = sql.SQLStr( ePly:SteamID() )
			local time = sql.QueryValue( 'SELECT Time FROM Jailroom WHERE SteamID='..steamid )
			if not time then return end
		
			time = tonumber( time ) -- only seconds!
			local date = sql.QueryValue( 'SELECT Date FROM Jailroom WHERE SteamID='..steamid  )

			local finish_time = time + tonumber( date )
			local current_time = os.time()

			if ( finish_time <= current_time ) then sql.Query( 'DELETE FROM Jailroom WHERE SteamID = '..steamid ) ePly:ChatPrint( 'Your jail has expired!' ) return end

			ePly:changeTeam( TEAM_JAILROOM, true )
			ePly:SetNWBool( 'Jailroom', true )
			ePly:SetNWInt( 'JailroomTime', time )
			ePly:Spawn()

			net.Start( 'Jailroom_send_ply' )
				net.WriteBool( true )
				net.WriteUInt( time, 16 )
			net.Send( ePly )

			timer.Create( 'JailroomPlayer'..ePly:SteamID(), time, 1, function() Jailroom.RemoveJailPlayerOffline( ePly:SteamID() ) end )

		end )

	end )

	hook.Add( 'PlayerSpawn', 'Jailroom.JailerSpawn', function( ePly )

		if not ePly:IsJailroom() then return end

		timer.Simple( 0.1, function() 

			ePly:SetPos( Jailroom.Config.jailroom_pos )
			ePly:SetModel( Jailroom.Config.jailroom_model )
			ePly:SetCrouchedWalkSpeed( Jailroom.Config.jailroom_maxspeed )
			ePly:SetRunSpeed( Jailroom.Config.jailroom_maxspeed )
			ePly:SetWalkSpeed( Jailroom.Config.jailroom_maxspeed )
			ePly:StripWeapons()

		end )

	end )

	hook.Add( 'PlayerDisconnected', 'Jailroom.UpdateTimeForJailer', function( ePly )

		if not ePly:IsJailroom() then return end

		local steamid, time = sql.SQLStr( ePly:SteamID() ), math.floor( timer.TimeLeft( 'JailroomPlayer'..ePly:SteamID() ) )
		sql.Query( 'UPDATE Jailroom SET Time='.. time ..' WHERE SteamID='.. steamid )

		timer.Remove( 'JailroomPlayer'..ePly:SteamID() )

	end)

	-- Restrict

	hook.Add( 'CanPlayerSuicide', 'Jailroom.RestrictHook', function( ePly ) 
		
		if ePly:IsJailroom() then return false end 
		
	end )

	hook.Add( 'PlayerLoadout', 'Jailroom.RestrictHook', function( ePly ) 
		
		if ePly:IsJailroom() then return false end 
		
	end )

	hook.Add( 'PlayerSpawnObject', 'Jailroom.RestrictHook', function( ePly ) 
		
		if ePly:IsJailroom() then return false end 
		
	end)

	hook.Add( 'PlayerSpawnSENT', 'Jailroom.RestrictHook', function( ePly ) 
		
		if ePly:IsJailroom() then return false end 
		
	end)

	hook.Add( 'PlayerSpawnNPC', 'Jailroom.RestrictHook', function( ePly ) 
		
		if ePly:IsJailroom() then return false end 
		
	end)

	hook.Add( 'PlayerSpawnSWEP', 'Jailroom.RestrictHook', function( ePly ) 
		
		if ePly:IsJailroom() then return false end 
		
	end)

	hook.Add( 'PlayerSpawnVehicle', 'Jailroom.RestrictHook', function( ePly ) 
		
		if ePly:IsJailroom() then return false end 
		
	end)

	hook.Add( 'PlayerGiveSWEP', 'Jailroom.RestrictHook', function( ePly ) 
		
		if ePly:IsJailroom() then return false end 
		
	end)

	hook.Add( 'PlayerCanPickupWeapon', 'Jailroom.RestrictHook', function( ePly ) 
		
		if ePly:IsJailroom() then return false end 
		
	end)

    hook.Add( 'PlayerCanPickupItem', 'Jailroom.RestrictHook', function( ePly )
        
		if ePly:IsJailroom() then return false end 

    end )

    hook.Add( 'playerCanChangeTeam', "GhostBan_CantChangeJob",function( ePly )
        
		if ePly:IsJailroom() then return false end 

    end)

	hook.Add( 'PlayerCanJoinTeam', 'Jailroom.RestrictHook', function( ePly )

		if ePly:IsJailroom() then return false end 

	end )

	hook.Add( 'CanPlayerEnterVehicle', 'Jailroom.RestrictHook', function( ePly )

		if ePly:IsJailroom() then return false end

	end )


elseif CLIENT then

	local w = ScrW()
	local h = ScrH()

	surface.CreateFont( 'TheShitFont', {

		font = "Trebuchet24",
		size = ( h + w ) * .011,
		weight = 300, 
		blursize = 0, 
		scanlines = 0, 
		antialias = false, 
		underline = false, 
		italic = false, 
		strikeout = false, 
		symbol = false, 
		rotary = false, 
		shadow = true, 
		additive = false, 
		outline = false,

	} )

	local COLOR_WHITE = Color( 255, 255, 255 )
	local COLOR_BLACK = Color( 0, 0, 0 )

	net.Receive( 'Jailroom_send_ply',function()

		to_ban = net.ReadBool()
		time = net.ReadUInt( 16 )

		if not to_ban then hook.Remove( 'HUDPaint', 'Jailroom.DrawInfoPanel' ) return end

		timer.Create( 'JailroomTime', time, 1, function() end )

		hook.Add( 'HUDPaint', 'Jailroom.DrawInfoPanel', function()

			if not LocalPlayer():IsJailroom() then return end
			local time = timer.Exists( 'JailroomTime' ) and math.floor( timer.TimeLeft( 'JailroomTime' ) ) or 0
	        draw.SimpleTextOutlined( 'Until the end of Jail left '.. time ..' sec', 'TheShitFont', w / 2, 0, COLOR_WHITE, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, COLOR_BLACK )

		end)

	end)

end

if SAM_LOADED then return end
local sam, cmd, lang = sam, sam.command, sam.language
local cat = 'Jailroom'

cmd.set_category( cat )

cmd.new( 'jailroom' )

    :Help( 'Jail player' ) -- Да да, вам не послышалось! ОТ ЮЛИ! (Курить плохо...)

	:SetPermission( 'jailroom', 'admin' )

	:AddArg( 'player' )
	:AddArg( 'number', { hint = 'Seconds', min = 1, max = Jailroom.Config.max_seconds, round = true, optional = true, default = 250 } )
    :AddArg( 'text', { hint = 'Reason' } )

	:OnExecute( function( eAdmin, tTargets, nSeconds, sReason )

		if #tTargets > 1 then return end

		for i=1, #tTargets do

			local ply = tTargets[i]

			Jailroom.JailPlayer( ply, eAdmin, sReason, nSeconds )

		end

	end )

:End()

cmd.new( 'unjailroom' )

    :Help( 'Removes the jail from the player' )

	:SetPermission( 'unjailroom', 'admin' )

	:AddArg( 'player' )

	:OnExecute( function( eAdmin, target )

		if #target > 1 then return end

		for i=1, #target do

			local ply = target[i]

			Jailroom.RemoveJailPlayer( ply, eAdmin )

		end

	end )

:End()
