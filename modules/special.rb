module SpecialRoomEvents
  extend Discordrb::EventContainer

  presence do |event|
    server = event.server

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

  sleep 30
end
