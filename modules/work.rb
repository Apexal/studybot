require 'date'

DATE_FORMAT = '%Y-%m-%d'.freeze


def toggle_studymode(server, user)
  grades = %w(Freshmen Sophomores Juniors Seniors)
  
  studyrole = server.roles.find { |r| r.name == 'studying' }
  user = user.on(server)
  clean_name = user.display_name
  clean_name.sub! '[S] ', ''
  
  # PUBLIC ROOM
  public_room = server.text_channels.find { |t| t.name == 'public-room' }
  groups = $db.query('SELECT * FROM groups')
  
  # Permissions
  perms = Discordrb::Permissions.new
  perms.can_read_messages = true
  perms.can_read_message_history = true
  perms.can_send_messages = true
  
  # WORK CHANNEL
  work_channel = server.text_channels.find { |t| t.name == 'work' }
  work_perms = Discordrb::Permissions.new
  work_perms.can_send_messages = true
  
  if user.role? studyrole
    # LEAVING STUDYMODE
    user.nickname = clean_name
    user.remove_role studyrole
    
    # Public Room
    Discordrb::API.update_user_overrides($token, public_room.id, user.id, 0, 0)
    
    # Work room
    #Discordrb::API.update_user_overrides(event.bot.token, work_channel.id, user.id, 0, 0)
    
    # Issue for grade channels
    grades.each do |g|
      gname = g.downcase
      role = server.roles.find { |r| r.name == g }
      if !role.nil? and user.role? role
        grade_channel = server.text_channels.find { |c| c.name == gname }
        Discordrb::API.update_user_overrides($token, grade_channel.id, user.id, 0, 0)
      end
    end
    groups.each do |row|
      group_role = server.roles.find { |r| r.id == Integer(row['role_id']) }
      next if group_role.nil? or !user.role? group_role

      group_channel = server.text_channels.find{ |c| c.id == Integer(row['room_id']) }
      Discordrb::API.update_user_overrides($token, group_channel.id, user.id, 0, 0)
      #group_channel.define_overwrite(user, 0, 0)
      sleep 0.5
    end

    if !user.voice_channel.nil? and !user.permission? 'can_connect', user.voice_channel
      puts 'Moving to allowed voice-channel'
      server.move user, server.voice_channels.find { |c| c.name == '[New Room]' }
      user.pm 'You were moved into a new voice-channel because your previous one only allowed students in studymode.'
    end
    
    puts "#{user.display_name} exited studymode"
    user.pm 'You have left **studymode**.'
  else
    # GOING INTO STUDYMODE
    user.nickname = "[S] #{clean_name}"[0..30]
    user.add_role studyrole
    
    # Public Room
    Discordrb::API.update_user_overrides($token, public_room.id, user.id, 0, perms.bits)
    
    # Work room
    #Discordrb::API.update_user_overrides($token, work_channel.id, user.id, 0, work_perms.bits)
    
    # Issue for grade channels
    grades.each do |g|
      gname = g.downcase
      role = server.roles.find { |r| r.name == g }
      if !role.nil? and user.role? role
        grade_channel = server.text_channels.find { |c| c.name == gname }
        Discordrb::API.update_user_overrides($token, grade_channel.id, user.id, 0, perms.bits)
        sleep 0.5
      end
    end
    
    groups.each do |row|
      group_role = server.roles.find { |r| r.id == Integer(row['role_id']) }
      next if group_role.nil? or !user.role? group_role
      
      group_channel = server.text_channels.find { |c| c.id == Integer(row['room_id']) }
      puts group_channel.name
      #group_channel.define_overwrite(user, 0, perms)
      Discordrb::API.update_user_overrides($token, group_channel.id, user.id, 0, perms.bits)
      sleep 0.5
    end

    # Check if current voice-channel (if exists) allows studying students and move them if necessary
    unless user.voice_channel.nil? or user.voice_channel.name.include?('Study ')
      puts 'Moving to allowed voice-channel'
      server.move user, server.voice_channels.find { |c| c.name == '[New Room]' }
      user.pm 'You were moved into a new voice-channel because your previous one did not allow students in studymode.'
    end
    
    puts "#{user.display_name} entered studymode"
    user.pm 'You are now in **studymode**! Type `!study` again to leave this mode.'
  end
end

module WorkCommands
  extend Discordrb::Commands::CommandContainer

  grades = %w(Freshmen Sophomores Juniors Seniors)
  command(:study, min_args: 0, max_args: 0, description: 'Toggle your ability to see non-work text channels to focus!', bucket: :study, permission_level: 1) do |event|
    event.message.delete unless event.message.channel.private?

    server = event.bot.server(150_739_077_757_403_137)
    studyrole = server.roles.find { |r| r.name == 'studying' }
    user = event.user.on(server)
    clean_name = user.display_name
    clean_name.sub! '[S] ', ''
    
    # PUBLIC ROOM
    public_room = server.text_channels.find { |t| t.name == 'public-room' }
    groups = $db.query('SELECT * FROM groups')
    
    # Permissions
    perms = Discordrb::Permissions.new
    perms.can_read_messages = true
    perms.can_read_message_history = true
    perms.can_send_messages = true
    
    # WORK CHANNEL
    work_channel = server.text_channels.find { |t| t.name == 'work' }
    work_perms = Discordrb::Permissions.new
    work_perms.can_send_messages = true
    
    if user.role? studyrole
      # LEAVING STUDYMODE
      user.nickname = clean_name
      user.remove_role studyrole
      
      # Public Room
      Discordrb::API.update_user_overrides(event.bot.token, public_room.id, user.id, 0, 0)
      
      # Work room
      #Discordrb::API.update_user_overrides(event.bot.token, work_channel.id, user.id, 0, 0)
      
      # Issue for grade channels
      grades.each do |g|
        gname = g.downcase
        role = server.roles.find { |r| r.name == g }
        if !role.nil? and user.role? role
          grade_channel = server.text_channels.find { |c| c.name == gname }
          Discordrb::API.update_user_overrides(event.bot.token, grade_channel.id, user.id, 0, 0)
        end
      end
      groups.each do |row|
        group_role = server.roles.find { |r| r.id == Integer(row['role_id']) }
        next if group_role.nil? or !user.role? group_role

        group_channel = server.text_channels.find{ |c| c.id == Integer(row['room_id']) }
        Discordrb::API.update_user_overrides(event.bot.token, group_channel.id, user.id, 0, 0)
        #group_channel.define_overwrite(user, 0, 0)
        sleep 0.5
      end

      if !user.voice_channel.nil? and !user.permission? 'can_connect', user.voice_channel
        puts 'Moving to allowed voice-channel'
        server.move user, server.voice_channels.find { |c| c.name == '[New Room]' }
        user.pm 'You were moved into a new voice-channel because your previous one only allowed students in studymode.'
      end
      
      puts "#{user.display_name} exited studymode"
			user.pm 'You have left **studymode**.'
    else
      # GOING INTO STUDYMODE
      user.nickname = "[S] #{clean_name}"[0..30]
      user.add_role studyrole
      
      # Public Room
      Discordrb::API.update_user_overrides(event.bot.token, public_room.id, user.id, 0, perms.bits)
      
      # Work room
      #Discordrb::API.update_user_overrides(event.bot.token, work_channel.id, user.id, 0, work_perms.bits)
      
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
      
      groups.each do |row|
        group_role = server.roles.find { |r| r.id == Integer(row['role_id']) }
        next if group_role.nil? or !user.role? group_role
        
        group_channel = server.text_channels.find { |c| c.id == Integer(row['room_id']) }
        puts group_channel.name
        #group_channel.define_overwrite(user, 0, perms)
        Discordrb::API.update_user_overrides(event.bot.token, group_channel.id, user.id, 0, perms.bits)
        sleep 0.5
      end

      # Check if current voice-channel (if exists) allows studying students and move them if necessary
      unless user.voice_channel.nil? or user.voice_channel.name.include?('Study ')
        puts 'Moving to allowed voice-channel'
        server.move user, server.voice_channels.find { |c| c.name == '[New Room]' }
        user.pm 'You were moved into a new voice-channel because your previous one did not allow students in studymode.'
      end
      
      puts "#{user.display_name} entered studymode"
			user.pm 'You are now in **studymode**! Type `!study` again to leave this mode.'
		end

    nil
  end
  
  command(:school, min_args: 0, max_args: 0, description: "Get info on school.", permission_level: 1) do |event|
		lines = []
		lines << '__**:school: School Info :school_satchel:**__'
		
		now = Date.parse(Time.now.to_s)
		today = now.strftime(DATE_FORMAT)
		
		# Before, or during school year?
		if summer?
			# Before
			school_start = Date.strptime($sd.keys.sort.first, DATE_FORMAT)
			lines << "School starts on **#{school_start.strftime('%A, %B %-d')}**."
			lines << "**#{(school_start - now).to_i}** days left untill then."
		else
			# During
			lines << "Today is #{school_day? ? "**" + get_sd + "-Day**" : 'not a school day'}."
		
			# Get stats
			last_day = $sd.keys.sort.last
			#days_left = (now - $sd.keys.sort.index(last_day)).to_i
		
			closest_day = Time.now.strftime(DATE_FORMAT)
			if $sd[closest_day].nil?
				closest_day = $sd.keys.sort.find_all { |date_str| date_str <= today }.last
			end
			class_days_left = $sd.keys.sort.index(last_day) - $sd.keys.sort.index(closest_day)

			lines << "\nThe last day of school is **#{Date.parse(last_day).strftime('%A, %B %-d')}**."
			lines << "There are **#{class_days_left}** class days left."
			#lines << "There are **#{days_left}** total days left."
		
		end
		
		message = event.channel.send_message(lines.join("\n"))
		nil
  end
end

