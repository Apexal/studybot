module RegistrationEvents
  extend Discordrb::EventContainer

  member_join do |event|
    event.user.pm "Welcome to the Regis Discord Server, **#{event.user.name}**! Please tell us who you are by typing `!register yourregisusername`. *You will not be able to participate in the server until you do this.*"
  end
end

module RegistrationCommands
  extend Discordrb::Commands::CommandContainer

  command(:register, description: "Connect your account to your Regis account. Usage: `!register regisusername`") do |event, username|
    # Check if username was passed and that its not a teacher's email
    if !!username && /^[a-z]+\d{2}$/.match(username)
      # Convert the hex username back to its string
      code = username.each_byte.map { |b| b.to_s(16) }.join

      # Send a welcome email with the command to verify
      mail = Mail.new do
        from "Regis Discord Server <#{$CONFIG["auth"]["gmail"]["username"]}@gmail.com>"
        to      "#{username}@regis.org"
        subject 'Verify Your Discord Account'

        text_part do
          body "Welcome to Discord, please verify your identity on the server by private messaging studybot '!verify #{code}' (no quotes)'."
        end

        html_part do
          content_type 'text/html; charset=UTF-8'
          body "<h1>Regis Discord Server</h1><img src='https://cdn.discordapp.com/attachments/150739077757403137/152977845621096449/flag.png'><br><p>Welcome to Discord, <b>#{event.user.name}</b>!<br> Please verify your identity on the server by sending <i>@studybot</i> the following message. After this you will be able to participate.</p> <code>!verify #{code}</code> <br><p><i>If you did not attempt to register on the server, someone is trying to impersonate you.</i></p>"
        end
      end
      mail.deliver!

      # Alert the user to the email
      event.user.pm('Please check your Regis email for further instructions. https://owa.regis.org/owa/')
      return
    else
      event.user.pm('Invalid username! Please use your Regis username.')
      return
    end
  end

  command(:verify, description: 'Verifies your identity with the emailed code.') do |event, code|
    server = event.bot.server(150739077757403137)
    # Make sure they passed a code!
    if code != nil
      # Change hex code back into characters
      username = code.scan(/../).map { |x| x.hex.chr }.join

      # Escape string since techinally anything can be in there
      escaped = $db.escape(username)

      # Find an unverified user with that username
      result = $db.query("SELECT * FROM students WHERE username='#{escaped}' AND verified=0")

      # If that guy exists
      if result.count > 0
        result = result.first

        # Set his discord_id and make him verified in the db
        $db.query("UPDATE students SET discord_id='#{event.user.id}', verified=1 WHERE username='#{escaped}'")

        # PM him a congratulatory message
        event.user.pm("Congratulations, **#{result['first_name']}**. You are now a verifed Regis Discord User!")

        # Make an announcement welcoming him to everyone
        event.bot.find_channel('announcements').first.send_message "@everyone Please welcome **#{result['first_name']} #{result['last_name']}** of **#{result['advisement']}** *(#{event.user.mention})* to the Discord Server!"

        # Add 'verified' role
        event.user.add_role(server, server.role(152_956_497_679_220_736))

        # Decide grade for role
        digit = result['advisement'][0].to_i
        rolename = 'freshmen'
        if digit == 2
          rolename = 'sophomores'
        elsif digit == 3
          rolename = 'juniors'
        elsif digit == 4
          rolename = 'seniors'
        end

        # Add grade role
        event.user.add_role(server, server.roles.find { |r| r.name == rolename })

        # Find advisement role or create it then add it to ther user
        adv = result['advisement'][0..1]
        advrole = server.roles.find { |r| r.name == adv }
        if advrole.nil?
          advrole = server.create_role
          advrole.name = adv
          advrole.hoist = true
        end

        event.user.add_role(server, advrole)

        bots_role_id = server.roles.find { |r| r.name == 'bots' }.id

        # Advisement channel handling
        adv_channel = event.bot.find_channel(adv.downcase).first
        token = event.bot.token
        role_id = advrole.id
        user_id = event.user.id

        allow_perms = Discordrb::Permissions.new(0, DummyRoleWriter.new)
        allow_perms.can_read_messages = true
        allow_perms.can_send_messages = true
        allow_perms.can_read_message_history = true
        allow_perms.can_mention_everyone = true
        deny_perms = allow_perms

        if adv_channel.nil?
          adv_channel = server.create_channel(adv)
          adv_channel.topic = "Private chat for Advisements #{adv}-1 and #{adv}-2."
          channel_id = adv_channel.id
          Discordrb::API.update_role_overrides(token, channel_id, server.id, 0, deny_perms.bits) # @everyone
          Discordrb::API.update_role_overrides(token, channel_id, role_id, allow_perms.bits, 0) # advisement role
          Discordrb::API.update_role_overrides(token, channel_id, bots_role_id, allow_perms.bits, 0) # bots
        end
      else
        event.user.pm('Incorrect code!')
      end
    end

    nil
  end
end
