module CourseCommands
    extend Discordrb::Commands::CommandContainer
    command(:fixcourses) do |event|
        server = event.bot.server(150739077757403137)
        user = if event.message.mentions.empty? then event.user else event.message.mentions.first end
        user = user.on(server)
        # Get all classes for this student
        query = "SELECT courses.id, courses.title, staffs.last_name FROM courses JOIN students_courses ON students_courses.course_id=courses.id JOIN students ON students.id=students_courses.student_id JOIN staffs ON staffs.id=courses.teacher_id WHERE students.discord_id=#{user.id} AND courses.is_class=1"
        course_roles = []
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
            course_roles << course_role
        end
        user.add_role(course_roles)
    end
    
    # END OF YEAR COMMAND
    command(:endyear) do |event|
        return if event.user.id != event.server.owner.id
        
        puts "Ending the year. Deleting course rooms and channels."
        event.bot.find_channel('announcements').first.send_message "@everyone Removing all traces of school so you can enjoy the summer."
        
        # Remove course rooms
        $db.query("DELETE FROM course_rooms")
        event.server.text_channels.find_all{|c| c.name.start_with?("course-")}.each do |c|
            c.delete
            sleep 1
        end
        
        # Remove course roles
        event.server.roles.find_all{|r| r.name.start_with?("course-")}.each do |r|
            r.delete
            sleep 1
        end
        
        # Remove advisement channels
        #$db.query("SELECT advisement FROM students WHERE verified=1 GROUP BY advisement").map{|result| result['advisement']}.each do |adv|
        #    begin
        #        event.server.roles.find_all{|r| r.name == adv[0..1]}.delete
        #        event.server.text_channels.find{|c| c.name == adv[0..1]}.delete
        #    rescue
        #    
        #    end
        #    
        #    begin
        #        event.server.text_channels.find{|c| c.name == adv}.delete
        #        event.server.roles.find_all{|r| r.name == adv}.delete
        #    rescue
        #        puts "Error removing #{adv}"
        #    end
        #end
        
        puts "Done."
    end
    
    command(:startyear) do |event|
        return if event.user.id != event.server.owner.id
        
        event.bot.find_channel('announcements').first.send_message "It's that time again. Opening course and advisement channels."
    end
end
