module RoomEvents
    extend Discordrb::EventContainer

end

module RoomCommands
    extend Discordrb::Commands::CommandContainer

    # List of special channels
    joinable = %w(gaming memes testing)
	
	channels_to_roles = {"memes" => "memer", "testing" => "tester", "gaming" => "gamer"}
	
    command(:join, description: 'Join a special channel. Usage: `!join channelname`') do |event, channel_name|
        server = event.bot.server(150739077757403137)
		user = event.user.on(server)
		
        if !event.channel.private?
            role = server.roles.find{|r| r.name == channels_to_roles[channel_name]}
            
            if !role.nil? && joinable.include?(channel_name)
                user.add_role role
            else
                event.user.pm "You can only join/leave **#{joinable.join ', '}**. Try `!join memes`"
            end
        else
            event.user.pm "`!join` and `!leave` are only available in PM's. Try using them here!"
            
        end
		
		event.message.delete
        nil
    end

    command(:leave, description: 'Leave a special channel. Usage: `!leave channel') do |event, channel_name|
        server = event.bot.server(150739077757403137)
		user = event.user.on(server)
		
        if !event.channel.private?
            role = server.roles.find{|r| r.name == channels_to_roles[channel_name]}
            
            if !role.nil? && joinable.include?(channel_name)
                user.remove_role role
            else
                event.user.pm "You can only join/leave **#{joinable.join ', '}**. Try `!join memes`"
            end
        else
            event.user.pm "`!join` and `!leave` are only available in PM's. Try using them here!"
            
        end
		
		event.message.delete
        nil
    end
end
