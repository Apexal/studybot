module GameEvents
  extend Discordrb::EventContainer

  # Stores info on who is playing what
  $playing = Hash.new

  playing do |event|
    server = event.server
    game = event.game

    # DiscordDJ says it plays whatever song it is on
    if event.user.name != 'DiscordDJ'
	  joining = (!!game ? true : false)

      if joining == false
		# Leaving game
        game = $playing[event.user.id]
      else
		# Joining game
        $playing[event.user.id] = game
      end

      user_id = event.user.id
      game_channel = server.voice_channels.find {|c| c.name == $playing[event.user.id]}

      if joining
        if game_channel.nil? && $playing.values.count(game) >= 2
			puts "Creating Room for #{event.user.game}"
			
			game_channel = server.create_channel($playing[event.user.id], 'voice')
		end
      else
		puts "Deleting rooms for #{$playing[event.user.id]}"
        gname = $playing[event.user.id]
        $playing.delete(event.user.id)

        # If nobody is playing the game anymore
        if $playing.count(gname) < 1
          # Move all people inside to the Music channel
		  if !game_channel.nil?
			  puts "Move everyone to #music"
			  musicchannel = server.voice_channels.find { |c| c.name == "Music" }
			  game_channel.users.each { |u| event.server.move(u, musicchannel) }
			  game_channel.delete
			  
			  # Unlink text channel to voice channel
			  puts "Unlinking voice and text channels"
			begin
				server.text_channels.find{|t| t.id == $hierarchy[game_channel.id]}.delete
				$hierarchy.delete game_channel.id
			rescue

			end
		  end
        end
      end
    end
  end
end
