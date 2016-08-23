module UtilityCommands
  extend Discordrb::Commands::CommandContainer

  command(:guestinfo, description: 'Set name and school for a guest. Usage: `!guestinfo "Name" "School"`') do |event, name, school|
    event.message.delete unless event.channel.private?
    server = event.bot.server(150_739_077_757_403_137)
    user = event.user.on(server)

    unless user.role? server.roles.find { |r| r.name == 'Guests' }
      user.pm 'Only guests can use that command!'
      return
    end


    # Cancel if no passed args
    if name.nil? and school.nil?
      user.pm 'Use the `!guestinfo` command like this: `!guestinfo "Your Name" "Your School"`.'
      return
    end

    name = $db.escape(name)
    school = $db.escape(school) unless school.nil?

    query = "INSERT INTO guests (discord_id, name, school) VALUES ('#{user.id}', '#{name}', '#{school}') ON DUPLICATE KEY UPDATE name='#{name}', school='#{school}'"
    query = "INSERT INTO guests (discord_id, name) VALUES ('#{user.id}', '#{name}') ON DUPLICATE KEY UPDATE name='#{name}'" if school.nil?

    $db.query(query)

    user.pm "Updated your info! It will be shown when somebody uses `!whois @#{user.display_name}`"

    puts "Updated guest info for #{user.display_name}"
    return nil
  end
end
