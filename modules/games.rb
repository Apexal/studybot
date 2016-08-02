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
          #game_channel = server.create_channel($playing[event.user.id], 'voice')
          to_delete << event.bot.find_channel('gaming').first.send_message("@everyone Looks like a **#{$playing[event.user.id]}** party is starting! Join the voice channel!")
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
    #puts($playing)
    sleep(60 * 20) # 20 minutes
    to_delete.each(&:delete)
  end
end
