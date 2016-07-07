module RegistrationEvents
    extend Discordrb::EventContainer
    member_leave do |event|
        event.server.owner.pm "#{event.user.mention} has left!"
        $db.query("UPDATE students SET verified=0 WHERE discord_id='#{event.user.id}'")
    end
    member_join do |event|
        event.bot.find_channel('meta').first.send_message "#{event.server.owner.mention} #{event.user.name} just joined the server!"
        sleep 5
        m = event.bot.find_channel('welcome').first.send_message "#{event.user.mention} Hello! Please check your Direct Messages (top left) to get started!"
        event.user.pm "Welcome! Please type `!register yourregisusername` to get started. *You will not be able to participate in the server until you do this.*"
        sleep 100
        m.delete
    end
end

module RegistrationCommands
    extend Discordrb::Commands::CommandContainer

    command(:register, description: "Connect your account to your Regis account. Usage: `!register regisusername`") do |event, username|
        # Check if username was passed and that its not a teacher's email
        if !!username && /^[a-z]+\d{2}$/.match(username)
            # Convert the hex username back to its string
            code = username.each_byte.map { |b| b.to_s(16) }.join

            # Send a welcome email with the command to verify
            mail = Mail.new do
                from "Regis Discord Server <#{$CONFIG["auth"]["gmail"]["username"]}@gmail.com>"
                to      "#{username}@regis.org"
                subject 'Verify Your Discord Account'

                text_part do
                    body "Welcome to Discord, please verify your identity on the server by private messaging studybot '!verify #{code}' (no quotes)'."
                end

                html_part do
                    content_type 'text/html; charset=UTF-8'
                    body "<h1>Regis Discord Server</h1><img src='https://cdn.discordapp.com/attachments/150739077757403137/152977845621096449/flag.png'><br><p>Welcome to Discord, <b>#{event.user.name}</b>!<br> Please verify your identity on the server by sending <i>@studybot</i> the following message. After this you will be able to participate.</p> <code>!verify #{code}</code> <br><p><i>If you did not attempt to register on the server, someone is trying to impersonate you.</i></p>"
                end
            end
            mail.deliver!

            # Alert the user to the email
            event.user.pm('Please check your Regis email for further instructions. https://owa.regis.org/owa/')
            return
        else
            event.user.pm('Invalid username! Please use your Regis username.')
            return
        end
    end

    command(:verify, description: 'Verifies your identity with the emailed code.') do |event, code|
        server = event.bot.server(150739077757403137)
        user = event.user.on(server)
        puts "Attempting to verify #{user} (#{event.user.name})"
        # Make sure they passed a code!
        if code != nil
            # Change hex code back into characters
            username = code.scan(/../).map { |x| x.hex.chr }.join

            # Escape string since techinally anything can be in there
            escaped = $db.escape(username)

            # Find an unverified user with that username
            result = $db.query("SELECT * FROM students WHERE username='#{escaped}' AND verified=0")

            # If that guy exists
            if result.count > 0
                result = result.first
                roles_to_add = []

                # Add 'verified' role
                puts "Adding 'verified' role"
                vrole = server.roles.find{|r| r.name == "verified"}
                roles_to_add << vrole
                # Decide grade for role
                digit = result['advisement'][0].to_i
                rolename = 'Freshmen'
                if digit == 2
                    rolename = 'Sophomores'
                elsif digit == 3
                    rolename = 'Juniors'
                elsif digit == 4
                    rolename = 'Seniors'
                end
                puts "Adding '#{rolename}' role"
                # Add grade role
                grole = server.roles.find { |r| r.name == rolename }
                roles_to_add << grole
                sleep 0.5
                bots_role_id = server.roles.find { |r| r.name == 'bots' }.id

                # Advisement channel handling
                token = event.bot.token
                # Perms for course text-channels
                perms = Discordrb::Permissions.new
                perms.can_read_messages = true
                perms.can_send_messages = true
                perms.can_read_message_history = true
                perms.can_mention_everyone = true
                large_adv = result['advisement'][0..1]
                small_adv = result['advisement']
                # Add the roles for each adv and create channels for each
                [large_adv, small_adv].each do |a|
                    advrole = server.roles.find { |r| r.name == a }
                    # Create role if doesn't exist
                    if advrole.nil?
                        puts "Creating role"
                        advrole = server.create_role
                        advrole.name = a
                        advrole.hoist = true if a.length <= 2 # This should only hoist large advisement roles
                    end
                    # Add role
                    puts "Adding role"
                    roles_to_add << advrole
                    # Advisement channel
                    puts "Finding channel"
                    adv_channel = event.bot.find_channel(a.downcase).first
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
                    sleep 1
                end


                # THE GOOD STUFF
                # Get all classes for this student
                query = "SELECT courses.id, courses.title, courses.room_id, staffs.last_name FROM courses JOIN students_courses ON students_courses.course_id=courses.id JOIN students ON students.id=students_courses.student_id JOIN staffs ON staffs.id=courses.teacher_id WHERE students.discord_id=#{event.user.id} AND courses.is_class=1"
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

                # Default groups
                $db.query("SELECT room_id, role_id FROM groups WHERE default_group=1").each do |group|
                    group_role = server.roles.find{|r| r.id==Integer(group['role_id']) }
                    if !group_role.nil?
                        roles_to_add << group_role
                    end
                end

                user.add_role roles_to_add

                # PM him a congratulatory message
                user.pm("Congratulations, **#{result['first_name']}**. You are now a verified Regis Discord User!")
                # Make an announcement welcoming him to everyone
                event.bot.find_channel('announcements').first.send_message "@everyone Please welcome **#{result['first_name']} #{result['last_name']}** of **#{result['advisement']}** *(#{event.user.mention})* to the Discord Server!"

                user.pm "You can choose to join default or user-made groups with `!groups`. Try it out here!"

                # Set his discord_id and make him verified in the db
                $db.query("UPDATE students SET discord_id='#{user.id}', verified=1 WHERE username='#{escaped}'")
            else
                user.pm('Incorrect code!')
            end
        end

        nil
    end
end
