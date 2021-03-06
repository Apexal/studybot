require 'securerandom'

module RegistrationEvents
  extend Discordrb::EventContainer
  member_leave do |event|
    event.server.owner.pm "#{event.user.mention} has left!"
    $db.query("UPDATE students SET verified=0 WHERE discord_id='#{event.user.id}'")
  end
  member_join do |event|
    event.bot.find_channel('meta').first.send_message "#{event.server.owner.mention} #{event.user.mention} just joined the server!"
    #event.user.on(event.server).add_role(event.server.roles.find { |r| r.name == 'Guests' } )
    handle_public_room(event.server)

    sleep 3
    m = event.bot.find_channel('welcome').first.send_message "#{event.user.mention} Hello! Please check your Direct Messages (top left) to get started!"
    sleep 1
    event.user.pm '**I am an automated bot for the Student Discord Server.** :robot:'
    sleep 1
    event.user.pm 'Please type `!register yourregisusername`. *You will not be able to participate in the server until you do this.*'
    event.user.pm '**Quickstart Guide** <https://www.youtube.com/watch?v=pynmRmJUDJs>'
    event.server.owner.pm "New user!"
    sleep 60 * 3
    m.delete
  end
end

module RegistrationCommands
  extend Discordrb::Commands::CommandContainer

  welcome_info = File.open('./resources/intro.txt', 'r')

  command(:register, min_args: 1, max_args: 1, description: 'Connect your account to your Regis account.', usage: '`!register regisusername`') do |event, username|
    server = event.bot.server(150_739_077_757_403_137)
    # Check if username was passed and that its not a teacher's email
    if !!username && /^[a-z]+\d{2}$/.match(username)
      username = $db.escape(username)
      puts "Attempting to send register email to #{username}..."
      # Check if already verified
      check = $db.query("SELECT verified as count FROM students WHERE username='#{username}'").first
      if check.nil?
        puts 'Invalid username'
        event.user.pm "That is an invalid Regis username."
        return
      elsif check['verified'] == 1
        puts 'Already registered.'
        event.user.pm "Somebody has already registered as **#{username}**. If it was not you, please alert #{server.owner.mention} immediately."
        return
      end

      # Convert the hex username back to its string
      #code = username.each_byte.map { |b| b.to_s(16) }.join
      
      code = SecureRandom.hex # Make random hex code

      $db.query("INSERT INTO discord_codes VALUES ('#{event.user.id}', '#{code}', '#{username}') ON DUPLICATE KEY UPDATE code='#{code}'")
      # Send a welcome email with the command to verify
      mail = Mail.new do
        from "Student Discord Server <#{$CONFIG['auth']['gmail']['username']}@gmail.com>"
        to      "#{username}@regis.org"
        subject 'Verify Your Discord Account'

        text_part do
          body "Welcome to Discord, please verify your identity on the server by private messaging studybot '!verify #{code}' (no quotes)'."
        end

        html_part do
          content_type 'text/html; charset=UTF-8'
          body "<h1>Student Discord Server</h1><img src='https://cdn.discordapp.com/attachments/150739077757403137/152977845621096449/flag.png'><br><p>Welcome to Discord, <b>#{event.user.name}</b>!<br> Please verify your identity on the server by sending <i>@studybot</i> the following message. After this you will be able to participate.</p> <code>!verify #{code}</code> <br><p><i>If you did not attempt to register on the server, someone is trying to impersonate you.</i></p>"
        end
      end
      mail.deliver!

      # Alert the user to the email
      event.user.pm('**Great!** Please check your Regis email to finish. https://owa.regis.org/owa/')
      puts 'Done.'
    else
      event.user.pm('Invalid username! Please use your Regis username.')
    end

    nil
  end

  command(:verify, min_args: 1, max_args: 2, description: 'Verifies your identity with the emailed code.', usage: '`!verify code`') do |event, code|
    event.message.delete unless event.channel.private?

    server = event.bot.server(150_739_077_757_403_137)
    user = event.user.on(server)

    user = event.message.mentions.first.on(server) if !event.message.mentions.empty? and event.user.id == server.owner.id

    puts "Attempting to verify #{user} (#{user.name})"

    status_message = user.pm.send_message('Registering...')

    # Make sure they passed a code!
    unless code.nil?
      # Change hex code back into characters
      code = $db.escape(code)
      u = $db.query("SELECT username, code FROM discord_codes WHERE code = '#{code}'").first
      if u.nil?
        user.pm 'Incorrect code!'
        puts 'Incorrect code!'
        return
      end
      username = u['username']

      # Escape string since techinally anything can be in there
      escaped = $db.escape(username)

      # Check if user is already registered with another Discord account
      if $db.query("SELECT verified FROM students WHERE username='#{escaped}' AND verified=1").count > 0
        user.pm "You are already registered on this server with another Discord account!\nAsk Frank (<@152621041976344577>) to reset this for you if you forgot the password for that account."
        puts 'Already registered'
        return
      end

      # Find an unverified user with that username
      result = $db.query("SELECT * FROM students WHERE username='#{escaped}' AND verified=0")

      # If that guy exists
      if result.count > 0
        result = result.first
        roles_to_add = []

        # Add 'Verified' role
        vrole = server.roles.find{|r| r.name == 'Verified'}
        roles_to_add << vrole

        #unless summer?
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
              puts 'Creating role'
              advrole = server.create_role
              advrole.name = a
              advrole.hoist = true if a.length <= 2 # This should only hoist large advisement roles
            end
            # Add role
            puts 'Adding role'
            roles_to_add << advrole
            # Advisement channel
            puts 'Finding channel'
            adv_channel = event.bot.find_channel(a.downcase).first
            if adv_channel.nil?
              # Create if not exist
              puts 'Creating channel'
              adv_channel = server.create_channel(a)
              adv_channel.topic = "Private chat for Advisement #{a}"
              adv_channel.position = server.text_channels.find_all { |t| %w(1 2 3 4).include? t.name[0] }.sort { |a, b| a.position <=> b.position }.last.position - 1

              pos = server.text_channels.find_all { |c| c.name.start_with? a[0] }.sort { |a, b| a.position <=> b.position }.last.position + 1
              adv_channel.position = pos # This keeps advisement channels above group channels
              puts 'Updating perms'
              Discordrb::API.update_role_overrides(token, adv_channel.id, server.id, 0, perms.bits) # @everyone
              Discordrb::API.update_role_overrides(token, adv_channel.id, advrole.id, perms.bits, 0) # advisement role
              Discordrb::API.update_role_overrides(token, adv_channel.id, bots_role_id, perms.bits, 0) # bots
            end
            sleep 1
            break if a[0] == '4'
          end

          # THE GOOD STUFF
          # Get all classes for this student
        unless summer?
          query = "SELECT courses.id, courses.title, courses.room_id, staffs.last_name FROM courses JOIN students_courses ON students_courses.course_id=courses.id JOIN students ON students.id=students_courses.student_id JOIN staffs ON staffs.id=courses.teacher_id WHERE students.username='#{escaped}' AND courses.is_class=1"
          $db.query(query).each do |course|
            # Ignore unnecessary classes
            next if $unallowed.any? { |w| course['title'].include? w } # Honestly Ruby is great

            # Turn something like 'Math II (Alg 2)' into 'math'
            course_name = course['title'].split(' (')[0].split(' ').join('-')
            course_name.gsub!(/\W+/, '-')
            %w(IV III II I 9 10 11 12).each { |i| course_name.gsub!("-#{i}", '') }
            puts "Handling course room for #{course['title']}"
            course_room = nil
            begin
              course_room = server.text_channels.find { |c| c.id == Integer(course['room_id']) }
              if course_room.nil?
                # Course room doesn't exist
                puts 'Missing room! Creating.'
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
        #end

        # Default groups
        $db.query('SELECT room_id, role_id FROM groups WHERE default_group=1').each do |group|
          group_role = server.roles.find{ |r| r.id == Integer(group['role_id']) }
          roles_to_add << group_role unless group_role.nil?
        end

        roles_to_add.each do |r|
          puts "Adding role #{r.name}"
          begin
            user.add_role(r)
          rescue => e
            puts 'FAILED!'
            puts e
          end
          sleep 1
        end

        user.remove_role(server.roles.find { |r| r.name == 'Guests' })

        # PM him a congratulatory message
        status_message.edit("**Congratulations, #{result['first_name']}. You are now a verified user!** *Please remember that this is not an official Regis server and is totally student-run.*")
        # Make an announcement welcoming him to everyone
        event.bot.find_channel('announcements').first.send_message "@everyone Please welcome **#{result['first_name']} #{result['last_name']}** of **#{result['advisement']}** *(#{user.mention})* to the Discord Server!"
        
        
        welcome_info.each_line do |line|
          begin
            user.pm(line)
            sleep 4
          rescue
            puts "Failed sending line: #{line}"
          end
        end
        
        begin
        event.bot.find_channel(result['advisement'][0..1].downcase).first.send_message "@everyone **#{result['first_name']} #{result['last_name']}** from your advisement has joined!"
        rescue;puts 'Couldn\'t announce to advisement channel.';end
        
        # Set his discord_id and make him verified in the db
        $db.query("UPDATE students SET discord_id='#{user.id}', verified=1 WHERE username='#{escaped}'")
      else
        user.pm('Incorrect code!')
      end
    end
    puts 'DONE.'
    #sort_channels(server)

    nil
  end
end
