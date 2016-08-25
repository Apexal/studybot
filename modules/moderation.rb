module ModeratorCommands
	extend Discordrb::Commands::CommandContainer
	
	command(:mute, min_args: 1, max_args: 1, description: 'Toggle a text mute on a user.', usage: '`!mute @user`', permission_level: 2) do |event|
		event.message.delete unless event.channel.private?
		
		server = event.bot.server(150_739_077_757_403_137)
		target = event.message.mentions.first.on(server)
		
		if target.nil?
			event.user.pm 'Please mention a user to be muted/unmuted.'
			return
		end
		
		if !target.role? server.roles.find { |r| r.name == 'Verified' } or target.role? server.roles.find { |r| r.name == 'Moderators' }
			unless target.role? server.roles.find { |r| r.name == 'Guests' }
				event.user.pm 'You can only mute non-moderator students and guests.'
				return
			end
		end
		
		muted_role = server.roles.find { |r| r.name == 'Muted' }
		if target.role? muted_role
			target.remove_role muted_role
			target.pm 'You have been unmuted by a Moderator!'
		else
			target.add_role muted_role
			target.pm 'You have been muted by a Moderator!'
		end
		
		event.user.pm "Toggled mute on #{target.mention}"
		puts "#{event.user.mention} toggled mute on #{target.mention}"
		
		nil
	end
	
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