module ModeratorCommands
	extend Discordrb::Commands::CommandContainer
	
	command(:report, min_args: 1, max_args: 1, description: "Send a report to the servers' Moderators.", usage: "`!report 'Message' @optionaluser`", bucket: :reporting, rate_limit_message: "**Woah there.** You must wait %time% seconds before attempting to report again.") do |event, message|
		event.message.delete unless event.channel.private?
		
		server = event.bot.server(150_739_077_757_403_137)
		user = event.user.on(server)
		
		if message.nil?
			user.pm 'You must give a message with your report! i.e. `!report "Message" @optionaluser`.'
			return
		end
		
		mod_channel = server.text_channels.find { |t| t.name == 'moderators' }
		# TODO: db stuff
		mod_channel.send_message "**REPORT FROM #{user.mention}:** #{message}"
		
		user.pm "Sent report."
		
		nil
	end
end