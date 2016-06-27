module UtilityEvents
    extend Discordrb::EventContainer
end

module UtilityCommands
    extend Discordrb::Commands::CommandContainer
    command(:flag, description: 'Show the official Regis Discord flag!') do |event|
        event.channel.send_file(File.open('./flag.png', 'rb'))
        'Designed by *Liam Quinn*'
    end
    
    grades = ['freshmen', 'sophomores', 'juniors', 'seniors']
    special = {"memes" => "Memes", "testing" => "Testing", "gaming" => "Gaming"}
   
    command(:study, description: 'Toggle your ability to see non-work text channels to focus!', bucket: :study) do |event|
        if !event.message.channel.private?
            event.message.delete
        end
        server = event.bot.server(150739077757403137)
        studyrole = server.roles.find{|r| r.name=="studying"}
        user = event.user.on(server)
        clean_name = user.display_name
        clean_name.sub! "[S] ", ""
        perms = Discordrb::Permissions.new
        perms.can_read_messages = true
        perms.can_read_message_history = true
        perms.can_send_messages = true
        if user.role? studyrole
            user.nickname = clean_name
            user.remove_role studyrole
            # Issue for grade channels
            grades.each do |g|
                role = server.roles.find{|r| r.name==g}
                if role.nil? == false and user.role? role
                    grade_channel = server.text_channels.find{|c| c.name==g}
                    Discordrb::API.update_user_overrides(event.bot.token, grade_channel.id, user.id, 0, 0)
                end
            end
            # For the special channels
            special.each do |c_name, r_name|
                role = server.roles.find{|r| r.name==r_name}
                channel = server.text_channels.find{|c| c.name==c_name}
                if user.role? role
                    Discordrb::API.update_user_overrides(event.bot.token, channel.id, user.id, 0, 0)
                end
            end
        else
            # GOING INTO STUDYMODE
            user.nickname = "[S] #{clean_name}"[0..30]
            user.add_role studyrole
            # Issue for grade channels
            grades.each do |g|
                role = server.roles.find{|r| r.name==g}
                if role.nil? == false and user.role? role
                    grade_channel = server.text_channels.find{|c| c.name==g}
                    Discordrb::API.update_user_overrides(event.bot.token, grade_channel.id, user.id, 0, perms.bits)
                end
            end
            # For the special channels
            special.each do |c_name, r_name|
                role = server.roles.find{|r| r.name==r_name}
                channel = server.text_channels.find{|c| c.name==c_name}
                if user.role? role
                    Discordrb::API.update_user_overrides(event.bot.token, channel.id, user.id, 0, perms.bits)
                end
            end
        end
        nil
    end
    command(:color, description: 'Set your color! Usage: `!color colorname`') do |event, color|
        server = event.server
        colors = %w(red orange yellow dark pink purple blue green)
        if colors.include?(color) || color == 'default'
            croles = server.roles.find_all { |r| colors.include? r.name }
            event.user.remove_role croles
            if color != "default"
                event.user.add_role croles.find{ |r| r.name == color}
            end
            "Successfully changed user color!"
        else
            "The available colors are **#{colors.join ', '}, and default**."
        end
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
    command(:rules, description: 'Show the rules of the server') do |event|
        event << "__***Server Rules***__ :bookmark_tabs:"
        event << "`1` Don't be a jerk."
        event << "`2` Report any and all abuse directly to the Owner <@152621041976344577>."
        event << "`3` Do not post any sexual content."
    end
end

module Suppressor
    extend Discordrb::EventContainer

    message(containing: not!("google.com/"), in: "#finals") do |event|
        if event.message.author != event.server.owner
            event.message.delete
        end
    end
end
