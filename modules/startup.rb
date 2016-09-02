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
    puts 'Removing #voice-channels'
    server.text_channels.each do |c|
      if c.name == 'voice-channel'
        puts "Deleting ##{c.name}"
        c.delete
      end
    end
    puts 'Done.'
    puts 'Setting user statuses'
    server.online_members.each do |m|
      $playing[m.id] = m.game if !!m.game
      # puts("#{m.display_name} is playing #{m.game}") if !!m.game
      $voice_states[m.id] = nil
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
    # Create #voice-channel's for all voice channels used right now
    puts "Creating all necessary #voice-channel's and adding users to them"
    server.voice_channels.find_all { |r| r.name != 'AFK' and r.name != $OPEN_ROOM_NAME }.each do |c|
		puts c.name
      
	  text_channel = c.name == 'Music Room' ? server.text_channels.find { |t| t.name == 'music' } : server.create_channel('voice-channel')
    puts text_channel.id
	  text_channel.topic = c.name == 'Music Room' ? 'Private chat room for DJ commands.' : "Private chat for all those in the voice channel '**#{c.name}**'"
      # Give the current user and BOTS access to it, restrict @everyone
      c.users.each do |u|
        $voice_states[u.id] = c.id
        Discordrb::API.update_user_overrides(bot.token, text_channel.id, u.id, perms.bits, 0)
      end
      Discordrb::API.update_role_overrides(bot.token, text_channel.id, server.roles.find { |r| r.name == "bots" }.id, 0, perms.bits)
      Discordrb::API.update_role_overrides(bot.token, text_channel.id, server.id, 0, perms.bits)
      # Link the id's of both channels together
      $hierarchy[c.id] = text_channel.id
    end
    puts 'Done.'
    # Doing group voice channels
    puts 'Doing group voice channels'
    handle_group_voice_channels(server)
    puts 'Doing game parties'
    handle_game_parties(server)
    handle_public_room(server)
    puts 'Done.'
    puts "FINISHED STARTUP\n------------------------------------------------\n"
  end
end
