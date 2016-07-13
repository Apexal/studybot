module VoiceChannelEvents
  extend Discordrb::EventContainer
  $hierarchy = Hash.new
  $user_teachers = Hash.new
  OPEN_ROOM_NAME = '[New Room]'
  $user_status = {} # Stores voice status of users to compare
  def self.handle_room(event, r)
    server = event.server
    if r.users.empty? and r.name != OPEN_ROOM_NAME
      # Delete associated 'voice-channel' and unlink it
      puts "Voice channel #{r.name} is empty and will be deleted"
      begin
        server.text_channels.find{|t| t.id == $hierarchy[r.id]}.delete
        $hierarchy.delete r.id
      rescue
        puts 'Failed to find/delete associated #voice-channel'
      end
      r.delete
    else
      # 'Open Room's with users in them
      if r.name == OPEN_ROOM_NAME and !r.users.empty?
        puts 'Renaming open room'
        # Get random teacher name
        teachers = $user_teachers[event.user.id].nil? ? $db.query("SELECT staffs.last_name FROM staffs JOIN courses ON courses.teacher_id=staffs.id JOIN students_courses ON students_courses.course_id=courses.id JOIN students ON students.id=students_courses.student_id WHERE students.discord_id=#{event.user.id}").map { |t| t['last_name'] }.uniq : $user_teachers[event.user.id]
        $user_teachers[event.user.id] = teachers
        randteacher = teachers.sample
        until server.voice_channels.find { |c| c.name == "Room #{randteacher}" }.nil?
          puts 'ALREADY EXISTS!'
          randteacher = teachers.sample
        end
        r.name = "Room #{randteacher}"
        c = event.server.create_channel(OPEN_ROOM_NAME, 'voice')
      end
    end
  end

  def self.update_channel_cache(channels)
  end

  voice_state_update do |event|
    puts 'Voice state update'
    old_status = $user_status[event.user.id]
    server = event.server
    perms = Discordrb::Permissions.new
    perms.can_read_message_history = true
    perms.can_read_messages = true
    perms.can_send_messages = true
    # ------------------------------
    # Room Naming/Open Room Handling

    handle_room event, event.channel unless event.channel.nil?

    rooms = server.voice_channels.find_all { |c| c.name.downcase.include?('room') }
    rooms.each do |r|
      # Empty Room ____'s
      next if !event.channel.nil? and r.id == event.channel.id
      handle_room event, r
    end
    # END ROOM NAMING/OPEN ROOM HANDLING
    # ----------------------------------
    # HANDLE ASSOCIATED #voice-channel TEXT CHANNEL
    if !event.channel.nil? and event.channel.name != 'AFK'
      # voice-channel associated with this voice channel
      text_channel = server.text_channels.find { |c| c.id == $hierarchy[event.channel.id] }
      # If it doesn't exist create it
      if text_channel.nil?
        puts "Creating #voice-channel for #{event.channel.name}"
        # Name it 'voice-channel' or 'Music'
        c_name = 'voice-channel'
        c_name = event.channel.name unless event.channel.name != 'Music'
        text_channel = event.server.create_channel c_name
        text_channel.topic = "Private chat for all those in the voice channel '#{event.channel.name}'."
        text_channel.send_message "Welcome to the text-channel for **#{event.channel.name}**! 🎙"
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
      $hierarchy.each do |_, text_id|
        next unless text_channel.id != text_id

        begin
          Discordrb::API.update_user_overrides(event.bot.token, text_id, event.user.id, 0, 0)
        rescue
          puts 'Failed to update user overrides'
        end

      end
    else
      # Remove the user's perms in all other 'voice-channel'
      $hierarchy.each do |_, text_id|
        begin
          Discordrb::API.update_user_overrides(event.bot.token, text_id, event.user.id, 0, 0)
        rescue
          puts 'Failed to update overrides'
        end
      end
    end
    member = event.user.on(server)
    current_status = event.channel.nil? ? nil : event.channel.id
    if old_status != current_status
      # There was a change
      unless current_status.nil?
        # In new voice channel
        server.text_channels.find { |c| c.id == $hierarchy[current_status] }.send_message("**#{member.display_name}** *has joined the voice channel.*", true) # Message new #voice-channel about joining
      end
      unless old_status.nil?
        # Left a voice channel
        begin
          server.text_channels.find { |c| c.id == $hierarchy[old_status] }.send_message("**#{member.display_name}** *has left the voice channel.*", true) # Message old #voice-channel about leaving
        rescue
          puts 'Failed to send leave message'
        end
      end
    end
    $user_status[event.user.id] = current_status
    #puts $user_status
  end
end
