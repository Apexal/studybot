module UtilityEvents
  extend Discordrb::EventContainer
  
  
end

module UtilityCommands
  extend Discordrb::Commands::CommandContainer
	
	command(:flag, description: 'Show the official Regis Discord flag!') do |event|
		event.channel.send_file(File.open('./flag.png', 'rb'))
		'Designed by *Liam Quinn*'
	end
	
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

  command(:adv, description: 'List all users in an advisement. Usage: `!adv` or `!adv advisement`') do |event, adv|
    if adv
      adv = $db.escape(adv).upcase
      if event.message.mentions.length == 1
        adv = $db.query("SELECT advisement FROM students WHERE discord_id=#{event.message.mentions.first.id}").first['advisement']
      end
      query = "SELECT * FROM students WHERE verified=1 AND advisement LIKE '#{adv}%' ORDER BY advisement ASC"
      event << "**:page_facing_up: __Listing All Users in #{adv}__ :page_facing_up:**"

      results = $db.query(query)
      results.each do |row|
        user = event.bot.user(row['discord_id'])
        if user
          event << "`-` #{user.mention} #{row['first_name']} #{row['last_name']}"
        end
      end
      event << "*#{results.count} total*"
    else
      total_users = 0
      event << '**:page_facing_up: __Advisement Statistics__ :page_facing_up:**'
      results = $db.query('SELECT advisement, COUNT(*) as count FROM students WHERE verified=1 GROUP BY advisement')
      results.each do |row|
        total_users += row['count']
        event << "`-` **#{row['advisement']}** *#{row['count']} users*"
      end
      event << "*#{results.count} total advisements*"
      event << "*#{total_users} total users*"
    end
    return ''
  end
end

module Suppressor
  extend Discordrb::EventContainer

  message(containing: 'discord.gg') do |event|
    event.message.delete
    event.user.pm "I wouldn't do that if I were you."
  end
  
  message(containing: 'https://images-2.discordapp.net/.eJwdyEsOhCAMANC7cAB-5WO8DUGCRm0JrXExmbtPMm_5PuqZl1rVLjJ4NWY7uNLcNAvN0pvuRP1qZRysK92miJS63w2FjcsBfPDWpuRzciH7f8ECANEu0bpok3nwRHpRD-zq-wMENyLF.r1RzJEKXNF2LyuWCKw2ZUDYfOc8.png?width=400&height=227') do |event|
      event.message.delete
  end
  
end
