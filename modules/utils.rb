module UtilityEvents
  extend Discordrb::EventContainer
  
  ['freshmen', 'sophomores', 'juniors', 'seniors'].each do |g|
	message(containing: "@#{g}") do |event|
		mentions = []
		event.channel.users.select{|u|u.roles.map{|r| r.name}.include? g }.each do |user|
			mentions.push(user.mention)
		end
		if mentions.length > 0
			event.channel.send_message mentions.join(' ')
		end
		nil
	  end
  end
end

module UtilityCommands
  extend Discordrb::Commands::CommandContainer
	
	command(:rooms) do |event|
		return false if event.user.name != "President Mantranga"
		
		server = event.bot.server(150739077757403137)
		vrole = server.roles.find{|r| r.name == "verified"}
		user = event.user.on(server)
		
		bots_role_id = server.roles.find { |r| r.name == 'bots' }.id
		
		token = event.bot.token
		
		perms = Discordrb::Permissions.new
        perms.can_read_messages = true
        perms.can_send_messages = true
        perms.can_read_message_history = true
        perms.can_mention_everyone = true
		
		puts server.users.length
		
		server.users.each do |u|
			sleep 0.5
			print "Working on #{u.name} "
			user_info = $db.query("SELECT * FROM students WHERE discord_id=#{u.id}")
			if user_info.count == 0
				next
			else
				user_info = user_info.first
			end
			
			print " (#{user_info['username']}) \n"
			
			large_adv = user_info['advisement'][0..1]
			small_adv = user_info['advisement']
			
			# Add the roles for each adv and create channels for each
			[large_adv, small_adv].each do |a|
				advrole = server.roles.find { |r| r.name == a }
				if advrole.nil?
					puts "Creating role"
					advrole = server.create_role
					advrole.name = a
					advrole.hoist = true if a.length <= 2 # This should only hoist large advisement roles
				end
				
				if u.roles.include?(advrole) == false
					puts "Adding role"
					u.add_role(advrole)
				end
				
				puts "Finding channel"
				adv_channel = event.bot.find_channel(a.downcase).first
				if adv_channel.nil?
					puts "Creating channel"
					adv_channel = server.create_channel(a)
					adv_channel.topic = "Private chat for Advisement #{a}"
					channel_id = adv_channel.id
				end
				
				puts "Updating perms"
				Discordrb::API.update_role_overrides(token, adv_channel.id, server.id, 0, perms.bits) # @everyone
				Discordrb::API.update_role_overrides(token, adv_channel.id, advrole.id, perms.bits, 0) # advisement role
				Discordrb::API.update_role_overrides(token, adv_channel.id, bots_role_id, perms.bits, 0) # bots
			end
		end
		
		"Done"
	end
	
	command(:flag, description: 'Show the official Regis Discord flag!') do |event|
		event.channel.send_file(File.open('./flag.png', 'rb'))
		'Designed by *Liam Quinn*'
	end
	
  command(:whois, description: 'Returns information on the user mentioned. Usage: `!whois @user or !whois regisusername`') do |event, username|
    # Get user mentioned or default to sender of command
    if username != nil and !username.start_with?("<@")
      # Prevent nasty SQL injection
      username = $db.escape(username)
      result = $db.query("SELECT * FROM students WHERE username='#{username}'")
      if result.count > 0
        result = result.first
        user = event.bot.user(result['discord_id'])
        event << "**#{result['first_name']} #{result['last_name']}** of **#{result['advisement']}** is #{user.mention()}!"
      else
        event << "*#{username}* is not yet registered!"
      end
      return
    end

    # Otherwise go off of mentions
    who = event.user
    who = event.message.mentions.first unless event.message.mentions.empty?

    # SuperUser shenanigans
    if who.name == 'studybot'
      event << '*I am who I am.*'
      return
    end

    # Find a student with the correct discord id
    result = $db.query("SELECT * FROM students WHERE discord_id=#{who.id}")
    if result.count > 0
      result = result.first
      event << "*#{who.name}* is **#{result['first_name']} #{result['last_name']}** of **#{result['advisement']}**!"
    else
      "*#{who.name}* is not yet registered!"
    end
  end

  command(:adv, description: 'List all users in an advisement. Usage: `!adv` or `!adv advisement`') do |event, adv|
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
  

  command(:color, description: 'Set your color! Usage: `!color colorname`') do |event, color|
    server = event.bot.server(150739077757403137)
    colors = %w(red yellow purple blue green)
    if colors.include?(color) || color == 'default'
      colors.each do |c|
        crole = server.roles.find { |r| r.name == c }
        if c == color
          event.user.add_role(crole)
        else
          event.user.remove_role(crole)
        end
      end
      'Successfully changed user color!'
    else
      "The available colors are **#{colors.join ', '}, and default**."
    end
  end
end

module Suppressor
  extend Discordrb::EventContainer

  message(containing: 'discord.gg') do |event|
    event.message.delete
    event.user.pm "I wouldn't do that if I were you."
  end
end
