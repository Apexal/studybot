module VoiceChannelEvents
	extend Discordrb::EventContainer
	
	hierarchy = Hash.new
	
	voice_state_update do |event|
		server = event.server
		
		perms = Discordrb::Permissions.new
		perms.can_read_message_history = true
		perms.can_read_messages = true
		perms.can_send_messages = true
		
		if event.channel != nil and !['Music', 'AFK'].include? event.channel.name
			text_channel = server.text_channels.find { |c| c.id == hierarchy[event.channel.id] }
			
			if text_channel == nil
				text_channel = event.server.create_channel "voice-channel"
				text_channel.topic = "Private chat for all those in your voice channel."
				Discordrb::API.update_role_overrides(event.bot.token, text_channel.id, server.id, 0, perms.bits)
				hierarchy[event.channel.id] = text_channel.id
			end
			
			Discordrb::API.update_user_overrides(event.bot.token, text_channel.id, event.user.id, perms.bits, 0)
		else
			hierarchy.each do |voice_id, text_id|
				Discordrb::API.update_user_overrides(event.bot.token, text_id, event.user.id, 0, 0)
			end
		end
		
		# Room Naming/Open Room Handling
		rooms = server.voice_channels.find_all { |c| c.name.include?('Room') }
		rooms.each do |r|
			if r.users.empty? and r.name != "Open Room"
				server.text_channels.find{|t| t.id == hierarchy[r.id]}.delete
				r.delete
				hierarchy.delete r.id
			else
				if r.name == "Open Room" and !r.users.empty?
					teachers = $db.query("SELECT staffs.last_name FROM staffs JOIN courses ON courses.teacher_id=staffs.id JOIN students_courses ON students_courses.course_id=courses.id JOIN students ON students.id=students_courses.student_id WHERE students.discord_id=#{event.user.id}").map { |t| t['last_name'] }.uniq
					randteacher = teachers.sample

					while server.voice_channels.find { |c| c.name == "Room #{randteacher}" } != nil
						randteacher = teachers.sample
					end
					r.name = "Room #{randteacher}"

					c = event.server.create_channel("Open Room", 'voice')
				end
			end
		end
	end
end
