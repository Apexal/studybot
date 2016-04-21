module CourseCommands
  extend Discordrb::Commands::CommandContainer
  
  command(:course, description: "Create a course text channel. Usage: `!course name`") do |event, name|
	return if name.nil? or event.user.name != "President Mantranga"
	
	if name.length < 4
		event << "Please use a more specific name. i.e. `Latin`"
		return
	end
	
	identifier = $db.escape(name)
	query = "SELECT courses.*, staffs.last_name FROM courses JOIN students_courses ON students_courses.course_id=courses.id JOIN students ON students.id=students_courses.student_id JOIN staffs ON staffs.id=courses.teacher_id WHERE students.discord_id=#{event.user.id} AND courses.title LIKE '%#{name}%'"
	#courses = $db.query("SELECT courses.*, staffs.last_name FROM courses JOIN students_courses ON students_courses.course_id=courses.id JOIN students ON students.id=students_courses.student_id WHERE students.discord_id=#{event.user.id} AND courses.title LIKE '%#{name}%'")
	courses = $db.query(query)
	if courses.count == 0
		event << "No course found!"
		return
	end
	
	
	
	course = courses.first
	course_name = course['title'].split(" (")[0].split(" ").join("-")
	['IV', 'III', 'II', 'I', '9', '10', '11', '12'].each {|i| course_name.gsub!("-#{i}", "") }

	event.channel.send_message "Creating text-channel for #{course['title']} with #{course['last_name']}..."
	
	puts "Creating text-channel for #{course['title']} with #{course['last_name']}..."
	
	course_role = event.server.roles.find{|r| r.name == "course-#{course['id']}"}
	if course_role.nil?
		course_role = event.server.create_role
		course_role.name = "course-#{course['id']}"
		
		$db.query("SELECT students.username, students.discord_id FROM students RIGHT JOIN students_courses ON students_courses.student_id=students.id WHERE students_courses.course_id=#{course['id']}").each do |row|
			if row['discord_id'].nil?
				next
			end
			if (event.bot.user(row['discord_id']).nil? == false)
				event.bot.user(row['discord_id']).on(event.server).add_role course_role
			end
			sleep 1
		end
	end
	
	if event.user.role?(course_role) == false
		event.user.add_role(course_role)
	end
	
	bots_role_id = event.server.roles.find { |r| r.name == 'bots' }.id
	
	course_rooms = $db.query("select room_id from course_rooms where course_id=#{course['id']}")
	if course_rooms.count == 0
		course_room = event.server.create_channel course_name
		$db.query("insert into course_rooms (course_id, room_id) values (#{course['id']}, #{course_room.id})")
		
		perms = Discordrb::Permissions.new
		perms.can_read_messages = true
		perms.can_send_messages = true
		perms.can_read_message_history = true
		perms.can_mention_everyone = true
		
		course_room.topic = "Disscussion room for #{course['title']} with #{course['last_name']}."
		
		course_room.define_overwrite(course_role, perms, 0)
		Discordrb::API.update_role_overrides(event.bot.token, course_room.id, bots_role_id, perms.bits, 0) # bots
		Discordrb::API.update_role_overrides(event.bot.token, course_room.id, event.server.id, 0, perms.bits) # @everyone
	end
	
	puts "Done!"
	
	"Done!"
  end
end
