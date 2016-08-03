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

def delete_channel(server, channel, count=1)
  return if channel.nil?

  puts "Deleting voice-channel #{channel.name} and associated #voice-channel"
  begin
    channel.delete
  rescue
    puts 'Failed to delete voice-channel'
  end
  begin
    server.text_channels.find{|t| t.id == $hierarchy[channel.id]}.delete
    $hierarchy.delete channel.id
  rescue => e
    puts 'Failed to find/delete associated #voice-channel'
    puts e
    if count < 2
      sleep 1.1
      delete_channel(server, channel, count + 1)
    end
  end
end

$groups = nil
def handle_group_voice_channels(server)
  if $groups.nil?
    $groups = $db.query('SELECT * FROM groups WHERE creator != "server"')
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

    minimum = (total_count * 0.25).floor > 5 ? (total_count * 0.25).floor > minimum : 5 
    minimum = 10 if minimum > 10

    if count > minimum
      if channel.nil? and server.voice_channels.find { |c| c.name == row['name'] }.nil?
        puts "Opening group voice channel for #{row['name']}"
        channel = server.create_channel("Group #{row['name']}", 'voice')
        study_role = server.roles.find { |r| r.name == "studying" }
        channel.define_overwrite(group_role, perms, 0)
        Discordrb::API.update_role_overrides($token, channel.id, server.id, 0, perms.bits)
        study_perms = perms
        study_perms.can_speak = true
        channel.define_overwrite(study_role, 0, study_perms)
      end
    else
      delete_channel(server, channel) unless channel.nil?  or !channel.users.empty?
      # puts 'Less than 5 online members in #{row['name']}'
    end
  end
end
