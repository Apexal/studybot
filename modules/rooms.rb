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
end
