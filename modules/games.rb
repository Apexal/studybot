module GameEvents
  extend Discordrb::EventContainer

  # Stores info on who is playing what
  playing = Hash.new

  playing do |event|
    server = event.server
    game = event.game

    # DiscordDJ says it plays whatever song it is on
    if event.user.name != 'DiscordDJ'
	  joining = (!!game ? true : false)

      if joining == false
        game = playing[event.user.id]
      else
        playing[event.user.id] = game
      end

      user_id = event.user.id
      game_channel = server.voice_channels.find {|c| c.name == playing[event.user.id]}

      if joining
        if game_channel.nil? && playing.values.count(game) >= 2
		  event.server.create_channel(playing[event.user.id], 'voice')
        end
      else
        gname = playing[event.user.id]
        playing.delete(event.user.id)

        # If nobody is playing the game anymore
        if playing.count(gname) < 2
          # Move all people inside to the Music channel
		  if !game_channel.nil?
			  musicchannel = server.voice_channels.find { |c| c.name == "Music" }
			  game_channel.users.each { |u| event.server.move(u, musicchannel) }
			  game_channel.delete
		  end
        end
      end
    end
  end
end
