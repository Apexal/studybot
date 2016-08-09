module VoiceChannelEvents
  extend Discordrb::EventContainer
  $hierarchy = Hash.new
  $user_teachers = Hash.new
  OPEN_ROOM_NAME = '[New Room]'
  $user_voice_channel = {} # Stores user voice-channels to compare
  def self.handle_room(event, r)
    puts "Handling room #{r.name} with #{r.users.length} users"
    server = event.server
    
    if r.users.empty? and r.name != OPEN_ROOM_NAME
      # Delete associated 'voice-channel' and unlink it
      delete_channel(server, r)
    else
      # 'Open Room's with users in them
      if r.name == OPEN_ROOM_NAME and !r.users.empty?
        puts 'Renaming open room'
        # Get random teacher name
        teachers = $user_teachers[event.user.id].nil? ? $db.query("SELECT staffs.last_name FROM staffs JOIN courses ON courses.teacher_id=staffs.id JOIN students_courses ON students_courses.course_id=courses.id JOIN students ON students.id=students_courses.student_id WHERE students.discord_id=#{event.user.id}").map { |t| t['last_name'] }.uniq : $user_teachers[event.user.id]
        $user_teachers[event.user.id] = teachers
        randteacher = teachers.sample
        randteacher = 'Zero' if event.user.id == event.server.owner.id
        
        count = 0
        until server.voice_channels.find { |c| c.name == "Room #{randteacher}" }.nil?
          randteacher = teachers.sample
          count += 1
          
          if count == teachers.length
            randteacher += " II"
            break
          end
        end
        r.name = "Room #{randteacher}"

        perms = Discordrb::Permissions.new
        perms.can_connect = true

        study_role = event.server.roles.find { |r| r.name == 'studying' }

        # If user is in studymode make the voice channel open to studying students only
        if event.user.on(event.server).role? study_role
          r.name = "Study #{r.name}"
          r.define_overwrite(study_role, perms, 0)
          Discordrb::API.update_role_overrides(event.bot.token, r.id, server.id, 0, perms.bits)
        else
          r.define_overwrite(study_role, 0, perms)
        end
        c = event.server.create_channel(OPEN_ROOM_NAME, 'voice')
      end
    end
  end

  voice_state_update do |event|
    #puts 'Voice state update'
    old_voice_channel = $user_voice_channel[event.user.id]
    server = event.server

    perms = Discordrb::Permissions.new
    perms.can_read_message_history = true
    perms.can_read_messages = true
    perms.can_send_messages = true
    # ------------------------------
    # Room Naming/Open Room Handling

    handle_room event, event.channel unless event.channel.nil?

    rooms = server.voice_channels.find_all { |c| c.name.downcase.include?('room ') }
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
        c_name = event.channel.name if event.channel.name == 'Music' # not really needed anymore
        text_channel = event.server.create_channel c_name
        text_channel.topic = "Private chat for all those in the voice channel '#{event.channel.name}'."
        text_channel.send_message "Welcome to the text-channel for **#{event.channel.name}**! 🎙"
        # Give the current user and BOTS access to it, restrict @everyone
        
        Discordrb::API.update_role_overrides(event.bot.token, text_channel.id, server.roles.find{|r| r.name == "bots"}.id, perms.bits, 0)
        Discordrb::API.update_user_overrides(event.bot.token, text_channel.id, event.user.id, perms.bits, 0)
        Discordrb::API.update_role_overrides(event.bot.token, text_channel.id, server.id, 0, perms.bits)
        # Link the id's of both channels together
        begin
          $hierarchy[event.channel.id] = text_channel.id
        rescue RuntimeError
          sleep 1
          $hierarchy[event.channel.id] = text_channel.id
        end
        
        # Remove the user's perms in all other 'voice-channel'
        $hierarchy.each do |_, text_id|
          next if text_channel.id == text_id
          begin
            Discordrb::API.update_user_overrides(event.bot.token, text_id, event.user.id, 0, 0)
          rescue
            puts 'Failed to update user overrides'
          end
        end
      else
        # Remove the user's perms in all other 'voice-channel'
        $hierarchy.each do |_, text_id|
          next if text_channel.id == text_id
          begin
            Discordrb::API.update_user_overrides(event.bot.token, text_id, event.user.id, 0, 0)
          rescue
            puts 'Failed to update user overrides'
          end
        end
        Discordrb::API.update_user_overrides(event.bot.token, text_channel.id, event.user.id, perms.bits, 0)
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
    
    # Account for hierarchy mismatches
    server.text_channels.find_all { |c| c.name == "voice-channel" }.each do |c|
      begin
        c.delete unless $hierarchy.has_value? c.id
        c.delete if server.voice_channels.find { |v| v.id == $hierarchy.key(c.id) }.nil?
      rescue
        puts 'Already deleted channel.'
      end
    end
    
    member = event.user.on(server)
    current_voice_channel = event.channel.nil? ? nil : event.channel.id
    if old_voice_channel != current_voice_channel
      # There was a change
      unless current_voice_channel.nil?
        # In new voice channel
        begin
          server.text_channels.find { |c| c.id == $hierarchy[current_voice_channel] }.send_message("**#{member.display_name}** *has joined the voice channel.*", true) # Message new #voice-channel about joining
        rescue
          puts 'Failed to send join message. Perhaps AFK channel?'
        end
      end
      unless old_voice_channel.nil?
        # Left a voice channel
        begin
          server.text_channels.find { |c| c.id == $hierarchy[old_voice_channel] }.send_message("**#{member.display_name}** *has left the voice channel.*", true) # Message old #voice-channel about leaving
        rescue
          puts 'Failed to send leave message. Perhaps AFK channel?'
        end
      end
    end
    
    handle_game_parties(server)
    
    $user_voice_channel[event.user.id] = current_voice_channel
  end
end
