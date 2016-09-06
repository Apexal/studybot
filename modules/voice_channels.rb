$hierarchy = {}
$user_teachers = {}
$OPEN_ROOM_NAME = '[New Room]'.freeze

$voice_states = {}

# UTILITY METHODS
def get_rand_teacher(user)
  teachers = $user_teachers[user.id].nil? ? $db.query("SELECT staffs.last_name FROM staffs JOIN courses ON courses.teacher_id=staffs.id JOIN students_courses ON students_courses.course_id=courses.id JOIN students ON students.id=students_courses.student_id WHERE students.discord_id=#{user.id} AND courses.is_class=1").map { |t| t['last_name'] }.uniq : $user_teachers[user.id]
  $user_teachers[user.id] = teachers
  randteacher = teachers.sample

	#if summer?
	#	return 'Summer'
	#else
		return randteacher
	#end	
end

def room_exists?(server, name)
  !server.voice_channels.find { |r| r.name == name }.nil?
end

def set_voice_channel_name(server, user, room)
  # Get a random teacher name
  randteacher = get_rand_teacher(user)
  randteacher = 'Zero' if user.id == server.owner.id

  count = 0
  while room_exists?(server, "Room #{randteacher}")
    randteacher = get_rand_teacher(user)
    count += 1
    if count == 7
      randteacher += ' II'
      break
    end
  end
  # Finally rename the voice channel
  room.name = "Room #{randteacher}"
end

def handle_room(event, r)
  server = event.server
  #puts "Handling voice-channel #{r.name} with #{r.users.length} users"
  
  # Temporary fix for stupid discordrb bug
  if r.name == $OPEN_ROOM_NAME and r.users.empty?
    puts 'Restarting due to users caching bug!'
    save_hierarchy
    event.bot.stop
    exec('./run')
	return
  end

  if r.users.empty? and r.name != $OPEN_ROOM_NAME
    # Delete associated 'voice-channel' and unlink it
    delete_channel(server, r)
  else
    # 'Open Room's with users in them
    if r.name == $OPEN_ROOM_NAME and !r.users.empty?
      puts 'Renaming open room'

      set_voice_channel_name(server, event.user, r)

      perms = Discordrb::Permissions.new
      perms.can_connect = true

      study_role = event.server.roles.find { |role| role.name == 'studying' }

      # If user is in studymode make the voice channel open to studying students only
      if event.user.on(event.server).role? study_role
        r.name = "Study #{r.name}"
        r.define_overwrite(study_role, perms, 0)
        Discordrb::API.update_role_overrides($token, r.id, server.id, 0, perms.bits)
      else
        r.define_overwrite(study_role, 0, perms)
      end

      # Add a new empty room
      event.server.create_channel($OPEN_ROOM_NAME, 'voice')
    end
  end
  #puts "Done\n"
end

def handle_associated_channel(server, user, voice_channel, perms)
  # Associated text-channel
  text_channel = server.text_channels.find { |c| c.id == $hierarchy[voice_channel.id] }
  
  if text_channel.nil?
    # Doesn't have a associated text-channel!
    puts "Creating #voice-channel for #{voice_channel.name}"
		# Name it 'voice-channel' or 'Music'
		c_name = voice_channel.name == 'Music Room' ? 'music' : 'voice-channel'
    text_channel = server.create_channel(c_name)
    text_channel.topic = "Private chat for all those in the voice channel '**#{voice_channel.name}**'"
		text_channel.topic = 'Private chat room for DJ commands' if c_name == 'Music'
		
		text_channel.send_message "Use `!rename` or `!rename 'Any of Your Teachers'` to change the name of your voice-channel!\n---"
		
    # Set permissions
    Discordrb::API.update_role_overrides($token, text_channel.id, server.roles.find{|r| r.name == "bots"}.id, perms.bits, 0)
    Discordrb::API.update_user_overrides($token, text_channel.id, user.id, perms.bits, 0)
    Discordrb::API.update_role_overrides($token, text_channel.id, server.id, 0, perms.bits)

    # Link the id's of both channels together
    begin
	  puts 'Linking channels'
      $hierarchy[voice_channel.id] = text_channel.id
    rescue RuntimeError
	  puts 'Failed to link channels, retrying...'
      sleep 1
      $hierarchy[voice_channel.id] = text_channel.id
    end

    # Remove the user's perms in all other 'voice-channel'
    $hierarchy.each do |_, text_id|
      next if text_channel.id == text_id

      begin
		#puts "2) Removing #{user.display_name} from #voice-channel for #{voice_channel.name}"
	    Discordrb::API.update_user_overrides($token, text_id, user.id, 0, 0)
      rescue => e
        puts "1) Failed to update user overrides:\n#{e}"
      end
    end
	# User now only has perms for associated #voice-channel
  else
    #puts "Adding #{user.display_name} to #voice-channel for #{voice_channel.name}."
    # Remove the user's perms in all other 'voice-channel'
    $hierarchy.each do |_, text_id|
	  next if text_id == text_channel.id
      begin
		#puts "2) Removing #{user.display_name} from #voice-channel for #{voice_channel.name}"
		Discordrb::API.update_user_overrides($token, text_id, user.id, 0, 0)
      rescue => e
        puts "2) Failed to update user overrides:\n#{e}"
      end
    end
	# Give them view perms in the proper #voice-channel
	Discordrb::API.update_user_overrides($token, text_channel.id, user.id, perms.bits, 0)
  end

end
# ---------------

module VoiceChannelEvents
  extend Discordrb::EventContainer

  perms = Discordrb::Permissions.new
  perms.can_read_message_history = true
  perms.can_read_messages = true
  perms.can_send_messages = true
  
  channel_delete do |event|
    unless event.type == 'text'
      begin
        event.server.text_channels.find { |t| t.id == $hierarchy[event.id] }.delete
        $hierarchy.delete event.id
      rescue;end
    end
  end
  
  voice_state_update do |event|
    #puts 'VOICE STATE UPDATE: '
    #unless event.channel.nil?
    #  puts "| #{event.channel.name} | #{event.channel.users.length} users"
    #end
    
    server = event.server

    # The voice-channel the user was in at the last event
    old_voice_channel = $voice_states[event.user.id]

    handle_room(event, event.channel) unless event.channel.nil?
    rooms = server.voice_channels.find_all { |c| c.name.include?('Room ') and !c.name.include?('Group ') and c.users.empty? }
    rooms.each do |r|
      # Empty Room ____'s
      next if !event.channel.nil? and r.id == event.channel.id
      handle_room(event, r)
    end

    # Associated voice-channels
    if !event.channel.nil? and event.channel.name != 'AFK'
      handle_associated_channel(server, event.user.on(server), event.channel, perms)
    else
	  # Remove the user's perms in all other 'voice-channel' since they are not in a voice channel anymore
      $hierarchy.each do |_, text_id|
        text_channel = server.text_channels.find { |t| t.id == text_id }
		begin
		  text_channel.define_overwrite(event.user, 0, 0)
		rescue => e
          puts "Failed to update overrides:\n#{e}"
        end
      end
    end

    # Account for hierarchy mismatches
    server.text_channels.find_all { |c| c.name == 'voice-channel' }.each do |c|
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
      handle_grade_voice_channels(server)
      # There was a change
      unless old_voice_channel.nil?
        # Left a voice channel
        begin
          server.text_channels.find { |c| c.id == $hierarchy[old_voice_channel] }.send_message("**#{member.display_name}** *has left the voice channel.*", true) # Message old #voice-channel about leaving
        rescue
          #puts 'Failed to send leave message. Perhaps AFK channel?'
        end
      end
      unless current_voice_channel.nil?
        # In new voice channel
        begin
          server.text_channels.find { |c| c.id == $hierarchy[current_voice_channel] }.send_message("**#{member.display_name}** *has joined the voice channel.*", true) # Message new #voice-channel about joining
        rescue
          #puts 'Failed to send join message. Perhaps AFK channel?'
        end
      end
    end

    handle_game_parties(server)

    $voice_states[event.user.id] = current_voice_channel
  end
end
