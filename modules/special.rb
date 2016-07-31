module SpecialRoomEvents
  extend Discordrb::EventContainer

  advisements = {}
  # {
  #   my id => "2B-1"
  # }

  presence do |event|
    server = event.server

    perms = Discordrb::Permissions.new
    perms.can_connect = true
    perms.can_speak = true
    perms.can_use_voice_activity = true
    
    # Public Room
    guest_role = server.roles.find { |r| r.name == 'Guests' }
    if event.user.on(server).role? guest_role
      online_count = server.online_members.count { |m| m.role? guest_role }
      public_room = server.voice_channels.find { |v| v.name == "Public Room" }
      if online_count > 0 and public_room.nil?
        puts "Creating Public Room"
        public_room = server.create_channel("Public Room", 'voice')
        public_room.position = 1
        Discordrb::API.update_role_overrides($token, public_room.id, server.id, perms.bits, 0)
      elsif online_count == 0 and !public_room.nil?
        puts "Removing Public Room"
        begin
          server.text_channels.find { |t| t.id == $hierarchy[public_room.id] }.delete
          $hierarchy.delete public_room.id
        rescue
          puts 'Failed to find/delete associated #voice-channel'
        end
        public_room.delete
      end
    end
    
    # Advisement Voice Channels
    if event.user.on(server).role? server.roles.find { |r| r.name == 'Verified' }
      advisement = advisements[event.user.id]
      if advisement.nil?
        advisement = $db.query("SELECT advisement FROM students WHERE discord_id=#{event.user.id}").map { |row| row['advisement'][0..1] }.first
        advisements[event.user.id] = advisement
      end

      advisement_role = server.roles.find { |r| r.name == advisement }
      online_count = server.online_members.count { |m| m.role? advisement_role }
      
      channel = server.voice_channels.find { |v| v.name == advisement }
      
      if online_count >= 7
        if channel.nil?
          puts "Creating voice-channel for Advisement #{advisement}"
          channel = server.create_channel("Advisement #{advisement}", 'voice')
          channel.position = 2
          channel.define_overwrite(advisement_role, perms, 0)
          Discordrb::API.update_role_overrides($token, channel.id, server.id, 0, perms.bits)
        end
      elsif online_count <= 2
        # 1 or 0 online
        unless channel.nil?
          puts "Removing voice-channel for Advisement #{advisement}"
          begin
            server.text_channels.find { |t| t.id == $hierarchy[channel.id] }.delete
            $hierarchy.delete channel.id
          rescue
            puts 'Failed to find/delete associated #voice-channel'
          end
          channel.delete
        end
      end
    end

    # Grade Voice Channels
    grades = %w(Freshmen Sophomores Juniors Seniors)
    Hash[grades.map { |g| [server.roles.find { |r| r.name == g }, server.voice_channels.find { |c| c.name == g } ] }]
      .each do |role, channel|
        next if role.nil?
        online_count = server.online_members.count { |m| m.role? role}
        if online_count >= 3
          if channel.nil?
            puts "Creating voice-channel for #{role.name}"
            channel = server.create_channel(role.name, 'voice')
            channel.position = 2
            channel.define_overwrite(role, perms, 0)
            Discordrb::API.update_role_overrides($token, channel.id, server.id, 0, perms.bits)
          end
        else
          channel = server.voice_channels.find { |v| v.name == role.name }
          # 1 or 0 online
          unless channel.nil?
            puts "Removing voice-channel for #{role.name}"
            begin
              server.text_channels.find { |t| t.id == $hierarchy[channel.id] }.delete
              $hierarchy.delete channel.id
            rescue
              puts 'Failed to find/delete associated #voice-channel'
            end
            channel.delete
          end
        end
      end
  end

  sleep 30
end
