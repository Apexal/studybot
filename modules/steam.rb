module SteamCommands
  extend Discordrb::Commands::CommandContainer
  
  command(:setsteam, description: 'Set your Steam profile link. Usage: `!setsteam link`') do |event, link|
    event.message.delete unless event.channel.private?

    server = event.bot.server(150_739_077_757_403_137)
    user = event.user.on(server)
    return unless user.role? server.roles.find { |r| r.name == 'Verified' }
    
    if link.nil?
      event.user.pm 'Please pass a Steam profile link.'
      return
    end
    
    link = $db.escape(link)
    if not (/(?:https?:\/\/)?steamcommunity\.com\/(?:profiles|id)\/[a-zA-Z0-9]+/ =~ link)
      user.pm 'Please give a valid Steam profile link.'
      return
    end
    
    puts "Updating Steam profile link for #{user.display_name}"
    $db.query("UPDATE students SET steam_profile='#{link}' WHERE discord_id=#{user.id}")
    user.pm 'Successfully updated Steam profile link.'
    
    nil
  end
  
  command(:steam, description: 'Show someone\'s Steam profile link. Usage: `!steam @user`') do |event|
    if event.message.channel.name == "work"
      event.message.delete 
      event.user.pm 'Steam commands are not allowed in #work.'
      return
    end
    
    server = event.bot.server(150_739_077_757_403_137)
    user = event.user.on(server)
    return unless user.role? server.roles.find { |r| r.name == 'Verified' }
    
    to_delete = [event.message]
    
    target = event.message.mentions.empty? ? user : event.message.mentions.first.on(server)
    hits = $db.query("SELECT steam_profile FROM students WHERE discord_id=#{target.id}").map { |u| u['steam_profile'] }
    
    if hits.empty? or hits.first.nil?
      to_delete << event.channel.send_message("**#{target.display_name}** has not linked his Steam profile yet!")
    else
      link = hits.first
      link = "https://#{link}" unless link.start_with? 'http'
      to_delete << event.channel.send_message("**#{target.display_name}'s** Steam Profile: <#{link}>")
    end
    
    sleep 60 * 2
    begin
      to_delete.map(&:delete)
    rescue
      # Channel could be deleted by now
    end
    
    nil
  end
 end