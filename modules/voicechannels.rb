module VoiceChannelEvents
    extend Discordrb::EventContainer
    $hierarchy = Hash.new
    voice_state_update do |event|
        #puts "Voice state update"
        server = event.server
        perms = Discordrb::Permissions.new
        perms.can_read_message_history = true
        perms.can_read_messages = true
        perms.can_send_messages = true
        if event.channel != nil and event.channel.name != "AFK"
            # voice-channel associated with this voice channel
            text_channel = server.text_channels.find { |c| c.id == $hierarchy[event.channel.id] }
            # If it doesn't exist create it
            if text_channel.nil?
                puts "Creating #voice-channel for #{event.channel.name}"
                # Name it 'voice-channel' or 'Music'
                
                c_name = "voice-channel"
                c_name = event.channel.name unless event.channel.name != "Music"
                
                text_channel = event.server.create_channel c_name
                text_channel.topic = (c_name == "voice_channel") ? "Private chat for all those in your voice channel." : "Private channel for DJ commands"
                
                # Give the current user and BOTS access to it, restrict @everyone
                
                Discordrb::API.update_user_overrides(event.bot.token, text_channel.id, event.user.id, perms.bits, 0)
                Discordrb::API.update_role_overrides(event.bot.token, text_channel.id, server.roles.find{|r| r.name == "bots"}.id, perms.bits, 0)
                Discordrb::API.update_role_overrides(event.bot.token, text_channel.id, server.id, 0, perms.bits)
                # Link the id's of both channels together
                $hierarchy[event.channel.id] = text_channel.id
            else
                Discordrb::API.update_user_overrides(event.bot.token, text_channel.id, event.user.id, perms.bits, 0)
            end
            # Remove the user's perms in all other 'voice-channel'
            $hierarchy.each do |voice_id, text_id|
                if text_channel.id != text_id
                    Discordrb::API.update_user_overrides(event.bot.token, text_id, event.user.id, 0, 0)
                end
            end
        else
            # Remove the user's perms in all other 'voice-channel'
            $hierarchy.each do |voice_id, text_id|
                Discordrb::API.update_user_overrides(event.bot.token, text_id, event.user.id, 0, 0)
            end
        end
        # Room Naming/Open Room Handling
        rooms = server.voice_channels.find_all { |c| c.name.include?('Room') }
        rooms.each do |r|
            # Empty Room ____'s
            if r.users.empty? and r.name != "Open Room"
                # Delete associated 'voice-channel' and unlink it
                puts "Voice channel #{r.name} is empty and will be deleted"
                begin
                    server.text_channels.find{|t| t.id == $hierarchy[r.id]}.delete
                    $hierarchy.delete r.id
                rescue
                    puts "Failed to find/delete associated #voice-channel"
                end
                r.delete
            else
                # 'Open Room's with users in them
                if r.name == "Open Room" and !r.users.empty?
                    puts "Open Room has been filled"
                    teachers = $db.query("SELECT staffs.last_name FROM staffs JOIN courses ON courses.teacher_id=staffs.id JOIN students_courses ON students_courses.course_id=courses.id JOIN students ON students.id=students_courses.student_id WHERE students.discord_id=#{event.user.id}").map { |t| t['last_name'] }.uniq
                    randteacher = teachers.sample
                    while server.voice_channels.find { |c| c.name == "Room #{randteacher}" } != nil
                        randteacher = teachers.sample
                    end
                    r.name = "Room #{randteacher}"
                    c = event.server.create_channel("Open Room", 'voice')
                end
            end
        end
    end
end
