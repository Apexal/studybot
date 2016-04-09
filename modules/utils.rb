module UtilityEvents
  extend Discordrb::EventContainer

  message(containing: '@online') do |event|
    mentions = []
    event.channel.users.each do |user|
      if [:online, :idle].include?(user.status) && (!['studybot', 'SuperUser', 'JunkBot', 'testing-bot', 'DiscordDJ'].include? user.name)
        mentions.push(user.mention)
      end
    end

    event.channel.send_message mentions.join(' ')
  end
end

module UtilityCommands
  extend Discordrb::Commands::CommandContainer

  command(:whois, description: 'Returns information on the user mentioned. Usage: `!whois @user or !whois regisusername`') do |event, username|
    # Get user mentioned or default to sender of command
    if username != nil and !username.start_with?("<@")
      # Prevent nasty SQL injection
      username = $db.escape(username)
      result = $db.query("SELECT * FROM students WHERE username='#{username}'")
      if result.count > 0
        result = result.first
        user = event.bot.user(result['discord_id'])
        event << "**#{result['first_name']} #{result['last_name']}** of **#{result['advisement']}** is #{user.mention()}!"
      else
        event << "*#{username}* is not yet registered!"
      end
      return
    end

    # Otherwise go off of mentions
    who = event.user
    who = event.message.mentions.first unless event.message.mentions.empty?

    # SuperUser shenanigans
    if who.name == 'studybot'
      event << '*I am who I am.*'
      return
    end

    # Find a student with the correct discord id
    result = $db.query("SELECT * FROM students WHERE discord_id=#{who.id}")
    if result.count > 0
      result = result.first
      event << "*#{who.name}* is **#{result['first_name']} #{result['last_name']}** of **#{result['advisement']}**!"
    else
      "*#{who.name}* is not yet registered!"
    end
  end
end

module Suppressor
  extend Discordrb::EventContainer

  message(containing: 'discord.gg') do |event|
    event.message.delete
    event.user.pm "I wouldn't do that if I were you."
  end
end
