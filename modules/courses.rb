module CourseCommands
    extend Discordrb::Commands::CommandContainer
    skippable = ['phys', 'guidance', 'speech', 'advisement', 'health', 'amer']
    command(:fixcourses) do |event|
        event << "Not done."
        return
        server = event.bot.server(150739077757403137)
        user = if event.message.mentions.empty? then event.user else event.message.mentions.first end
        user = user.on(server)
        # Get all classes for this student
        query = "SELECT courses.id, courses.title, staffs.last_name FROM courses JOIN students_courses ON students_courses.course_id=courses.id JOIN students ON students.id=students_courses.student_id JOIN staffs ON staffs.id=courses.teacher_id WHERE students.discord_id=#{user.id} AND courses.is_class=1"
        course_roles = []
        $db.query(query).each do |course|
            # Ignore unnecessary classes
            skippable.each do |s|
                if course['title'].downcase.include? s
                    next
                end
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
        #event.bot.find_channel('announcements').first.send_message "@everyone Removing all traces of school so you can enjoy the summer."
        # Remove course rooms
        $db.query("SELECT room_id FROM courses WHERE room_id IS NOT NULL").each do |row|
            begin
                event.server.text_channels.find{|c| c.id==Integer(row['room_id'])}.delete
                sleep 0.5
            rescue
                puts "No room #{row['room_id']}"
            end
        end
        $db.query("UPDATE courses SET room_id=NULL WHERE room_id IS NOT NULL")

        #puts "Removing advisement channels" 
        #$db.query("SELECT advisement FROM students WHERE verified=1 GROUP BY advisement").map{|result| result['advisement']}.each do |adv|
        #    if adv[0..1] == "2B" # Happy, Liam?
        #       next
        #    end
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

    command(:updatecourses) do |event|
        return if event.user.id != event.server.owner.id

        server = event.server

        # Perms for course text-channels
        perms = Discordrb::Permissions.new
        perms.can_read_messages = true
        perms.can_send_messages = true
        perms.can_read_message_history = true
        perms.can_mention_everyone = true

        bots_role_id = server.roles.find { |r| r.name == 'bots' }.id

        discord_id = if event.message.mentions.length > 0 then " AND discord_id='#{event.message.mentions.first.id}'" else "" end

        $db.query("SELECT username, discord_id, advisement FROM students WHERE verified=1#{discord_id}").each do |row|
            puts "\n ---------- [HANDLING #{username}] ----------"
            user = server.member(row['discord_id'])
            if user.nil?
                next
            end

            large_adv = row['advisement'][0..1]
            small_adv = row['advisement']
            
            # Add the roles for each adv and create channels for each
            [large_adv, small_adv].each do |a|
                advrole = server.roles.find { |r| r.name == a }
                
                # Create role if doesn't exist
                if advrole.nil?
                    puts "Creating role"
                    advrole = server.create_role
                    advrole.name = a
                    advrole.hoist = true if a.length <= 2 # This should only hoist large advisement roles
                else
                    puts "Room for #{a} exists already"
                end
                
                if !user.role? advrole
                    # Add role
                    puts "Adding role"
                    user.add_role advrole
                else
                    puts "Already has role for #{a}"
                end

                # Advisement channel
                puts "Finding channel"
                adv_channel = server.text_channels.find{|c| c.name==a.downcase}
                if adv_channel.nil?
                    # Create if not exist
                    puts "Creating channel"
                    adv_channel = server.create_channel(a)
                    adv_channel.topic = "Private chat for Advisement #{a}"
                    puts "Updating perms"
                    Discordrb::API.update_role_overrides(token, adv_channel.id, server.id, 0, perms.bits) # @everyone
                    Discordrb::API.update_role_overrides(token, adv_channel.id, advrole.id, perms.bits, 0) # advisement role
                    Discordrb::API.update_role_overrides(token, adv_channel.id, bots_role_id, perms.bits, 0) # bots
                end
                sleep 0.5
            end

            # Grade channel handling
            puts "Handling grade channels"
            digit = row['advisement'][0].to_i
            rolename = 'Freshmen'
            if digit == 2
                rolename = 'Sophomores'
            elsif digit == 3
                rolename = 'Juniors'
            elsif digit == 4
                rolename = 'Seniors'
            end
            ['Freshmen', 'Sophomores', 'Juniors', 'Seniors'].each do |grade|
                grole = server.roles.find{|r| r.name==grade}
                if grole.nil?
                    next
                end
                if grade == rolename
                    user.add_role grole
                else
                    if user.role? grole
                        user.remove_role grole
                    end
                end
            end

            # THE GOOD STUFF
            # Get all classes for this student
            query = "SELECT courses.id, courses.title, courses.room_id, staffs.last_name FROM courses JOIN students_courses ON students_courses.course_id=courses.id JOIN students ON students.id=students_courses.student_id JOIN staffs ON staffs.id=courses.teacher_id WHERE students.discord_id=#{user.id} AND courses.is_class=1"
            $db.query(query).each do |course|
                # Ignore unnecessary classes
                if course['title'].include? "Phys " or course['title'].include? "Guidance " or course['title'].include? "Speech " or course['title'].include? "Advisement " or course['title'].include? "Health " or course['title'].include? "Amer "
                    next
                end
                # Turn something like 'Math II (Alg 2)' into 'math'
                course_name = course['title'].split(" (")[0].split(" ").join("-")
                ['IV', 'III', 'II', 'I', '9', '10', '11', '12'].each {|i| course_name.gsub!("-#{i}", "") }
                
                puts "Handling course room for #{course['title']}"
                course_room = nil
                begin
                    course_room = server.text_channels.find{|c| c.id==Integer(course['room_id']) }
                    if course_room.nil?
                        # Course room doesn't exist
                        puts "Missing room! Creating."
                        course_room = server.create_channel course_name
                        course_room.topic = "Disscussion room for #{course['title']} with #{course['last_name']}."
                        Discordrb::API.update_role_overrides(event.bot.token, course_room.id, server.id, 0, perms.bits) # @everyone
                    end
                rescue
                    puts "Doesn't exist. Creating.'"
                    course_room = server.create_channel course_name
                    course_room.topic = "Disscussion room for #{course['title']} with #{course['last_name']}."
                    Discordrb::API.update_role_overrides(event.bot.token, course_room.id, server.id, 0, perms.bits) # @everyone
                end
                #course_room.define_overwrite(user, perms, 0)
                Discordrb::API.update_user_overrides(event.bot.token, course_room.id, user.id, perms.bits, 0)

                $db.query("UPDATE courses SET room_id='#{course_room.id}' WHERE id=#{course['id']}")

                sleep 0.5
            end
        end
        nil
    end

    command(:startyear) do |event|
        return if event.user.id != event.server.owner.id
        #event.bot.find_channel('announcements').first.send_message "It's that time again. Opening course and advisement channels."
    end
end
