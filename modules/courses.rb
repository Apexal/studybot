module CourseCommands
  extend Discordrb::Commands::CommandContainer

  command(:teachers, min_args: 0, max_args: 1, description: 'List your teachers or another student\'s teachers.', usage: '`!teachers` or `!teachers @student`', permission_level: 1) do |event|
    to_delete = [event.message]

    user = event.message.mentions.empty? ? event.user : event.message.mentions.first
    message = []

    username = nil
    $db.query("SELECT students.username, courses.title, staffs.last_name FROM staffs JOIN courses ON courses.teacher_id=staffs.id JOIN students_courses ON students_courses.course_id=courses.id JOIN students ON students.id=students_courses.student_id WHERE students.discord_id=#{user.id} AND courses.is_class=1").each do |row|
      username = row['username']
      message << "`-` #{row['title']}: *#{row['last_name']}*"
    end
    if username.nil?
      event.message.delete unless event.channel.private?
      event.user.pm 'Invalid user!'
      return
    end
    to_delete << event.channel.send_message("**Teacher List for #{username}**")
    to_delete << event.channel.send_message(message.join "\n")

    sleep 60 * 3
    begin;to_delete.map(&:delete);rescue;end
    nil
  end

  # END OF YEAR COMMAND
  command(:endyear, permission_level: 3) do |event|
    puts 'Ending the year. Deleting course rooms and channels.'
    #event.bot.find_channel('announcements').first.send_message "@everyone Removing all outdated roles/text-channels."
    # Remove course rooms
    $db.query('SELECT room_id FROM courses WHERE room_id IS NOT NULL').each do |row|
      begin
        event.server.text_channels.find{ |c| c.id == Integer(row['room_id']) }.delete
        sleep 0.5
      rescue
        puts "No room #{row['room_id']}"
      end
    end
    $db.query('UPDATE courses SET room_id=NULL WHERE room_id IS NOT NULL')

    puts 'Removing advisement channels'
    $db.query("SELECT advisement FROM students WHERE verified=1 GROUP BY advisement").map{|result| result['advisement']}.each do |adv|
      roles = event.server.roles.find_all { |r| r.name.start_with? adv or r.name.start_with? adv[0..1] }
      roles.each do |role|
        puts "Removing role #{role.name}"
        role.delete
      end

      channels = event.server.text_channels.find_all { |c| c.name.downcase.start_with?(adv[0..1].downcase) }
      channels.each do |channel|
        puts "Removing text-channel for #{channel.name}"
        begin
          channel.delete
        rescue
          puts 'Failed...?'
        end
      end

    end
    puts 'Done.'
    
    puts 'Removing grade channels'
    %w(Freshmen Sophomores Juniors Seniors).each do |g|
      begin
        g_role = event.server.roles.find { |r| r.name == g }
        event.server.members.each do |m|
          next unless m.role? g_role
          m.remove_role g_role
          sleep 1
        end
        
        event.server.text_channels.find { |t| t.name == g.downcase }.delete
      rescue => e
        puts "Failed for #{g}"
        puts e
      end
      sleep 1
    end
  end

  command(:updatecourses, permission_level: 3) do |event|
    server = event.bot.server(150_739_077_757_403_137)

    # Perms for course text-channels
    perms = Discordrb::Permissions.new
    perms.can_read_messages = true
    perms.can_send_messages = true
    perms.can_read_message_history = true
    perms.can_mention_everyone = true

    bots_role_id = server.roles.find { |r| r.name == 'bots' }.id

    discord_id = !event.message.mentions.empty? ? " AND discord_id='#{event.message.mentions.first.id}'" : ''
    
    adv_roles = server.roles.find_all { |r| %w(1 2 3 4).include? r.name[0] }
    puts "#{adv_roles.length} advisement roles detected"

    $db.query("SELECT username, discord_id, advisement FROM students WHERE verified=1#{discord_id}").each do |row|
      puts "\n ---------- [HANDLING #{row['username']} of #{row['advisement']}] ----------"
      user = server.member(row['discord_id'])
      
      if user.nil?
        puts 'User isn\'t on server!'
        next
      end

      large_adv = row['advisement'][0..1]
      small_adv = row['advisement']

      adv_roles = server.roles.find_all { |r| %w(1 2 3 4).include? r.name[0] }

      # Add the roles for each adv and create channels for each
      [large_adv, small_adv].each do |a|
        puts "#{a}:"
        advrole = adv_roles.find { |r| r.name == a }

        # Remove old roles
        adv_roles.find_all { |r| !r.name.start_with? a[0..1] and user.role? r }.each do |r|
          puts "Removing old advisement role #{r.name}"
          user.remove_role r
          sleep 0.5
        end

        # Create role if doesn't exist
        if advrole.nil?
          puts 'Creating role'
          advrole = server.create_role
          advrole.name = a
          advrole.hoist = true if a.length <= 2 # This should only hoist large advisement roles
          
        else
          puts "Room for #{a} exists already"
        end
        if !user.role? advrole
          # Add role
          puts 'Adding role'
          user.add_role advrole
        else
          puts "Already has role for #{a}"
        end

        # Advisement channel
        puts 'Finding channel'
        adv_channel = server.text_channels.find { |c| c.name == a.downcase }
        if adv_channel.nil?
          # Create if not exist
          puts 'Creating channel'
          adv_channel = server.create_channel(a)
          adv_channel.topic = "Private chat for Advisement #{a}"
          puts 'Updating perms'
          Discordrb::API.update_role_overrides($token, adv_channel.id, server.id, 0, perms.bits) # @everyone
          Discordrb::API.update_role_overrides($token, adv_channel.id, advrole.id, perms.bits, 0) # advisement role
          Discordrb::API.update_role_overrides($token, adv_channel.id, bots_role_id, perms.bits, 0) # bots
        end
        sleep 0.5
      end

      # Grade channel handling
      puts 'Handling grade channels'
      digit = row['advisement'][0].to_i
      rolename = 'Freshmen'
      if digit == 2
        rolename = 'Sophomores'
      elsif digit == 3
        rolename = 'Juniors'
      elsif digit == 4
        rolename = 'Seniors'
      end

      %w(Freshmen Sophomores Juniors Seniors).each do |grade|
        grole = server.roles.find{ |r| r.name == grade }

        next if grole.nil? # Should never happen

        if grade == rolename
          user.add_role grole
          puts "Added #{grade} role"
        elsif user.role? grole
          user.remove_role(grole) if user.role?(grole)
          puts "Removing #{grade} role"
        end
      end

      # THE GOOD STUFF
      # Get all classes for this student
      query = "SELECT courses.id, courses.title, courses.room_id, staffs.last_name FROM courses JOIN students_courses ON students_courses.course_id=courses.id JOIN students ON students.id=students_courses.student_id JOIN staffs ON staffs.id=courses.teacher_id WHERE students.discord_id=#{user.id} AND courses.is_class=1"
      
      #unless summer?
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
          # course_room.define_overwrite(user, perms, 0)
          Discordrb::API.update_user_overrides(event.bot.token, course_room.id, user.id, perms.bits, 0)

          $db.query("UPDATE courses SET room_id='#{course_room.id}' WHERE id=#{course['id']}")
          sleep 0.5
        end
      #end

    end
    puts "Done."

    nil
  end
end
