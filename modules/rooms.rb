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
    messages << '**Public Groups**'
    $db.query('SELECT * FROM groups WHERE private=0').each do |row|
      group_role = server.roles.find { |r| r.id == Integer(row['role_id']) }
      count = server.members.find_all { |m| m.role? group_role }.length
      owner = row['creator'] != 'server' ? "**#{row['creator']}**" : ''

      messages << "#{row['default'] == 1 ? '*' : ''}`#{row['name']}` *#{row['description']}* (#{count} members) #{owner}"
    end
    messages << '*Private groups are not listed. You must be invited to these to join.*'
    messages << "\n *Use `!join \"group\"` to join."
    messages << 'Use `!creategroup "Name Here" "Description here."` to start a group.*'

    to_delete << event.channel.send_message(messages.join("\n"))
    sleep 60
    to_delete.each(&:delete) unless event.channel.private?

    nil
  end
  
  command(:toggleprivate, description: 'Toggle your group\'s privacy status.') do |event|
    event.message.delete unless event.channel.private?
    
    channel = nil
    server = event.bot.server(150_739_077_757_403_137)
    p_status = nil
    
    $db.query("SELECT room_id, private FROM groups JOIN students ON students.username=groups.creator WHERE students.discord_id=#{event.user.id}").each do |row|
      p_status = row['private']
      channel = server.text_channels.find { |c| c.id == Integer(row['room_id']) }
    end
    
    if p_status.nil?
      event.user.pm 'You don\'t have a group.'
    else
      p_status = p_status == 1 ? 0 : 1 # Flip
      
      $db.query("UPDATE groups JOIN students ON students.username=groups.creator SET groups.private=#{p_status} WHERE students.discord_id=#{event.user.id}")
      unless channel.nil?
        channel.send_message "This group is now **#{p_status == 1 ? 'private' : 'public'}**."
      end
    end
    
    puts 'Updated group privacy status.'
    
    nil
  end
  
  command(:creategroup, description: 'Create a group to get your own role and text-channel. Usage: `!creategroup "Name" "Description" yes/no (private)`') do |event, full_name, description, private|
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
    
    # Private
    p = false
    p = true if !private.nil? and (private == "yes" or private == "true" or private == "1")
    p = if p then 1 else 0 end
    
    # Insert group in DB
    $db.query("INSERT INTO groups (creator, name, private, room_id, role_id, description) VALUES ('#{username}', '#{full_name}', #{p}, '#{group_room.id}', '#{group_role.id}', '#{description}')")
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
        server.roles.find { |r| r.name == row['name'] }.delete
      rescue
        puts 'Failed to remove group channel and/or role'
      end
    end
    $db.query("DELETE groups FROM groups JOIN students ON groups.creator=students.username WHERE students.discord_id=#{event.user.id}")
    event.user.pm 'Successfully deleted group!'

    nil
  end
  
  invites = {}
  command(:invite, description: 'Invite a student to a private group. Usage: `!invite "Group" @user`') do |event, group_name|
    event.message.delete unless event.channel.private?
    if group_name.nil? or event.message.mentions.empty?
      user.pm "Invalid syntax. `!invite 'Group' @user`"
      return
    end
    
    server = event.bot.server(150_739_077_757_403_137)
    user = event.user.on(server)
    
    target = event.message.mentions.first
    
    role = nil
    group_name = $db.escape(group_name)
    $db.query("SELECT role_id, room_id FROM groups WHERE name='#{group_name}' AND private=1").each do |row|
      role = server.roles.find { |r| r.id == Integer(row['role_id']) }
    end
    
    if role.nil?
      user.pm 'Invalid group.'
    else
      if user.role? role 
        target.pm "You have been invited to the private **Group #{group_name}**. Type `!join '#{group_name}'` to enter!"
        invites[target.id] = group_name
      else
        user.pm 'You can only invite users to a group you are in yourself.'
      end
    end
    
    nil
  end
  
  # List of special channels
  command(:join, description: 'Join a group. Usage: `!join "group"`') do |event, group_name|
    event.message.delete unless event.channel.private?
    return if group_name.nil?

    server = event.bot.server(150_739_077_757_403_137)
    user = event.user.on(server)
  
    private = false
    role = nil
    channel = nil
    group_name = $db.escape(group_name)
    $db.query("SELECT role_id, room_id, private FROM groups WHERE name='#{group_name}'").each do |row|
      role = server.roles.find { |r| r.id == Integer(row['role_id']) }
      channel = server.text_channels.find { |c| c.id == Integer(row['room_id']) }
      private = (row['private'] == 1)
    end
    
    if role.nil?
      user.pm 'Invalid group! For a list of availble groups type `!groups`.'
    else
      if private
        if invites[user.id] == group_name
          # Was invited
          user.add_role role
          unless channel.nil?
            channel.send_message "*#{user.mention} joined the group.*"
            puts "#{user.display_name} joined Group #{group_name}"
          end
          
          invites.delete user.id
        else
          # Was NOT invited
          user.pm 'You have not been invited to that private group.'
        end
      else
        user.add_role role
        unless channel.nil?
          channel.send_message "*#{user.mention} joined the group.*"
        end
        puts "#{user.display_name} joined Group #{group_name}"
      end
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
    channel = nil
    $db.query("SELECT role_id, room_id FROM groups WHERE name='#{group_name}'").each do |row|
      role = server.roles.find { |r| r.id == Integer(row['role_id']) }
      channel = server.text_channels.find { |c| c.id == Integer(row['room_id']) }
    end

    if !role.nil?
      user.remove_role role
      user.pm 'Left group!'
      unless channel.nil?
        channel.send_message "*#{user.mention} left the group.*"
      end
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
    
    puts 'Updated group description.'
    
    nil
  end
end