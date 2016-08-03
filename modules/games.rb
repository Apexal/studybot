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

    server.voice_channels.find_all { |v| !v.name.include? 'Group ' and v.name.downcase.include? 'room ' and !v.users.empty? }.each do |v|
      game_totals = Hash.new(0)
      user_count = v.users.length

      v.users.each do |u|
        next if u.game.nil?
        game_totals[u.game] += 1
      end

      game_totals.each do |game, t|
        next if t <= 2

        min = user_count > 4 ? 0.8 : 1 # If only a few people are in the room, all must be playing the game
        percent = t / user_count.to_f

        next if percent < min

        v.name = "#{game} Party"
        server.text_channels.find { |c| c.id == $hierarchy[v.id] }.topic = "Private chat for all those in the voice channel '#{game} Party'."
        puts "Started #{game} Party room"
        break
      end
    end

    server.voice_channels.find_all { |v| v.name.end_with? " Party" and v.users.empty? }.each do |v|
      v.delete
      sleep 0.5
    end

    sleep(60 * 20) # 20 minutes
    to_delete.each(&:delete)
  end
end
