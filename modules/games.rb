module GameEvents
  extend Discordrb::EventContainer

  # Stores info on who is playing what
  $playing = {}

  playing do |event|
    server = event.server
    game = event.game
	
	to_delete = []
	
    # DiscordDJ says it plays whatever song it is on
    if event.user.name != 'DiscordDJ'
      joining = (!!game ? true : false)

      if joining == false
        # Leaving game
        game = $playing[event.user.id]
		#to_delete << event.bot.find_channel('gaming').first.send_message("**#{event.user.on(server).display_name}** is no longer playing **#{game}**")
      else
        # Joining game
        $playing[event.user.id] = game
		#to_delete << event.bot.find_channel('gaming').first.send_message("**#{event.user.on(server).display_name}** is now playing **#{game}**")
      end

      user_id = event.user.id
      game_channel = server.voice_channels.find {|c| c.name == $playing[user_id]}

      if joining
        if game_channel.nil? && $playing.values.count(game) >= 4
          puts "Creating Room for #{event.user.game}"
          game_channel = server.create_channel($playing[event.user.id], 'voice')
		  to_delete << event.bot.find_channel('gaming').first.send_message("@everyone Looks like a **#{$playing[event.user.id]}** party is starting! Join it!")
        end
      else
        puts "Deleting rooms for #{$playing[event.user.id]}"
        gname = $playing[event.user.id]
        $playing.delete(event.user.id)

        # If nobody is playing the game anymore
        if $playing.count(gname) < 1
          # Move all people inside to the Music channel
          unless game_channel.nil?
            puts 'Move everyone to #music'
            musicchannel = server.voice_channels.find { |c| c.name == 'Music' }
            game_channel.users.each { |u| event.server.move(u, musicchannel) }
            game_channel.delete
            # Unlink text channel to voice channel
            puts 'Unlinking voice and text channels'
            begin
              server.text_channels.find{|t| t.id == $hierarchy[game_channel.id]}.delete
              $hierarchy.delete game_channel.id
            rescue

            end
          end
        end
      end
    end
	
	sleep 60 * 20 # 20 minutes
	to_delete.each(&:delete)
  end
end
