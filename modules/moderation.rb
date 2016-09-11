require 'date'

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
  
  command(:strikes, min_args: 0, max_args: 1, description: '', permission_level: 1) do |event|
    event.message.delete unless event.channel.private?
    server = event.bot.server(150_739_077_757_403_137)
    user = event.user.on(server)

    if !event.message.mentions.empty? and (!user.role? server.roles.find { |r| r.name == 'Moderators' } or user.id != server.owner.id)
      user.pm 'Only moderators can view strikes on other users!'
      return
    end

    target = event.message.mentions.empty? ? user : event.message.mentions.first.on(server)

    strikes = $db.query("SELECT reason, added_date FROM strikes WHERE discord_id='#{target.id}'")
    list = strikes.count > 0 ? strikes.map { |row| "`-` #{row['reason']} (#{row['added_date']})" } : ["*None!*"]
    
    info = []
    info << "\n__**Server Rule Violation Info**__"
    info << "1st — *Warning*"
    info << "2nd — *Warning*"
    info << "3rd — *Text mute for 1 day*"
    info << "4th — *1 week ban*"
    info << "5th and more — *1 month ban (each time)*"
    
    user.pm ":warning: **Your Active Strikes** (#{strikes.count}) :warning:\n#{list.join "\n"}\n#{info.join "\n"}"
    
    nil
  end
  
  command(:strike, min_args: 2, max_args: 2, description: 'Add a strike to a user for a rule violation.', usage: '`!strike "reason" @user` (in quotes!)', permission_level: 2) do |event, reason|
    event.message.delete unless event.channel.private?
    server = event.bot.server(150_739_077_757_403_137)
    
    user = event.user.on(server)
    
    if reason.empty? or reason.length <= 5
      event.user.pm 'Reason is too short!'
      return
    end
    
    target = event.message.mentions.first
    unless target.nil?
      target = target.on(server)
      unless target.role? server.roles.find { |r| r.name == 'Verified' } 
        event.user.pm 'You can only give a strike to verified users.'
        return
      end
      
      $db.query("INSERT INTO strikes (discord_id, reason, added_date) VALUES ('#{target.id}', '#{reason}', '#{DateTime.now}')")
      strike_count = $db.query("SELECT reason, added_date FROM strikes WHERE discord_id='#{target.id}'").count
      
      server.owner.pm "#{target.mention} has received a strike, bringing them to #{strike_count}."
      
      target.pm ":warning: **YOU HAVE BEEN GIVEN STRIKE ##{strike_count} BY A MODERATOR FOR THE FOLLOWING REASON** :warning: \n'#{reason}'\n*Use `!strkes` to see all of your existing strikes and the punishments.*"
    else
      
    end
    
    event.bot.find_channel('moderators').first.send_message "**#{target.mention} was given strike ##{} by Moderator #{user.mention} for reason:**\n'#{reason}'"
    nil
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
      #puts row['name']
      role = server.roles.find { |r| r.id == Integer(row['role_id']) }

      channel_name = row['name']
      channel_name.downcase!
      channel_name.strip!
      channel_name.gsub!(/\s+/, '-')
      channel_name.gsub!(/[^\p{Alnum}-]/, '')


      channel = server.text_channels.find { |t| t.name == channel_name }
      puts channel.name
      puts channel.id
      if channel.nil?
        puts channel_name + " NOOOOOPE"
        next
      end
      $db.query("UPDATE groups SET room_id='#{channel.id}' WHERE role_id='#{role.id}'")
      sleep 1
      next
      
      # GROUP CHANNEL IS MISSING!
      if channel.nil?
        puts 'Creating text-channel.'
        channel = server.create_channel row['name']
        channel.define_overwrite(role, g_perms, other_p)
        Discordrb::API.update_role_overrides($token, channel.id, server.id, 0, perms.bits)
        
      else
        puts 'Already has text-channel.'
      end
      channel.topic = row['description']

      sleep 0.5
    end
    puts 'Done.'
    
    return

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
    lost = server.members.find_all { |m| m.roles.empty? }
    puts "#{lost.length} lost boys"
    lost.each do |m|
      puts "#{m.display_name} #{m.id}"
      
      begin
        m.pm #'Hey! You haven\'t registered yet! You can\'t use anything in the server until you do this. Just send me the message `!register regisusername` (with your Regis username).'
      rescue
        puts 'Nope!'
      end
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