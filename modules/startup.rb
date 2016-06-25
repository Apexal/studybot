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
        
        # Removing #voice-channel's
        puts "Removing #voice-channels"
        server.text_channels.each do |c|
            if c.name == "voice-channel"
                puts "Deleting ##{c.name}"
                c.delete
            end
        end
        puts "Done"
        
        # Create #voice-channel's for all voice channels used right now
        puts "Creating all necessary #voice-channel's and adding users to them"
        server.voice_channels.find_all{|r| r.name != "AFK"}.each do |c|
            puts c.name
            
            text_channel = server.text_channels.find{|t| t.name=="music"}
            if c.name != "Music"
                text_channel = server.create_channel "voice-channel"
                text_channel.topic = "Private chat for all those in your voice channel."
            end
            
            # Give the current user and BOTS access to it, restrict @everyone
            c.users.each do |u|
                Discordrb::API.update_user_overrides(bot.token, text_channel.id, u.id, perms.bits, 0)
            end
            
            Discordrb::API.update_role_overrides(bot.token, text_channel.id, server.roles.find{|r| r.name == "bots"}.id, 0, perms.bits)
            
            Discordrb::API.update_role_overrides(bot.token, text_channel.id, server.id, 0, perms.bits)
            
            # Link the id's of both channels together
            $hierarchy[c.id] = text_channel.id
        end
        puts "Done"
        
        # Doing group voice channels
        puts "Doing group voice channels"
        handle_group_voice_channels(server)
        puts "Done"
    end
end
