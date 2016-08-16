module WorkCommands
  extend Discordrb::Commands::CommandContainer

  grades = %w(Freshmen Sophomores Juniors Seniors)
  command(:study, description: 'Toggle your ability to see non-work text channels to focus!', bucket: :study, permission_level: 1) do |event|
    event.message.delete unless event.message.channel.private?

    server = event.bot.server(150_739_077_757_403_137)
    studyrole = server.roles.find { |r| r.name == 'studying' }
    user = event.user.on(server)
    clean_name = user.display_name
    clean_name.sub! '[S] ', ''
    # Permissions
    perms = Discordrb::Permissions.new
    perms.can_read_messages = true
    perms.can_read_message_history = true
    perms.can_send_messages = true
    if user.role? studyrole
      user.nickname = clean_name
      user.remove_role studyrole
      # Issue for grade channels
      grades.each do |g|
        gname = g.downcase
        role = server.roles.find { |r| r.name == g }
        if !role.nil? and user.role? role
          grade_channel = server.text_channels.find { |c| c.name == gname }
          Discordrb::API.update_user_overrides(event.bot.token, grade_channel.id, user.id, 0, 0)
        end
      end
      $db.query('SELECT * FROM groups').each do |row|
        group_role = server.roles.find { |r| r.id == Integer(row['role_id']) }
        next if group_role.nil? or !user.role? group_role

        group_channel = server.text_channels.find{ |c| c.id == Integer(row['room_id']) }
        Discordrb::API.update_user_overrides(event.bot.token, group_channel.id, user.id, 0, 0)
        sleep 0.5
      end

      if !user.voice_channel.nil? and !user.permission? 'can_connect', user.voice_channel
        puts 'Moving to allowed voice-channel'
        server.move user, server.voice_channels.find { |c| c.name == '[New Room]' }
        user.pm 'You were moved into a new voice-channel because your previous one only allowed students in studymode.'
      end
    else
      # GOING INTO STUDYMODE
      user.nickname = "[S] #{clean_name}"[0..30]
      user.add_role studyrole
      # Issue for grade channels
      grades.each do |g|
        gname = g.downcase
        role = server.roles.find { |r| r.name == g }
        if !role.nil? and user.role? role
          grade_channel = server.text_channels.find { |c| c.name == gname }
          Discordrb::API.update_user_overrides(event.bot.token, grade_channel.id, user.id, 0, perms.bits)
          sleep 0.5
        end
      end
      $db.query('SELECT * FROM groups').each do |row|
        group_role = server.roles.find { |r| r.id == Integer(row['role_id']) }
        if !group_role.nil? and user.role? group_role
          group_channel = server.text_channels.find { |c| c.id == Integer(row['room_id']) }
          Discordrb::API.update_user_overrides(event.bot.token, group_channel.id, user.id, 0, perms.bits)
        end
      end

      # Check if current voice-channel (if exists) allows studying students and move them if necessary
      unless user.voice_channel.nil? or user.permission? 'can_connect', user.voice_channel
        puts 'Moving to allowed voice-channel'
        server.move user, server.voice_channels.find { |c| c.name == '[New Room]' }
        user.pm 'You were moved into a new voice-channel because your previous one did not allow students in studymode.'
      end
    end

    nil
  end
end

