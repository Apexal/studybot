module CourseCommands
  extend Discordrb::Commands::CommandContainer
  
  command(:cleancourses) do |event|
	return if event.user.name != "President Mantranga"
	
	$db.query("DELETE FROM course_rooms")
	event.server.text_channels.find_all{|c| c.name.start_with?("course-")}.each do |c|
		c.delete
		sleep 0.5
	end
	
  end
end
