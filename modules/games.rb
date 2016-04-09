class DummyRoleWriter
  def write(bits); end
end

module GameEvents
  extend Discordrb::EventContainer

  # Stores info on who is playing what
  playing = {}

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

      token = event.bot.token
      user_id = event.user.id
      game_channel = server.channels.find { |c| c.name == playing[event.user.id] }

      if joining
        if game_channel.nil? && playing.values.count(game) >= 2
          Discordrb::API.create_channel(token, server.id, playing[event.user.id], 'voice')
        end
      else
        gname = playing[event.user.id]
        playing.delete(event.user.id)

        # If nobody is playing the game anymore
        if playing.value?(gname) == false
          # Move all people inside to the Music channel
          musicchannel = server.channels.find { |c| c.name == "Music" }
          game_channel.users.each { |u| event.server.move(u, musicchannel) }
          Discordrb::API.delete_channel(token, game_channel.id)
        end
      end
    end
  end
end
