module UtilityEvents
  extend Discordrb::EventContainer

  message(containing: '@online') do |event|
    # server = event.bot.server(150739077757403137)
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

  command(:whois, description: 'Returns information on the user mentioned. Usage: `!whois @user`') do |event|
    # Get user mentioned or default to sender of command
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
      # event << result['mpicture']
    else
      "*#{who.name}* is not yet registered!"
    end
  end
end

module Suppressor
  extend Discordrb::EventContainer

  message(containing: 'discord.gg') do |event|
    event.message.delete
  end
end
