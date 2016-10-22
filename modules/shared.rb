def save_hierarchy
  puts 'Saving hierarchy to DB'
  $db.query('DELETE FROM channel_links')
  $hierarchy.each do |vc_id, tc_id|
    puts "#{vc_id} | #{tc_id}"
    $db.query("INSERT INTO channel_links VALUES ('#{vc_id}', '#{tc_id}') ON DUPLICATE KEY UPDATE text_channel_id='#{tc_id}'")
  end
end

def replace_mentions(message)
  message.strip!
  message.gsub! '**', ''
  message.gsub! '@everyone', '**everyone**'
  message.gsub! '@here', '**here**'
  words = message.split ' '
  done = []
  words.each_with_index do |w, i|
    w.sub!('(', '')
    w.sub!(')', '')
    w.sub!('"', '')
    if w.start_with? '<@' and w.end_with? '>'
      id = w.sub('<@!', '').sub('<@', '').sub('>', '') # Get ID 
      if !done.include? id and /\A\d+\z/.match(id)
        user = $db.query("SELECT username FROM students WHERE discord_id=#{id}")
        if user.count > 0
          user = user.first
          rep = "**@#{user["username"]}**" # replacement
          message.gsub! "<@#{id}>", rep # Only works when they don't have a nickname
          message.gsub! "<@!#{id}>", rep
        end
        done << id
      end
    end
  end

  return message.sub('@', '') if words.length == 1 and done == 1
  return message
end

def handle_public_room(server)
  perms = Discordrb::Permissions.new
  perms.can_connect = true
  perms.can_speak = true
  perms.can_use_voice_activity = true

  guest_role = server.roles.find { |r| r.name == 'Guests' }
  online_count = server.online_members.count { |m| m.role? guest_role }
  public_room = server.voice_channels.find { |v| v.name == 'Public Room' }
  if online_count > 0 and public_room.nil?
    puts 'Creating Public Room'
    public_room = server.create_channel('Public Room', 'voice')
    public_room.position = 1
    study_role = server.roles.find { |r| r.name == 'studying' }
    public_room.define_overwrite(study_role, 0, perms)
    Discordrb::API.update_role_overrides($token, public_room.id, server.id, perms.bits, 0)
  elsif online_count == 0 and !public_room.nil?
    delete_channel(server, public_room)
  end
end

def sort_channels(server)
  start_pos = 14
  %w(1 2 3 4).each do |g|
    channels = server.text_channels.find_all { |c| c.name.start_with? g }
      # channels.sort { |a, b| a.position <=> b.position }.first.position

    pos = start_pos
    channels.sort { |a, b| a.name <=> b.name }.each do |c|
      c.position = pos
      pos += 1
      sleep 1
    end

    start_pos += (channels.length-1)
    sleep 1
  end
end

def delete_channel(server, channel, count=1)
  return if channel.nil? or channel.name == 'AFK'

  puts "Deleting voice-channel #{channel.name} and associated #voice-channel"
  unless channel.users.empty?
    puts 'Moving users first'
    begin
      new_room = server.voice_channels.find { |r| r.name == $OPEN_ROOM_NAME }
      channel.users.each do |u|
        server.move(u, new_room)
      end
    rescue => e
      puts "Failed to move all users:\n#{e}"
    end
  end
  begin
    channel.delete
  rescue => e
    puts "Failed to delete voice-channel:\n#{e}"
  end

  return if server.text_channels.find { |t| t.id == $hierarchy[channel.id] }.nil?

  # begin
    # server.text_channels.find { |t| t.id == $hierarchy[channel.id] }.delete
    # $hierarchy.delete channel.id
  # rescue => e
    # puts 'Failed to find/delete associated #voice-channel'
    # puts e
    # if count < 2
      # sleep 1.1
      # delete_channel(server, channel, count + 1) # Is this recursion?
    # end
  # end
end

$groups = nil
def handle_group_voice_channels(server)
  if $groups.nil?
    $groups = $db.query('SELECT * FROM groups WHERE voice_channel_allowed=1')
  end

  $groups.each do |row|
    group_role = server.roles.find{|r| r.id==Integer(row['role_id'])}
    next if group_role.nil?

    # Get count of online group members
    total_count = server.members.find_all { |m| m.role? group_role }.length
    count = server.online_members.find_all { |m| m.role? group_role }.length
    channel = server.voice_channels.find { |c| c.name == "Group #{row['name']}" }
    perms = Discordrb::Permissions.new
    perms.can_connect = true

    #minimum = (total_count * 0.25).floor > 5 ? (total_count * 0.25).floor > minimum : 5 
    #minimum = 10 if minimum > 10
    minimum = 4
    
    if count > minimum
      # if channel.nil? and server.voice_channels.find { |c| c.name == row['name'] }.nil?
        # puts "Opening group voice channel for #{row['name']}"
        # channel = server.create_channel("Group #{row['name']}", 'voice')
        # study_role = server.roles.find { |r| r.name == 'studying' }
        # channel.define_overwrite(group_role, perms, 0)
        # Discordrb::API.update_role_overrides($token, channel.id, server.id, 0, perms.bits)
        # study_perms = perms
        # study_perms.can_speak = true
        # channel.define_overwrite(study_role, 0, study_perms)
      # end
    elsif count <= 2 and !channel.nil? and channel.users.empty?
      delete_channel(server, channel) unless channel.nil?  or !channel.users.empty?
      # puts 'Less than 5 online members in #{row['name']}'
    end
  end
end


$timings = {}
def handle_game_parties(server)
  game_role = server.roles.find { |r| r.name == 'Gaming' }
  game_channel = server.text_channels.find { |c| c.name == 'gaming' }
  server.voice_channels.find_all { |v| !v.name.include? 'Group ' and (v.name.end_with? ' Party' or v.name.include? 'Room ') }.each do |v|
    game_totals = Hash.new(0)
    user_count = v.users.length

    v.users.each do |u|
      next if u.game.nil?
      game_totals[u.game] += 1
    end

    next if user_count < 4

    game_totals.each do |game, t|
      next if v.name == "#{game} Party"

      next if t <= 2

      min = 0.75 # If only a few people are in the room, all must be playing the game
      percent = t / user_count.to_f

      next if percent < min
			
			# 5 minutes between game parties (prevent spam)
			next if !$timings[game].nil? and (Time.new - $timings[game]) < 60 * 10 # 10 minutes
			
			# ITS A PAAAAARTY
			$timings[game] = Time.new
      v.name = "#{game} Party"
      server.text_channels.find { |c| c.id == $hierarchy[v.id] }.topic = "Private chat for all those in the voice channel '#{game} Party'."
      puts "Started #{game} Party room"

      short_name = game.downcase.strip.gsub(/[^\p{Alnum}-]/, '')
			
      possible = $db.query("SELECT game_interests.discord_id FROM game_interests JOIN games ON games.id=game_interests.game_id WHERE games.short_name='#{short_name}'").map { |row| server.member(Integer(row['discord_id'])) }
      #mentions = server.online_members.find_all { |u| u.role? game_role and !v.users.include? u and u.game.nil? }.map { |u| u.mention }
      mentions = possible.find_all { |u| u.role? game_role and !v.users.include? u and u.game.nil? }.map { |u| u.mention }
      
      game_channel.send_message "A #{game} session has started. Join voice-channel **#{game} Party**: #{mentions.join ' '}"
      break
    end
    sleep 1
  end

  server.voice_channels.find_all { |v| !v.name.include? 'Group ' and v.name.end_with? ' Party'}.each do |v|
    game_totals = Hash.new(0)
    v.users.each do |u|
      next if u.game.nil?
      game_totals[u.game] += 1
    end

    if v.users.empty?
      delete_channel(server, v)
    elsif v.users.length <= 2 or game_totals.max_by{ |k, v| v }[1] <= 2
      teacher = get_rand_teacher(v.users.first)
      v.name = "Room #{teacher}"
      server.text_channels.find { |c| c.id == $hierarchy[v.id] }.topic = "Private chat for all those in the voice channel 'Room #{teacher}'."
    else
    end
    sleep 0.5
  end
end
