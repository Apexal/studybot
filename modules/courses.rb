module CourseCommands
  extend Discordrb::Commands::CommandContainer
  
  command(:fixcourses) do |event|
	server = event.bot.server(150739077757403137)
	user = if event.message.mentions.empty? then event.user else event.message.mentions.first end
	user = user.on(server)
	# Get all classes for this student
	query = "SELECT courses.id, courses.title, staffs.last_name FROM courses JOIN students_courses ON students_courses.course_id=courses.id JOIN students ON students.id=students_courses.student_id JOIN staffs ON staffs.id=courses.teacher_id WHERE students.discord_id=#{user.id} AND courses.is_class=1"
	$db.query(query).each do |course|
		# Ignore unnecessary classes
		if course['title'].include? "Phys " or course['title'].include? "Guidance " or course['title'].include? "Speech " or course['title'].include? "Advisement " or course['title'].include? "Health " or course['title'].include? "Amer "
			next
		end
		
		# Create course role if not exist
		course_role = server.roles.find{|r| r.name == "course-#{course['id']}"}
		if course_role.nil?
			course_role = server.create_role
			course_role.name = "course-#{course['id']}"
		end
		
		# Add that lovely course role m8
		user.add_role(course_role)
		sleep 1
	end
  end
  
  command(:cleancourses) do |event|
	return if event.user.name != "President Mantranga"
	
	$db.query("DELETE FROM course_rooms")
	event.server.text_channels.find_all{|c| c.name.start_with?("course-")}.each do |c|
		c.delete
		sleep 0.5
	end
	
  end
end
