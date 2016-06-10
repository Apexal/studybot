module GroupCommands
    extend Discordrb::Commands::CommandContainer
    
    command(:creategroup, description: "Create a group to get your own role and text-channel.") do |event, full_name, description|
        full_name.strip!
        
        if description
            description = description[0..254]
        else
            description = "No description given."
        end
        
        group_name = full_name.dup
        
        if !event.channel.private?
            event.message.delete
            event.user.pm "Group commands are DM only. Use them here."
            return
        end
        
        puts "Attempting to make group '#{full_name}'"
        
        # Check if group exists already or person already has group
        group_name = $db.escape(group_name)
        existing = $db.query("SELECT COUNT(*) AS count FROM groups JOIN students ON students.username=groups.creator WHERE students.discord_id=#{event.user.id} OR groups.name='#{group_name}'").first['count']
        if existing > 0
            puts "Group exists or user already has group"
            event.message.reply "A group by that name already exists or you already started a group."
            return
        end

        # Sanitize group name
        group_name.downcase!
        group_name.strip!
        group_name.gsub! /\s+/, '-'
        group_name.gsub! /[^\p{Alnum}-]/, ''

        server = event.bot.server(150739077757403137)
        user = event.user.on(server)
        
        # Good to go
        perms = Discordrb::Permissions.new
        perms.can_read_messages = true
        perms.can_read_message_history = true
        perms.can_send_messages = true
        
        # Create role
        group_role = server.create_role
        group_role.name = full_name
        user.add_role group_role
        
        puts group_role.id
        
        # Create text-channel
        group_room = server.create_channel group_name
        group_room.topic = description
        group_room.define_overwrite(group_role, perms, 0)
        Discordrb::API.update_role_overrides(event.bot.token, group_room.id, server.id, 0, perms.bits)
        
        puts group_room.id
        
        # Get Regis username of user
        username = "unknown"
        $db.query("SELECT username FROM students WHERE discord_id=#{event.user.id}").each do |row|
            username = row['username']
        end
        
        # Insert group in DB
        $db.query("INSERT INTO groups (creator, name, private, room_id, role_id, description) VALUES ('#{username}', '#{full_name}', 0, '#{group_room.id}', '#{group_role.id}', '#{description}')")
        
        event.message.reply "You have created **#{full_name}!** Others can join with `!join "#{full_name}"`"
    end
end
