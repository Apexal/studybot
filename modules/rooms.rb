module RoomEvents
  extend Discordrb::EventContainer

  
end

module RoomCommands
  extend Discordrb::Commands::CommandContainer

  # List of special channels
  joinable = %w(gaming memes meta testing)

  command(:join, description: 'Join a special channel. Usage: `!join channelname`') do |event, channel_name|
    server = event.bot.server(150739077757403137)

    if !event.channel.private?
      channel = server.channels.find { |c| c.name == channel_name }

      if !channel.nil? && joinable.include?(channel_name)
        Discordrb::API.update_user_overrides(event.bot.token, channel.id, event.user.id, 0, 0)
		event.message.reply "You have joined #{channel.mention}!"
      else
        event.message.reply "You can only join/leave **#{joinable.join ', '}**. Try `!join memes`"
      end
    else
      event.user.pm "`!join` and `!leave` are only available in PM's. Try using them here!"
      event.message.delete
    end

    nil
  end

  command(:leave, description: 'Leave a special channel. Usage: `!leave channel') do |event, channel_name|
    server = event.bot.server(150739077757403137)

    if !event.channel.private?
      channel = server.channels.find { |c| c.name == channel_name }

      if !channel.nil? && joinable.include?(channel_name)
        deny_perms = Discordrb::Permissions.new
        deny_perms.can_read_messages = true
        deny_perms.can_send_messages = true
        deny_perms.can_read_message_history = true
        deny_perms.can_mention_everyone = true

        Discordrb::API.update_user_overrides(event.bot.token, channel.id, event.user.id, 0, deny_perms.bits)
        event.message.reply "You have left #{channel.mention}!"
      else
        event.message.reply "You can only join/leave **#{joinable.join ', '}**. Try `!leave memes`"
      end
    else
      event.send_message "`!join` and `!leave` are only available in the server! Try in #meta"
      event.message.delete
    end

    nil
  end
  
  command :test do |event|
    adv = $db.query("SELECT advisement FROM students WHERE discord_id=#{event.user.id}")
    
    if adv.count == 0
      return
    end
    adv = adv.first["advisement"]
    teachers = $db.query("SELECT staffs.last_name FROM staffs JOIN courses ON courses.teacher_id=staffs.id JOIN students_courses ON students_courses.course_id=courses.id JOIN students ON students.id=students_courses.student_id WHERE students.discord_id=#{event.user.id}").map { |t| t['last_name'] }.uniq
    
    grades = {"1" => ["9", "I"], "2" => ["10", "II"], "3" => ["11", "III"], "4" => ["12", "IV"]}
    
    used = grades[adv[0]]
    unused = []
    puts grades[adv[0]]
    
    grades.each do |i, g| 
      puts "#{i} vs #{adv[0]}"
      if i != adv[0]
        g.each {|c| unused << c }
      end
    end
    
    
    useful = $events.find_all { |e| adv.include? e[:adv] and teachers.include? e[:teacher] and e[:date] > (DateTime.now - 1)}
  
    useful.each do |e|
      skip = false 
      unused.each do |text|
        if e[:course].split(" ").include? text
          skip = true
        end
      end
      
      if !skip
        name = e[:course].split(" ")[0]
        name = "#{e[:adv]}-#{name}-test".downcase
        
        test_channel = event.server.text_channels.find {|c| c.name == name }
        
        if test_channel == nil
          test_channel = event.server.create_channel name
          Discordrb::API.update_role_overrides(event.bot.token, test_channel.id, event.server.id, 0, perms.bits)
        else
           
        end
        
        perms = Discordrb::Permissions.new
        perms.can_read_messages = true
        perms.can_send_messages = true
        perms.can_read_message_history = true
        
        text_channel.define_overwrite(event.user, allow, 0)
      end
    end
  end
end
