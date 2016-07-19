module RoomEvents
  extend Discordrb::EventContainer
  presence do |event|
    handle_group_voice_channels(event.server)
  end
end

module RoomCommands
  extend Discordrb::Commands::CommandContainer
  command(:groups, description: 'List availble groups.') do |event|
    server = event.bot.server(150_739_077_757_403_137)
    user = event.user.on(server)
    to_delete = [event.message]
    messages = []
    messages << '**Open Groups**'
    $db.query('SELECT * FROM groups').each do |row|
      group_role = server.roles.find { |r| r.id == Integer(row['role_id']) }
      count = server.members.find_all { |m| m.role? group_role }.length
      owner = row['creator'] != 'server' ? "**#{row['creator']}**" : ''

      messages << "`#{row['name']}` *#{row['description']}* #{owner} (#{count} members)"
    end
    messages << "\n *Use `!join \"group\"` to join."
    messages << 'Use `!creategroup "Name Here" "Description here."` to start a group.*'

    to_delete << event.channel.send_message(messages.join("\n"))
    sleep 60
    to_delete.each(&:delete)

    nil
  end

  command(:creategroup, description: 'Create a group to get your own role and text-channel.') do |event, full_name, description|
    event.message.delete unless event.channel.private?

    full_name.strip!
    description = description ? description[0..254] : 'No description given.'
    group_name = full_name.dup
    puts "Attempting to make group '#{full_name}'"
    # Check if group exists already or person already has group
    group_name = $db.escape(group_name)
    existing = $db.query("SELECT COUNT(*) AS count FROM groups JOIN students ON students.username=groups.creator WHERE students.discord_id=#{event.user.id} OR groups.name='#{group_name}'").first['count']
    if existing > 0
      puts 'Group exists or user already has group'
      event.message.reply 'A group by that name already exists or you already started a group.'
      return
    end

    # Sanitize group name
    group_name.downcase!
    group_name.strip!
    group_name.gsub!(/\s+/, '-')
    group_name.gsub!(/[^\p{Alnum}-]/, '')

    server = event.bot.server(150_739_077_757_403_137)
    user = event.user.on(server)
    # Good to go
    perms = Discordrb::Permissions.new
    perms.can_read_messages = true
    perms.can_read_message_history = true
    perms.can_send_messages = true
    # Permissions for group creator
    creator_perms = Discordrb::Permissions.new
    creator_perms.can_manage_messages = true
    # Create role
    group_role = server.create_role
    group_role.name = full_name
    user.add_role group_role
    # Create text-channel
    group_room = server.create_channel group_name
    group_room.topic = description
    group_room.define_overwrite(group_role, perms, 0)
    # group_room.define_overwrite(user, creator_perms, 0)
    Discordrb::API.update_user_overrides(event.bot.token, group_room.id, user.id, creator_perms.bits, 0)
    Discordrb::API.update_role_overrides(event.bot.token, group_room.id, server.id, 0, perms.bits)
    # Get Regis username of user
    username = 'unknown'
    $db.query("SELECT username FROM students WHERE discord_id=#{event.user.id}").each do |row|
      username = row['username']
    end
    # Insert group in DB
    $db.query("INSERT INTO groups (creator, name, private, room_id, role_id, description) VALUES ('#{username}', '#{full_name}', 0, '#{group_room.id}', '#{group_role.id}', '#{description}')")
    user.pm "You have created **#{full_name}!** Others can join with `!join \"#{full_name}\"` \n Change the description of the group with `!description \"New Description\"`.\nDelete the group with `!deletegroup`."
    handle_group_voice_channels(server)
    # Announce to #meta
    server.text_channels.find{|c| c.name == 'meta'}.send_message "@everyone #{user.mention} has just created the group **#{full_name}**. Join with `!join \"#{full_name}\"`"
    
    nil
  end

  command(:deletegroup, description: 'Delete a group that you started.') do |event|
    event.message.delete unless event.channel.private?

    server = event.bot.server(150_739_077_757_403_137)

    $db.query("SELECT * FROM groups JOIN students ON students.username=groups.creator WHERE students.discord_id=#{event.user.id}").each do |row|
      server.roles.find { |r| r.id == Integer(row['role_id']) }.delete
      server.text_channels.find { |r| r.id == Integer(row['room_id']) }.delete
      begin
        server.voice_channels.find { |c| c.name == "Group #{row['name']}" }.delete
      rescue
      end
    end
    $db.query("DELETE groups FROM groups JOIN students ON groups.creator=students.username WHERE students.discord_id=#{event.user.id}")
    event.user.pm 'Successfully deleted group!'
    nil
  end

  # List of special channels
  command(:join, description: 'Join a group. Usage: `!join "group"`') do |event, group_name|
    event.message.delete unless event.channel.private?
    return if group_name.nil?

    server = event.bot.server(150_739_077_757_403_137)
    user = event.user.on(server)

    role = nil
    group_name = $db.escape(group_name)
    $db.query("SELECT role_id FROM groups WHERE name='#{group_name}'").each do |row|
      role = server.roles.find { |r| r.id == Integer(row['role_id']) }
    end
    if !role.nil?
      user.add_role role
      user.pm 'Joined group!'
    else
      user.pm 'Invalid group! For a list of availble groups type `!groups`.'
    end

    handle_group_voice_channels(server)
    nil
  end

  command(:leave, description: 'Leave a group. Usage: `!leave group`') do |event, group_name|
    event.message.delete unless event.channel.private?

    server = event.bot.server(150_739_077_757_403_137)
    user = event.user.on(server)
    group_name = $db.escape(group_name)
    role = nil
    $db.query("SELECT role_id FROM groups WHERE name='#{group_name}'").each do |row|
      role = server.roles.find { |r| r.id == Integer(row['role_id']) }
    end
    if !role.nil?
      user.remove_role role
      user.pm 'Left group!'
    else
      user.pm 'Invalid group!'
    end

    handle_group_voice_channels(server)
    nil
  end

  command(:description, description: 'Change the description of your group.') do |event, description|
    event.message.delete unless event.channel.private?

    channel = nil
    server = event.bot.server(150_739_077_757_403_137)

    $db.query("SELECT room_id FROM groups JOIN students ON students.username=groups.creator WHERE students.discord_id=#{event.user.id}").each do |row|
      channel = server.text_channels.find{|c| c.id==Integer(row['room_id'])}
    end
    unless channel.nil?
      channel.topic = description
      $db.query("UPDATE groups JOIN students ON students.username=groups.creator SET groups.description='#{description}' WHERE students.discord_id=#{event.user.id}")
      event.user.pm 'Updated group description.'
    end
    nil
  end
end