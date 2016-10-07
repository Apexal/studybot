module StartupEvents
  extend Discordrb::EventContainer
  ready do |event|
    bot = event.bot
    puts 'Ready!'
    server = bot.server(150_739_077_757_403_137)
    # text-channel perms
    perms = Discordrb::Permissions.new
    perms.can_read_message_history = true
    perms.can_read_messages = true
    perms.can_send_messages = true
    # Removing #voice-channel's
		puts 'Setting up user command perms'
		vrole = server.roles.find { |r| r.name == 'Verified' }
		server.members.each do |m|
			next if m.id == 152621041976344577 or m.id == 152189849284247553
			event.bot.set_user_permission(m.id, 1) if m.role?(vrole)
		end
		puts 'Done.'

    puts 'Reading DB for channel links'
    $db.query('SELECT * FROM channel_links').each do |row|
      $hierarchy ||= {}
      $hierarchy[Integer(row['voice_channel_id'])] = Integer(row['text_channel_id'])
    end
    
    music_room_id = 223570352385687552
    music_channel_id = 224644696838766592
    $hierarchy[music_room_id] = music_channel_id
    
    server.voice_channels.find_all { |r| r.name != 'AFK' and r.name != $OPEN_ROOM_NAME }.each do |c|
      puts $hierarchy.values.join ' '
      puts $hierarchy[c.id]
      text_channel = server.text_channels.find { |t| t.id == $hierarchy[c.id] }
      if text_channel.nil?
        puts "Making #voice-channel for #{c.name}"
        # THERE ISN'T AN ASSOCIATED #voice-channel
        text_channel = c.name == 'Music Room' ? server.text_channels.find { |t| t.name == 'music' } : server.create_channel('voice-channel')
        text_channel.topic = c.name == 'Music Room' ? 'Private chat room for DJ commands.' : "Private chat for all those in the voice channel '**#{c.name}**'"
        Discordrb::API.update_role_overrides(bot.token, text_channel.id, server.id, 0, perms.bits)
        $hierarchy[c.id] = text_channel.id
      end
      c.users.each do |u|
        Discordrb::API.update_user_overrides(bot.token, text_channel.id, u.id, perms.bits, 0)
        $voice_states[u.id] = c.id
      end
      
    end
    
    $hierarchy.each do |vc_id, _|
      $hierarchy.delete(vc_id) if server.voice_channels.find { |v| v.id == vc_id }.nil?
    end
    
    server.text_channels.find_all { |t| t.name == 'voice-channel' and !$hierarchy.values.include? t.id }.each do |t|
      begin
        puts "DELETING #{t.topic}"
        t.delete
      rescue
        puts 'Couldn\'t delete #voice-channel!'
      end
    end
    puts 'Done.'

    puts 'Setting user statuses'
    server.online_members.each do |m|
      $playing[m.id] = m.game if !!m.game
      # puts("#{m.display_name} is playing #{m.game}") if !!m.game
    end

    puts 'Done.'
    puts "Deleting extra [New Room]'s"
    newrooms = server.voice_channels.find_all { |c| c.name == '[New Room]' }
    count = newrooms.length
    if count > 1
      newrooms.each do |c|
        c.delete if count > 1
        count -= 1
        sleep 0.5
      end
    end
    puts 'Done.'





    puts 'Done.'
    # Doing group voice channels
    puts 'Doing group voice channels'
    handle_group_voice_channels(server)
    puts 'Doing game parties'
    handle_game_parties(server)
    handle_public_room(server)
    handle_grade_voice_channels(server)
    puts 'Done.'
    puts "FINISHED STARTUP\n------------------------------------------------\n"
  end
end
