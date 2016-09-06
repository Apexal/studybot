module ModeratorCommands
  extend Discordrb::Commands::CommandContainer
  
  command(:reorder, permission_level: 3) do |event|
    pos = event.server.text_channels.find { |t| t.name == 'seniors' }.position
    adv_channels = event.server.text_channels.find_all { |t| %w(1 2 3 4).include? t.name[0] }.sort { |a, b| a.name <=> b.name }
    adv_channels.each { |a| a.position = pos; puts "#{a.name} at #{pos}"; sleep 1; pos+=1 }

    pos = event.server.text_channels.find_all { |t| %w(1 2 3 4).include? t.name[0] }.sort { |a, b| a.position <=> b.position }.last.position
    $db.query('SELECT room_id FROM courses WHERE room_id IS NOT NULL').each do |row|
      begin
        event.server.text_channels.find { |t| t.id == Integer(row['room_id']) }.position = pos
      rescue

      end
      sleep 1
    end
    puts 'Done.'
  end
  
  command(:sync, permission_level: 3) do |event|
    server = event.bot.server(150_739_077_757_403_137)
    puts 'GROUPS'
    # GROUP PERMS
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
    $db.query("SELECT * FROM groups").each do |row|
      puts row['name']
      role = server.roles.find { |r| r.id == Integer(row['role_id']) }

      channel_name = row['name']
      channel_name.downcase!
      channel_name.strip!
      channel_name.gsub!(/\s+/, '-')
      channel_name.gsub!(/[^\p{Alnum}-]/, '')


      channel = server.text_channels.find { |t| t.name == channel_name }
      
      # GROUP CHANNEL IS MISSING!
      if channel.nil?
        puts 'Creating text-channel.'
        channel = server.create_channel row['name']
        channel.define_overwrite(role, g_perms, other_p)
        Discordrb::API.update_role_overrides($token, channel.id, server.id, 0, perms.bits)
        $db.query("UPDATE groups SET room_id='#{channel.id}' WHERE name='#{row['name']}'")
      else
        puts 'Already has text-channel.'
      end
      channel.topic = row['description']

      sleep 0.5
    end
    puts 'Done.'


    # GRADE PERMS
    perms = Discordrb::Permissions.new
    perms.can_read_messages = true
    perms.can_read_message_history = true
    perms.can_send_messages = true
		perms.can_mention_everyone = true

    puts 'Grade text-channels'
    grades = %w(Freshmen Sophomores Juniors Seniors).reverse
    grades.each do |grade|
      puts grade
      role = server.roles.find { |r| r.name == grade.downcase }
      channel = server.text_channels.find { |t| t.name == grade.downcase }

      if channel.nil?
        puts 'Creating...'
        channel = server.create_channel grade
        channel.topic = "Private discussion room for all **#{grade}**."
        channel.position = 5
        channel.define_overwrite(role, perms, 0)
        Discordrb::API.update_role_overrides($token, channel.id, server.id, 0, perms.bits)
      end
    end
    puts 'Done.'
  end


  command(:purgatory) do |event|
    server = event.bot.server(150_739_077_757_403_137)
    server.members.find_all { |m| m.roles.empty? }.each do |m|
      m.pm 'Hey! You haven\'t registered yet! You can\' use anything in the server until you do this. Just send me the message `!register regisusername` (with your Regis username).'
    end
  end
  
  command(:closecourses, permission_level: 3) do |event|
    event.message.delete unless event.channel.private?
    
    server = event.bot.server(150_739_077_757_403_137)
    # Remove course rooms
    $db.query('SELECT room_id FROM courses WHERE room_id IS NOT NULL').each do |row|
      begin
        event.server.text_channels.find{ |c| c.id == Integer(row['room_id']) }.delete
        sleep 0.5
      rescue
        puts "No room #{row['room_id']}"
      end
    end
    $db.query('UPDATE courses SET room_id=NULL WHERE room_id IS NOT NULL')
    event.user.pm 'Closed course channels.'
    nil
  end

  command(:mute, min_args: 1, max_args: 1, description: 'Toggle a text mute on a user.', usage: '`!mute @user`', permission_level: 2) do |event|
    event.message.delete unless event.channel.private?
    
    server = event.bot.server(150_739_077_757_403_137)
    target = event.message.mentions.first.on(server)
    
    if target.nil?
      event.user.pm 'Please mention a user to be muted/unmuted.'
      return
    end
    
    if !target.role? server.roles.find { |r| r.name == 'Verified' } or target.role? server.roles.find { |r| r.name == 'Moderators' }
      unless target.role? server.roles.find { |r| r.name == 'Guests' }
        event.user.pm 'You can only mute non-moderator students and guests.'
        return
      end
    end
    
    muted_role = server.roles.find { |r| r.name == 'Muted' }
    if target.role? muted_role
      target.remove_role muted_role
      target.pm 'You have been unmuted by a Moderator!'
    else
      target.add_role muted_role
      target.pm 'You have been muted by a Moderator!'
    end
    
    event.user.pm "Toggled mute on #{target.mention}"
    puts "#{event.user.mention} toggled mute on #{target.mention}"
    
    nil
  end
  
  command(:report, min_args: 1, max_args: 1, description: "Send a report to the servers' Moderators.", usage: "`!report 'Message' @optionaluser`", bucket: :reporting, rate_limit_message: "**Woah there.** You must wait %time% seconds before attempting to report again.") do |event, message|
    event.message.delete unless event.channel.private?
    
    server = event.bot.server(150_739_077_757_403_137)
    user = event.user.on(server)
    
    if message.nil?
      user.pm 'You must give a message with your report! i.e. `!report "Message" @optionaluser`.'
      return
    end
    
    mod_channel = server.text_channels.find { |t| t.name == 'moderators' }
    # TODO: db stuff
    mod_channel.send_message "**REPORT FROM #{user.mention}:** #{message}"
    
    user.pm "Sent report."
    
    nil
  end
end