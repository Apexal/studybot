require 'date'

DATE_FORMAT = '%Y-%m-%d'.freeze

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
			days_left = 0
		
			closest_day = Time.now.strftime(DATE_FORMAT)
			if $sd[closest_day].nil?
				closest_day = $sd.keys.sort.find_all { |date_str| date_str <= today }.last
			end
			class_days_left = $sd.keys.sort.index(last_day) - $sd.keys.sort.index(closest_day)
		
			lines << "\nThe last day of school is #{last_day}."
			lines << "There are **#{class_days_left}** school days left."
			lines << "There are **#{}** days left."
		
		end
		
		message = event.channel.send_message(lines.join("\n"))
		nil
  end
end

