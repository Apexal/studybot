module GameEvents
  extend Discordrb::Commands::CommandContainer
  
  command(:optin, min_args: 1, max_args: 1, description: 'Choose to be mentioned when a specific game party starts.', usage: '`!optin "Game"` (don\'t forget the quotes!)', permission_level: 1) do |event, game|
    event.message.delete unless event.channel.private?
    
    unless event.channel.name == 'gaming'
      event.user.pm 'You must be in the Gaming group to use this command. And you must type it in #gaming'
      return
    end
    
    server = event.bot.server(150_739_077_757_403_137)
    user = event.user.on(server)
    
    short_name = $db.escape(game).downcase.strip.gsub(/[^\p{Alnum}-]/, '')
    
		game_id = $db.query("SELECT id FROM games WHERE short_name='#{short_name}'").first
		if game_id.nil?
			user.pm "That game isn't in the list yet. Someone on the server must play the game at least once to add it to the list."
			return
		end
		game_id = game_id['id']
		
    begin
      $db.query("INSERT INTO game_interests VALUES ('#{user.id}', #{game_id})")
      user.pm "You have been opted in for **#{game} Party announcements.**"
      puts "#{event.user.name} has opted-in for #{game} announcements."
    rescue => e
			#puts e
      user.pm "You're already opted in for **#{game}**."
    end
    
    nil
  end
  
  command(:optout, min_args: 1, max_args: 1, description: 'Choose *not* to be mentioned when a specific game party starts.', usage: '`!optout "Game"` (don\'t forget the quotes!)', permission_level: 1) do |event, game|
    event.message.delete unless event.channel.private?
    server = event.bot.server(150_739_077_757_403_137)
    user = event.user.on(server)
    
		short_name = $db.escape(game).downcase.strip.gsub(/[^\p{Alnum}-]/, '')
    
    $db.query("DELETE game_interests FROM game_interests JOIN games ON games.id=game_interests.game_id WHERE game_interests.discord_id='#{user.id}' AND games.short_name='#{short_name}'")
    user.pm "You have been opted out of **#{game} Party announcements.**"
    puts "#{event.user.name} has opted-out of #{game} announcements."
    nil
  end
end

module GameEvents
  extend Discordrb::EventContainer

  # Stores info on who is playing what
  $playing = {}
	
  playing do |event|
    server = event.server
    game = event.game
    to_delete = []
    
    # DiscordDJ says it plays whatever song it is on
    if event.user.id != 195674370826436609
      joining = (!!game ? true : false)

      if joining == false
        # Leaving game
        game = $playing[event.user.id]
        #to_delete << event.bot.find_channel('gaming').first.send_message("**#{event.user.on(server).display_name}** is no longer playing **#{game}**")
      else
        # Joining game
        $playing[event.user.id] = game
				short_name = game.downcase.strip.gsub(/[^\p{Alnum}-]/, '')
				
				if $db.query("SELECT COUNT(*) as count FROM games WHERE full_name='#{$db.escape(game)}'").first['count'] == 0
					$db.query("INSERT INTO games (full_name, short_name) VALUES ('#{$db.escape(game)}', '#{$db.escape(short_name)}')")
					puts "Added #{game} to game list."
				end
        #to_delete << event.bot.find_channel('gaming').first.send_message("**#{event.user.on(server).display_name}** is now playing **#{game}**")
      end

      user_id = event.user.id
      game_channel = server.voice_channels.find {|c| c.name == $playing[user_id]}

      if joining
        if game_channel.nil? && $playing.values.count(game) >= 4
          puts "Creating Room for #{event.user.game}"
          #game_channel = server.create_channel($playing[event.user.id], 'voice')
          #to_delete << event.bot.find_channel('gaming').first.send_message("@everyone Looks like a **#{$playing[event.user.id]}** party is starting! Join the voice channel!")
          # Annoyingly DMing each person playing the game
          #server.online_members.find_all { |m| m.game == game }.each do |m|
          #  m.pm "Playing **#{game}** with others? Join the designated voice channel for your game!"
          #end
        end
      else
        gname = $playing[event.user.id]
        $playing.delete(event.user.id)

        # If nobody is playing the game anymore
        if $playing.values.count(gname) < 1
          # Move all people inside to a new room
          unless game_channel.nil?
            puts "Deleting rooms for #{$playing[event.user.id]}"
            puts 'Move everyone to a new room'
            newchannel = server.voice_channels.find { |c| c.name == '[New Room]' }
            game_channel.users.each do |u|
              event.server.move(u, newchannel)
              sleep 0.5
            end
            delete_channel(server, game_channel)
          end
        end
      end
    end

    handle_game_parties(server)

    sleep(60 * 20) # 20 minutes
    to_delete.each(&:delete)
  end
end
