module GroupEvents
  extend Discordrb::EventContainer
  presence do |event|
    handle_group_voice_channels(event.server)
  end
end

module GroupCommands
  extend Discordrb::Commands::CommandContainer
  command(:groups, min_args: 0, max_args: 0, description: 'List availble groups.', permission_level: 1) do |event|
    server = event.bot.server(150_739_077_757_403_137)
    user = event.user.on(server)
    to_delete = [event.message]
    
    messages = []
    $db.query('SELECT * FROM groups WHERE private=0 ORDER BY name').each do |row|
      group_role = server.roles.find { |r| r.id == Integer(row['role_id']) }
      count = server.members.find_all { |m| m.role? group_role }.length
      owner = row['creator'] != 'server' ? "(#{row['creator']})" : ''

      messages << "**#{row['name']}** `#{row['description']}` *#{count} users* #{owner}"

      #messages << "#{row['default_group'] == 1 ? '*' : ''}`#{row['name']}` *#{row['description']}* (#{count} members) #{owner}"
    end
    messages << '*Private groups are not listed. You must be invited to these to join.*'
    messages << "\n *Use `!join \"group\"` to join."
    messages << 'Use `!creategroup "Name Here" "Description here."` to start a group.*'
    
    puts messages.join("\n").length
    messages.each_slice(10) do |messages|
      to_delete << event.channel.send_message(messages.join("\n"))
    end
    sleep 60 * 3
    begin  
      to_delete.each(&:delete) unless event.channel.private?
    rescue
    
    end
    nil
  end

  command(:toggleprivate, min_args: 0, max_args: 0, description: 'Toggle your group\'s privacy status.', permission_level: 1) do |event|
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

  command(:creategroup, min_args: 2, max_args: 3, description: 'Create a group to get your own role and text-channel.', usage: '`!creategroup "Name" "Description" yes/no (private)`', permission_level: 1) do |event, full_name, description, private|
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
    
    if group_name.length < 3
      event.user.pm 'Group name is too short. It must be at least 3 characters long.'
      return
    end
    
    if group_name.length > 20
      event.user.pm 'Group name is too long. It must be less than 21 characters.'
      return
    end
    
    group_name.gsub!(/\s+/, '-')
    group_name.gsub!(/[^\p{Alnum}-]/, '')
    
    server = event.bot.server(150_739_077_757_403_137)
    user = event.user.on(server)
    # Good to go
    perms = Discordrb::Permissions.new
    perms.can_read_messages = true
    perms.can_read_message_history = true
    perms.can_send_messages = true
		perms.can_mention_everyone = true
		
		# Fix for @here replacing
		g_perms = perms.clone
		g_perms.can_mention_everyone = false

		other_p = Discordrb::Permissions.new
		other_p.can_mention_everyone = true
		
    # Permissions for group creator
    creator_perms = Discordrb::Permissions.new
    creator_perms.can_manage_messages = true
    # Create role
    group_role = server.create_role
    group_role.name = full_name
    #group_role.mentionable = true
    user.add_role group_role
    # Create text-channel
    group_room = server.create_channel group_name
    group_room.topic = description
    group_room.define_overwrite(group_role, g_perms, other_p)
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
    user.pm "You have created **#{full_name}!**"
		user.pm "Others can join with `!join \"#{full_name}\"`" if p == 0
		user.pm "Invite other users with `!invite '#{full_name}' @user`" if p == 1
		user.pm "Change the description of the group with `!description \"New Description\"`.\nDelete the group with `!deletegroup`."
    handle_group_voice_channels(server)
    # Announce to #meta (if public)
    server.text_channels.find{|c| c.name == 'meta'}.send_message("@everyone #{user.mention} has just created the group **#{full_name}**. Join with `!join \"#{full_name}\"`") unless private == 1
		user.pm "*As group founder, you can manage (delete/pin) messages in your group's text-channel.*"
    $groups = $db.query('SELECT * FROM groups WHERE creator != "server" AND voice_channel_allowed=1')
    nil
  end

  command(:deletegroup, min_args: 0, max_args: 0, description: 'Delete a group that you started.', permission_level: 1) do |event|
    event.message.delete unless event.channel.private?
    
    server = event.bot.server(150_739_077_757_403_137)

    $db.query("SELECT * FROM groups JOIN students ON students.username=groups.creator WHERE students.discord_id=#{event.user.id}").each do |row|
      server.roles.find { |r| r.id == Integer(row['role_id']) }.delete
      server.text_channels.find { |r| r.id == Integer(row['room_id']) }.delete
      begin
        delete_channel(server, server.voice_channels.find { |c| c.name == "Group #{row['name']}" })
        g_role = server.roles.find { |r| r.name == row['name'] }.delete
        #g_role.members.each { |m| m.pm "Creator #{event.user.mention} (#{row['creator']}) has deleted **Group #{row['name']}**!" }
        g_role.delete
      rescue
        puts 'Failed to remove group channel and/or role'
      end
    end
    
    $db.query("DELETE groups FROM groups JOIN students ON groups.creator=students.username WHERE students.discord_id=#{event.user.id}")
    event.user.pm 'Successfully deleted group!'

    nil
  end
  
  invites = {}
  command(:invite, min_args: 2, max_args: 2, description: 'Invite a student to a group.', usage: '`!invite "Group" @user`', permission_level: 1) do |event, group_name|
    event.message.delete unless event.channel.private?
    if group_name.nil? or event.message.mentions.empty?
      event.user.pm "Invalid syntax. `!invite 'Group' @user`"
      return
    end
    
    server = event.bot.server(150_739_077_757_403_137)
    user = event.user.on(server)
    
    target = event.message.mentions.first.on(server)
    unless target.role? server.roles.find { |r| r.name == 'Verified' }
			user.pm 'You can only invite Regians to groups.'
			return
		end
		
    role = nil
    group_name = $db.escape(group_name)
		room = nil
		is_private = nil
    $db.query("SELECT role_id, room_id, private FROM groups WHERE name='#{group_name}'").each do |row|
      is_private = row['private'] == 1
			role = server.roles.find { |r| r.id == Integer(row['role_id']) }
			room = server.text_channels.find { |t| t.id == Integer(row['room_id']) }
			break
		end
    
    if role.nil?
      user.pm 'Invalid group.'
    else
      if user.role? role
				if target.role? role
					user.pm 'They are already in that group!'
				elsif is_private
					target.pm "You have been invited to the private **Group #{group_name}**. Type `!join '#{group_name}'` to enter!"
					invites[target.id] = group_name
					room.send_message "#{target.mention} has been invited to join the group."
				else
					target.pm "#{user.mention} wants you to join public **Group #{group_name}**! `!join '#{group_name}'`"
					room.send_message "#{target.mention} has been asked to join the group."
				end
			else
        user.pm 'You can only invite users to a group you are in yourself.'
      end
    end

    nil
  end
  
  # List of special channels
  command(:join, min_args: 1, max_args: 1, description: 'Join a group.', usage: '`!join "group"`', permission_level: 1) do |event, group_name|
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
        if invites[user.id].downcase == group_name.downcase
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
  
  command(:togglevoicechannel, min_args: 1, max_args: 1, description: 'Toggle whether a group can get a private voice-channel.', usage: '`!togglevoicechannel "Group"`', permission_level: 2) do |event, group|
    event.message.delete unless event.channel.private?
    server = event.bot.server(150_739_077_757_403_137)
    group = $db.escape(group)
    
    $db.query("SELECT voice_channel_allowed FROM groups WHERE name='#{group}'").each do |row|
      status = row['voice_channel_allowed'] == 1 ? 0 : 1
      $db.query("UPDATE groups SET voice_channel_allowed=#{status} WHERE name='#{group}'")
      puts "Group #{group} #{status == 1 ? 'now gets' : 'can no longer get'} a voice-channel"
      event.user.pm("Group #{group} #{status == 1 ? 'now gets' : 'can no longer get'} a voice-channel")
      
      # Remove voice channel if open
      delete_channel(server, server.voice_channels.find { |v| v.name == "Group #{group}" })
      break
    end
    
    $groups = $db.query('SELECT * FROM groups WHERE creator != "server" AND voice_channel_allowed=1')
    handle_group_voice_channels(server)
    nil
  end
  
  command(:leave, min_args: 0, max_args: 1, description: 'Leave a group.', usage: '`!leave "group"` or while in a group\'s text-channel: `!leave`', permission_level: 1) do |event, group_name|
    event.message.delete unless event.channel.private?

    server = event.bot.server(150_739_077_757_403_137)
    user = event.user.on(server)
		
		condition = "room_id='#{event.channel.id}'"
		unless group_name.nil?
			group_name = $db.escape(group_name)
			condition = "name='#{group_name}'"
		end
		
    role = nil
    channel = nil
    $db.query("SELECT role_id, room_id FROM groups WHERE #{condition}").each do |row|
      role = server.roles.find { |r| r.id == Integer(row['role_id']) }
      channel = server.text_channels.find { |c| c.id == Integer(row['room_id']) }
			break
    end

    if !role.nil? and user.role?(role)
      user.remove_role role
      user.pm 'Left group!'
      unless channel.nil?
        channel.send_message "*#{user.mention} left the group.*"
      end
    else
      user.pm 'You aren\'t in that group!'
    end

    handle_group_voice_channels(server)
    nil
  end

  command(:description, min_args: 1, max_args: 1, description: 'Change the description of your group.', usage: '`!description "New Description"`', permission_level: 1) do |event, description|
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