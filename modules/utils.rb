require 'pry'
require 'securerandom'

module UtilityEvents
  extend Discordrb::EventContainer
end

module UtilityCommands
  extend Discordrb::Commands::CommandContainer

  pokemon_theme = File.open('./resources/pokemon.txt', 'r')
  command(:pry, permission_level: 2) do |event|
    event.message.delete unless event.channel.private?
    server = event.bot.server(150_739_077_757_403_137)
    user = event.user.on(server)

    binding.pry
  end
  
  command(:vc, max_args: 0, description: 'Open up a voice channel for a advisement or group if none exists.', permission_level: 1) do |event|
    event.message.delete unless event.channel.private?
    server = event.bot.server(150_739_077_757_403_137)
    perms = Discordrb::Permissions.new
    perms.can_connect = true

    if $groups.map { |g| g['name'].downcase }.include? event.channel.name
      g_name = $groups.find { |g| Integer(g['room_id']) == event.channel.id }['name']

      group_role = server.roles.find { |r| r.id == Integer($groups.find { |g| Integer(g['room_id']) == event.channel.id }['role_id']) }
      puts "Manually opening channel for Group #{g_name}"
      
      perms = Discordrb::Permissions.new
      perms.can_connect = true
      
      channel = server.create_channel("Group #{g_name}", 'voice')
      study_role = server.roles.find { |r| r.name == 'studying' }
      channel.define_overwrite(group_role, perms, 0)
      Discordrb::API.update_role_overrides($token, channel.id, server.id, 0, perms.bits)
      study_perms = perms
      study_perms.can_speak = true
      channel.define_overwrite(study_role, 0, study_perms)
    else
      advisement = $db.query("SELECT advisement FROM students WHERE discord_id='#{event.user.id}'").first
      unless advisement.nil?
        adv = advisement['advisement'][0..1]
        
        if adv.downcase == event.channel.name[0..1]
          unless server.voice_channels.find { |v| v.name == "Advisement #{adv}" }.nil?
            event.user.pm "A voice-channel for Advisement #{adv} is already open."
            return
          end

          advisement_role = server.roles.find { |r| r.name == adv }
          puts "Creating voice-channel for Advisement #{advisement_role.name}"
          channel = server.create_channel("Advisement #{advisement_role.name}", 'voice')
          channel.position = 2
          channel.define_overwrite(advisement_role, perms, 0)
          Discordrb::API.update_role_overrides($token, channel.id, server.id, 0, perms.bits)
        end
      end
    end

    nil
  end
  
  command(:birthday, min_args: 0, max_args: 1, description: 'Find birthday info about a student.', usage: '`!birthday @user` or `!birthday regisusername`', permission_level: 1) do |event, username|
    server = event.bot.server(150_739_077_757_403_137)

    # Decide who to look up
    where = nil
    if username.nil? or username.start_with? '<@'
      where = "discord_id = '#{(event.message.mentions.empty? ? event.user : event.message.mentions.first).id}'"
    else
      username = $db.escape(username)
      where = "username = '#{username}'"
    end
    #puts where
    target = $db.query("SELECT first_name, last_name, birthday FROM students WHERE #{where}").first
    if target.nil?
      event << 'Failed to find birthday info.'
      return
    end

    now = DateTime.now
    date_str = target['birthday'].strftime("%B %-d")
    date = Date.new(now.year, target['birthday'].month, target['birthday'].day)

    date = Date.new(now.year + 1, date.month, date.day) if date < now

    days_away = (date - now).to_i
    "**#{target['first_name']} #{target['last_name']}**'s birthday is **#{date_str}**! That's #{days_away} days away."
  end
  
  adv_invited = []
  command(:expand, max_args: 0, description: 'Email everyone in your big advisement an invitation to join!', permission_level: 1) do |event|
    event.message.delete unless event.channel.private?
    server = event.bot.server(150_739_077_757_403_137)
    
    $db.query("SELECT advisement FROM students WHERE discord_id='#{event.user.id}'").map { |row| row['advisement'][0..1] }.each do |adv|
      if adv_invited.include? adv
        event.user.pm 'Your advisement has already been emailed!'
        return
      end
      all = $db.query("SELECT username, first_name, last_name, verified FROM students WHERE advisement LIKE '#{adv}%'")
      
      registered = all.find_all { |row| row['verified'] == 1 }
      unregistered = all.find_all { |row| row['verified'] == 0 }
      
      list = registered.map { |u| "<li>#{u['first_name']} #{u['last_name']}</li>" }.join "\n"
      
      mail = Mail.new do
        from "Student Discord Server <#{$CONFIG['auth']['gmail']['username']}@gmail.com>"
        to    unregistered.map { |row| "#{row['username']}@regis.org" }
        subject "Your Advisement Calls"

        html_part do
          content_type 'text/html; charset=UTF-8'
          body File.read('./resources/expand_email.html').gsub('%adv%', adv).gsub('%count%', registered.length.to_s).gsub('%list%', list)
        end
      end
      mail.deliver!
      
      adv_invited << adv
      event.user.on(server).pm "Successfully invited the rest of #{adv}"
      break
    end
    nil
  end
  
  emailed = []
  command(:recruit, min_args: 1, max_args: 1, description: 'Invite a student to the server with an email!', usage: '`!recruit regisusername`', permission_level: 1) do |event, username|
    event.message.delete unless event.channel.private?
    server = event.bot.server(150_739_077_757_403_137)
    user = event.user.on(server)
    
    username = $db.escape(username)
    # Check if they are already registered
    inviter = $db.query("SELECT * FROM students WHERE discord_id=#{user.id}")
    
    if inviter.count == 0
      return
    else
      inviter = inviter.first
    end
    
    $db.query("SELECT first_name, username, verified, discord_id FROM students WHERE username='#{username}' ").each do |row|
      if row['verified'] == 1
        user.pm "They are already registered! <@#{row['discord_id']}>"
        return
      else
        if emailed.include? username
          user.pm 'They have already been emailed an invitation.'
          return
        else
          code = SecureRandom.hex
          $db.query("INSERT INTO discord_codes VALUES (NULL, '#{code}', '#{username}') ON DUPLICATE KEY UPDATE code='#{code}'")
          mail = Mail.new do
            from "Student Discord Server <#{$CONFIG['auth']['gmail']['username']}@gmail.com>"
            to    "#{username}@regis.org"
            subject "Invite from #{inviter['advisement']}"

            html_part do
              content_type 'text/html; charset=UTF-8'
              body File.read('./resources/recruit_email.html').sub('%code%', code).sub('%first_name%', row['first_name']).sub('%inviter%', "#{inviter['first_name']} #{inviter['last_name']} of #{inviter['advisement']}")
            end
          end
          mail.deliver!
        
          puts "#{inviter['username']} invited #{row['username']}"
          
          user.pm 'Successfully invited user!'
          
          emailed << username
        end
      end
      break
    end
    
    nil
  end
  
  command(:flag, description: 'Show the official Student Discord flag!') do |event|
    event.channel.send_file(File.open('./resources/flag.png', 'rb'))
    'Designed by *Liam Quinn*'
  end

  command(:login, description: 'Get the link to login to the server\'s website!', permission_level: 1) do |event|
    event.message.delete unless event.channel.private?
    
    # Get user's secret code
    code = nil
    $db.query("SELECT code FROM discord_codes WHERE discord_id='#{event.user.id}'").each do |row|
      code = row['code']
    end

    event.user.pm "http://www.getontrac.info:4567/login?code=#{code}" unless code.nil?
    nil
  end

  command(:eval, permission_level: 3) do |event, code|
    event.message.delete unless event.channel.private?

    eval(code) # not the safest...
    puts "Evaluated code: #{code}"
    "Successfully executed code."
  end

  command(:addall, permission_level: 3) do |event, group|
    puts "Adding all users to Group #{group}"
    role = event.server.roles.find { |r| r.name == group }
    verified = event.server.roles.find { |r| r.name == 'Verified' }

    event.server.members.each do |m|
      next unless m.role? verified or m.role? role
      m.add_role role

      sleep 0.5
    end
    puts 'Done.'

    nil
  end

  command(:theverybest, permission_level: 3) do |event|
    pokemon_theme.each_line do |line|
      begin
        event.channel.send line, true
      rescue;end
      sleep 1.5
    end

    nil
  end

  command(:rename, description: 'Set a new name for your current voice room or get a random one. Usage: `!rename "Teacher Last Name"` or just `!rename`', permission_level: 1) do |event, name|
    if event.channel.name != 'voice-channel'
      event.message.delete unless event.channel.private?
      event.user.pm 'You can only use `!rename` in a #voice-channel text channel.'
      return
    end

    to_delete = []

    voice_channel = event.server.voice_channels.find { |c| c.id == $hierarchy.key(event.channel.id) }
    return if voice_channel.nil?

    unless voice_channel.name.include? 'Room '
      event.message.delete
      event.user.pm '`!rename` can only be used for a **Room [TEACHER NAME]** voice channel.'
      return
    end

    old_teacher = voice_channel.name.split(' ')[-1] # Get's last word

    teachers = $user_teachers[event.user.id].nil? ? $db.query("SELECT staffs.last_name FROM staffs JOIN courses ON courses.teacher_id=staffs.id JOIN students_courses ON students_courses.course_id=courses.id JOIN students ON students.id=students_courses.student_id WHERE students.discord_id=#{event.user.id} AND courses.is_class=1").map { |t| t['last_name'] }.uniq : $user_teachers[event.user.id]
    $user_teachers[event.user.id] = teachers
    teacher = teachers.include?(name) ? name : teachers.sample

    until event.server.voice_channels.find { |c| c.name == "Room #{teacher}" }.nil?
      teacher = teachers.sample
    end

    voice_channel.name = voice_channel.name.gsub(old_teacher, teacher)
    event.channel.topic = "Private chat for all those in the voice channel 'Room #{teacher}'."

    to_delete << event.message
    to_delete << event.channel.send_message("Renamed voice-channel to **Room #{teacher}**!")

    puts "Renamed voice channel #{old_teacher} to #{teacher}"

    sleep 30
    begin
      to_delete.map(&:delete)
    rescue
      # Channel could be deleted already
    end

    nil
  end

  command(:color, description: 'Set your color! Usage: `!color colorname`', permission_level: 1) do |event, color|
    server = event.bot.server(150_739_077_757_403_137)
    colors = %w(red orange yellow pink purple blue green)
    if colors.include?(color) || color == 'default'
      croles = server.roles.find_all { |r| colors.include? r.name }
      event.user.remove_role croles
      if color != 'default'
        event.user.add_role croles.find { |r| r.name == color}
      end
      'Successfully changed user color!'
    else
      "The available colors are **#{colors.join ', '}, and default**."
    end
  end
  
  command(:photo, description: 'Get the profile picture of a student.', usage: '`!whois @user` or `!whois regisusername`', permission_level: 1) do |event, username|
    messages = [event.message]
    
    where = "discord_id='#{event.user.id}'"
    if !username.nil? and !username.start_with?('<@')
      where = "username='#{$db.escape(username)}'"
    elsif !event.message.mentions.empty?
      where = "discord_id='#{event.message.mentions.first.id}'"
    end
    
    url = $db.query("SELECT mpicture FROM students WHERE #{where}").first
    if url.nil? or url['mpicture'].empty? or url['mpicture'].nil?
      event << "They do not have a profile picture set."
      return
    end
    
    messages << event.channel.send_message(url['mpicture'])
    
    sleep 60
    begin;messages.map(&:delete);rescue;end
    nil
  end
  
  command(:whois, description: 'Returns information on the user mentioned.', usage: '`!whois @user or !whois regisusername`', permission_level: 1) do |event, username|
    server = event.bot.server(150_739_077_757_403_137)
    # Get user mentioned or default to sender of command
    if !username.nil? and !username.start_with?('<@')
      # Prevent nasty SQL injection
      username = $db.escape(username)
      result = $db.query("SELECT * FROM students WHERE username='#{username}' AND verified=1")
      if result.count > 0
        result = result.first
        user = server.member(result['discord_id'])
        
        message = "**#{result['first_name']} #{result['last_name']}** of **#{result['advisement']}** is #{user.mention()}!"
        
        event << message
      else
        event << "*#{username}* is not yet registered!"
      end
      return
    end

    # Otherwise go off of mentions
    who = event.user
    who = event.message.mentions.first unless event.message.mentions.empty?
    who = who.on(server)

    # Shenanigans
    if who.name == 'studybot'
      event << '**I am the bot that automates every single part of the Discord server!** Made by Frank Matranga https://github.com/Apexal/studybot'
      return
    elsif who.id == server.owner.id
      event << "#{server.owner.mention} is the **Owner** of the server."
      return
    elsif who.role? server.roles.find { |r| r.name == 'Guests' }
      #event << "*#{who.display_name}* is a **Guest** (Non-Regian)."
      # GUEST INFO
      $db.query("SELECT name, school FROM guests WHERE discord_id=#{who.id}").each do |result|
        school = result['school'].nil? ? '' : " of **#{result['school']}**"
        event << "*#{who.display_name}* is **#{result['name']}**#{school}!"
        break
      end

      return
    end

    # Find a student with the correct discord id
    result = $db.query("SELECT * FROM students WHERE discord_id=#{who.id}")
    if result.count > 0
      result = result.first
      event << "*#{who.display_name}* is **#{result['first_name']} #{result['last_name']}** of **#{result['advisement']}**!"
    else
      "*#{who.display_name}* is not yet registered!"
    end
  end

  command(:adv, description: 'List all users in an advisement. Usage: `!adv` or `!adv advisement`', permission_level: 1) do |event, adv|
    if adv
      adv = $db.escape(adv).upcase
      if event.message.mentions.length == 1
        adv = $db.query("SELECT advisement FROM students WHERE discord_id=#{event.message.mentions.first.id}").first['advisement']
      end
      query = "SELECT * FROM students WHERE verified=1 AND advisement LIKE '#{adv}%' ORDER BY advisement ASC"
      event << "**:page_facing_up: __Listing All Users in #{adv}__ :page_facing_up:**"

      results = $db.query(query)
      results.each do |row|
        user = event.bot.user(row['discord_id'])
        if user
          event << "`-` #{user.mention} #{row['first_name']} #{row['last_name']}"
        end
      end
      event << "*#{results.count} total*"
    else
      total_users = 0
      event << '**:page_facing_up: __Advisement Statistics__ :page_facing_up:**'
      results = $db.query('SELECT advisement, COUNT(*) as count FROM students WHERE verified=1 GROUP BY advisement')
      results.each do |row|
        total_users += row['count']
        event << "`-` **#{row['advisement']}** *#{row['count']} users*"
      end
      event << "*#{results.count} total advisements*"
      event << "*#{total_users} total users*"
    end
    return ''
  end

  command(:rules, description: 'Show the rules of the server') do |event|
    event << '__***Server Rules***__ :bookmark_tabs:'
    event << '`1` Don\'t be a jerk.'
    event << '`2` Report any and all abuse directly to the Owner <@152621041976344577>.'
    event << '`3` No NSFW content.'
  end

  command(:shutdown, permission_level: 3) do |event|
    event.message.delete unless event.channel.private?
    
    puts 'Shutting down!'
    event.user.pm 'See ya!'
    save_hierarchy
    event.bot.stop
  end
  
  command(:restart, description: 'Restart the bot.', permission_level: 3) do |event|
    puts 'Restarting!'
    save_hierarchy
    event.bot.stop
    exec('./run')
  end
end

module Suppressor
  extend Discordrb::EventContainer

  message(containing: not!('google.com/'), in: '#finals') do |event|
    event.message.delete if event.message.author != event.server.owner
  end

  message(containing: '@') do |event|
    server = event.bot.server(150_739_077_757_403_137)
    mentions = []

    usernames = []

    words = event.message.content.split ' '
    words.each do |w|
      next if usernames.include? w
      usernames << w
      if w.start_with? '@'
        username = w.tr('@', '')
        next unless username.match(/^\w+[1-9]{2}$/)

        username = $db.escape(username)
        $db.query("SELECT discord_id FROM students WHERE username='#{username}' AND verified=1").each do |row|
          member = server.members.find { |m| m.id == Integer(row['discord_id']) }
          mentions.append(member) unless member.nil?
        end
      end
    end

    event.channel.send("^^^ #{mentions.map { |m| m.mention }.join(' ')}") unless mentions.empty?
  end
  
  message(containing: '@Room') do |event|
    return if event.channel.private?

    mentions = []
    channels = []

    words = event.message.content.split ' '
    words.each do |w|
      next if channels.include? w
      if w.start_with? '@'
        channel_name = w.tr('@', '').tr('-', ' ').tr('_', ' ')
        begin
          channel = event.server.voice_channels.find { |v| v.name.downcase == channel_name.downcase }
          mentions = channel.users.map { |u| u.mention }
        rescue
          puts 'Doesn\'t exist'
        end
        channels << w
      end
    end
    
    event.channel.send_message(mentions.join ' ').delete unless mentions.empty?
  end
  
  message(containing: '@here') do |event|
    return if event.channel.private?
    # Check if channel allows @everyone
    
    unless event.user.on(event.server).permission?(:mention_everyone, event.channel)
      m = event.channel.send_message '^^^ @here'
      puts 'Manually replace @here'
      sleep 5
      m.delete
    end
  end
  
  message do |event|
    unless event.channel.private?
      event.message.delete if event.user.on(event.server).role? event.server.roles.find { |r| r.name == 'Muted' }
    end
  end
end
