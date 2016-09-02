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
      handle_public_room(server)
    end

    # Advisement Voice Channels
    if event.user.on(server).role?(server.roles.find { |r| r.name == 'Verified' })
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
        delete_channel(server, channel) unless channel.nil?
      end
    end

    # Grade Voice Channels
    grades = %w(Freshmen Sophomores Juniors Seniors)
    Hash[grades.map { |g| [server.roles.find { |r| r.name == g }, server.voice_channels.find { |c| c.name == g } ] }]
      .each do |role, channel|
        next if role.nil?
        channel = server.voice_channels.find { |v| v.name == role.name }
        online_count = server.online_members.count { |m| m.role? role}
        if online_count >= 7
          if channel.nil?
            puts "Creating voice-channel for #{role.name}"
            channel = server.create_channel(role.name, 'voice')
            channel.position = 2
            channel.define_overwrite(role, perms, 0)
            Discordrb::API.update_role_overrides($token, channel.id, server.id, 0, perms.bits)
          end
        else
          # 1 or 0 online
          delete_channel(server, channel) unless channel.nil? or !channel.users.empty?
        end
      end

    if event.user.status == :offline
      $db.query("UPDATE students SET last_online='#{Time.new}' WHERE discord_id=#{event.user.id}")
    end
  end
end
