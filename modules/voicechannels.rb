module VoiceChannelEvents
  extend Discordrb::EventContainer
	
	voice_state_update do |event|
		server = event.server
		
		rooms = server.channels.find_all { |c| c.voice? and c.name.include?('Room') }
		rooms.each do |r|
			if r.users.empty? and r.name != "Open Room"
				r.delete
			else
				if r.name == "Open Room" and !r.users.empty?
					teachers = $db.query("SELECT staffs.last_name FROM staffs JOIN courses ON courses.teacher_id=staffs.id JOIN students_courses ON students_courses.course_id=courses.id JOIN students ON students.id=students_courses.student_id WHERE students.discord_id=#{event.user.id}").map { |t| t['last_name'] }.uniq
					randteacher = teachers.sample
					
					while server.channels.find { |c| c.name == "Room #{randteacher}" } != nil
						randteacher = teachers.sample
					end
					r.name = "Room #{randteacher}"
					
					event.server.create_channel("Open Room", 'voice')
				end
			end
		end
	end
end
