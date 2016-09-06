def handle_grade_voice_channels(server)
  # Grade Voice Channels
  grades = %w(Freshmen Sophomores Juniors Seniors)
  Hash[grades.map { |g| [server.roles.find { |r| r.name == g }, server.voice_channels.find { |c| c.name == g } ] }]
    .each do |role, channel|
      next if role.nil?
      channel = server.voice_channels.find { |v| v.name == role.name }
      online_count = server.online_members.count { |m| m.role? role}
      
      delete_channel(server, channel) if (!channel.nil? and online_count <= 2 and channel.users.empty?)
    end
end

module SpecialRoomEvents
  extend Discordrb::EventContainer

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
      user = event.user.on(server)
      advisement_role = user.roles.find { |r| r.name.length == 2 and %w(1 2 3 4).include? r.name[0] }

      online_count = server.online_members.count { |m| m.role? advisement_role }

      channel = server.voice_channels.find { |v| v.name == "Advisement #{advisement_role.name}" }
      delete_channel(server, channel) if (online_count <= 2 and !channel.nil? and channel.users.empty?)
    end

    handle_grade_voice_channels(server)

    if event.user.status == :offline
      $db.query("UPDATE students SET last_online='#{Time.new}' WHERE discord_id=#{event.user.id}")
    end
  end
end
