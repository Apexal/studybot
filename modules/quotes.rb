module QuoteCommands
  extend Discordrb::Commands::CommandContainer

  command(:addquote, description: 'Quote someone!') do |event, quote|
    if quote != nil and quote.start_with? "<@"
      quote = nil
    end
    server = event.bot.server(150739077757403137)
    speaker = event.user
    # Get first mentioned user to attribute quote to or if none is attributed use sender
    speaker = event.message.mentions.last unless event.message.mentions.empty?
    sid = speaker.id

    speaker = $db.query("SELECT * FROM students WHERE discord_id=#{speaker.id}")
    # If user who sent message has linked Regis account (99.99% probability)
    user = $db.query("SELECT * FROM students WHERE discord_id=#{event.user.id}")

    # Make sure both user and speaker exist
    if user.count > 0 && speaker.count > 0
      user = user.first
      speaker = speaker.first

      if quote == nil
        botrole = server.roles.find { |r| r.name == 'bots' }

        if event.message.mentions.last != nil
          quote = event.channel.history(30).find {|m| m.content.start_with?("!") == false and m.content.start_with?("?") == false and m.author.roles[server.id].include?(botrole) == false and m.author.id == sid}
        else
          quote = event.channel.history(30).find {|m| m.content.start_with?("!") == false and m.content.start_with?("?") == false and m.author.roles[server.id].include?(botrole) == false }
          speaker = $db.query("SELECT * FROM students WHERE discord_id=#{quote.author.id}").first # Yikes
        end

        if quote == nil
          event << "Failed to find quote."
          return
        end
        quote = quote.content
      end

      quote = quote.gsub '"', "'" # Turn array of words into text and remove quotes if added
      quote = $db.escape(quote) # Escape text so no SQL injection

      if quote.length > 450
        event << "Quote too long!"
        return
      end

      query = "INSERT INTO quotes (user, text, attributed_to, date) VALUES ('#{user['username']}', '#{quote}', '#{speaker['username']}', '#{Time.now.strftime('%F')}')"
      $db.query(query)
      "Saved quote: *\"#{quote}\"* by #{speaker['first_name'] + " " + speaker['last_name']}"
    else
      'Unknown sender...'
    end
  end

  command(:quotes, description: 'List all of your quotes!') do |event|
	if event.channel.name == "work"
	  event.user.pm "Quotes can not be viewed in #work! Try #recreation."
	  return
	end

    query = ""
    method = :other
    user = event.user

    if event.message.mentions.first != nil
      user = event.message.mentions.first
      query = "SELECT quotes.id, quotes.user, quotes.text, quotes.attributed_to, quotes.date FROM quotes INNER JOIN students ON quotes.attributed_to=students.username WHERE students.discord_id=#{user.id}"
    else
      method = :self
      query = "SELECT quotes.id, quotes.user, quotes.text, quotes.attributed_to, quotes.date FROM quotes INNER JOIN students ON quotes.user=students.username WHERE students.discord_id=#{user.id}"
    end

    event.send_message "**__Quotes#{method == :self ? " Recorded By" : " From"} #{user.name}__**"

    index = 1
    messages = []

    $db.query(query).each_slice(20) do |rows|
      rows.each do |row|
        m = "`#{row['id']}` *\"#{row['text']}\"* "
        if method == :self
          m << "**~#{row['attributed_to']}**"
        end
        messages << m
        index += 1
      end
      event.send_message messages.join "\n"
      messages = []
    end

    "#{index-1} total"
  end

  command(:delquote, description: 'Delete a quote.') do |event, *indexes|
  	if event.channel.name == "work"
  	  event.user.pm "Quotes can not be viewed in #work! Try #recreation."
  	  return
  	end

    if indexes.empty?
      event << 'Invalid number(s).'
      return
    end

    query = "DELETE quotes FROM quotes INNER JOIN students ON quotes.user=students.username WHERE students.discord_id=#{event.user.id} AND quotes.id IN (#{indexes.join(', ')})"
    $db.query(query)
    'Deleted quote(s).'
  end
 end
