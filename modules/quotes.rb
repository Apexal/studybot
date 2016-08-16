module QuoteCommands
  extend Discordrb::Commands::CommandContainer
  command(:addquote, description: 'Quote someone!', bucket: :abusable, permission_level: 1) do |event, quote, user|
    puts "Adding quote from #{event.user.name}"
    if !quote.nil? and quote.split(' ').length == 1 and quote.start_with? '<@'
      quote = nil
    end
    server = event.bot.server(150_739_077_757_403_137)
    speaker = event.user
    # Get first mentioned user to attribute quote to or if none is attributed use sender
    speaker = event.message.mentions.last unless event.message.mentions.empty?
    if !user.nil? and user.start_with? '<@'
      speaker = event.bot.parse_mention user
    end
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
          quote = event.channel.history(30).find {|m| m.content.start_with?('!') == false and m.content.start_with?('?') == false and m.author.roles.include?(botrole) == false and m.author.id == sid}
        else
          quote = event.channel.history(30).find {|m| m.content.start_with?('!') == false and m.content.start_with?('?') == false and m.author.roles.include?(botrole) == false }
          speaker = $db.query("SELECT * FROM students WHERE discord_id=#{quote.author.id}").first # Yikes
        end

        if quote.nil?
          event << 'Failed to find quote.'
          return
        end
        quote = quote.content
      end

      quote = $db.escape(quote) # Escape text so no SQL injection

      if quote.length > 450
        event << 'Quote too long!'
        return
      end
      if quote.split(' ').length == 1 and (quote.start_with?('<@') or quote == '@here' or quote == '@everyone')
        event << "You can't quote that!"
        return
      end
      query = "INSERT INTO quotes (user, text, attributed_to, date) VALUES ('#{user['username']}', '#{quote}', '#{speaker['username']}', '#{Time.now.strftime('%F')}')"
      $db.query(query)
      "Saved quote: *\"#{quote}\"* by #{speaker['first_name'] + " " + speaker['last_name']}"
    else
      'Unknown sender...'
    end
  end

  command(:quotes, description: 'List all of your quotes!', bucket: :abusable, permission_level: 1) do |event|
    if event.channel.name == "work"
      event.message.delete
      event.user.pm "Quotes are not allowed in #work!"
      return
    end
    # Store temporary messages
    toDelete = []
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
    index = 1
    messages = ["**__Quotes#{method == :self ? ' Recorded By' : ' From'} #{user.name}__**"]
    $db.query(query).each_slice(20) do |rows|
      rows.each do |row|
        text = replace_mentions(row['text']).gsub("\"", "'") # The text of the message
        m = "`#{row['id']}` *\"#{text}\"* " 
        m << "**~#{row['attributed_to']}**" if method == :self
        messages << m
        index += 1
      end
      toDelete << event.send_message(messages.join("\n"))
      messages = []
    end
    event.send_message "#{index - 1} total"

    time = 30
    if toDelete.length > 6
      time = 60 * 3
    elsif toDelete.length > 3
      time = 60
    end

    sleep(time)

    toDelete.each(&:delete)
    nil
  end

  command(:delquote, description: 'Delete a quote.', bucket: :abusable, permission_level: 1) do |event, *indexes|
    if event.channel.name == 'work'
      event.user.pm 'Quotes can not be viewed in #work! Try #recreation.'
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
