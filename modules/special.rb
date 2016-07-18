module SpecialRoomEvents
  extend Discordrb::EventContainer

  presence do |event|
    server = event.server

    # Guest Rooms
    guest_role = server.roles.find { |r| r.name == 'Guests' }
    unless server.online_members.find_all { |m| m.role? guest_role }.empty?
      if server.voice_channels.find { |c| c.name == 'Guest Room' }.nil?
        guest_room = server.create_channel('Guest Room', 'voice')
        guest_room.position = 1
        perms = Discordrb::Permissions.new
        perms.can_connect = true
        perms.can_speak = true
        perms.can_use_voice_activity = true

        Discordrb::API.update_role_overrides($token, guest_room.id, server.id, perms.bits, 0)
      end
    else
      begin
        guest_room = server.voice_channels.find { |c| c.name == 'Guest Room' }
        begin
          server.text_channels.find { |t| t.id == $hierarchy[guest_room.id] }.delete
          $hierarchy.delete guest_room.id
        rescue
          puts 'Failed to find/delete associated #voice-channel'
        end
        guest_room.delete
      rescue
        puts 'Guest Room didn\'t exist so can\'t delete'
      end
    end

    # Grade Voice Channels
    grades = %w(Freshmen Sophomores Juniors Seniors)
    Hash[grades.map { |g| [server.roles.find { |r| r.name == g }, server.voice_channels.find { |c| c.name == g } ] }]
      .each do |role, channel|
        next if role.nil?
        online_count = server.online_members.count { |m| m.role? role}
        if online_count >= 2
          if channel.nil?
            puts "Creating voice-channel for #{role.name}"
            channel = server.create_channel(role.name, 'voice')
            channel.position = server.voice_channels.find { |c| c.name == 'Guest Room' }.nil? ? 1 : 2 # Since Guest Room is always the first room
            perms = Discordrb::Permissions.new
            perms.can_connect = true
            perms.can_speak = true
            perms.can_use_voice_activity = true

            channel.define_overwrite(role, perms, 0)
            Discordrb::API.update_role_overrides($token, channel.id, server.id, 0, perms.bits)
          end
        else
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
end
