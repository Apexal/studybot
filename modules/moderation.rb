module ModeratorCommands
	extend Discordrb::Commands::CommandContainer
	
	command(:report, description: "Send a report to the servers' Moderators. Usage: `!report 'Message' @optionaluser`") do |event, message|
		event.message.delete unless event.channel.private?
		
		server = event.bot.server(150_739_077_757_403_137)
		user = event.user.on(server)
		
		if message.nil?
			user.pm 'You must give a message with your report! i.e. `!report "Message" @optionaluser`.'
			return
		end
		
		mod_channel = server.text_channels.find { |t| t.name == 'moderators' }
		
	end
end