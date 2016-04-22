module StartupEvents
  extend Discordrb::EventContainer
  
  ready do |event|
	bot = event.bot
	puts "Ready!"
	server = bot.server(150739077757403137)
	
	# text-channel perms
	perms = Discordrb::Permissions.new
	perms.can_read_message_history = true
	perms.can_read_messages = true
	perms.can_send_messages = true
	
	djrole = server.roles.find{|r| r.name == "dj"}
	server.text_channels.each do |c|
		if c.name == "voice-channel" || c.name == "music"
			puts "Deleting ##{c.name}"
			c.delete
		else
			c.define_overwrite(djrole, 0, perms)
		end
	end
	
	# Create game rooms
	server.users.each do |u|
		if !!u.game
			$playing[u.id] = u.game
			puts "#{u.name} is playing #{u.game}"
			game_channel = server.voice_channels.find {|c| c.name == $playing[u.id]}
			if game_channel.nil? && $playing.values.count(u.game) >= 2
			  puts "Creating Room for #{u.game}"
			  server.create_channel($playing[u.id], 'voice')
			end
		end
	end
	
	server.voice_channels.find_all{|r| r.name != "AFK"}.each do |c|
		puts c.name
		c_name = "voice-channel"
		c_name = c.name unless c.name != "Music"
		
		text_channel = server.create_channel c_name
		text_channel.topic = "Private chat for all those in your voice channel."
		
		# Give the current user and BOTS access to it, restrict @everyone
		c.users.each do |u|
			puts u.name
			Discordrb::API.update_user_overrides(bot.token, text_channel.id, u.id, perms.bits, 0)
		end
		
		Discordrb::API.update_role_overrides(bot.token, text_channel.id, server.roles.find{|r| r.name == "bots"}.id, 0, perms.bits)
		Discordrb::API.update_role_overrides(bot.token, text_channel.id, server.id, 0, perms.bits)

		# Link the id's of both channels together
		$hierarchy[c.id] = text_channel.id
	end
  end
end