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
	user = event.user.on(server)
	puts "Attempting to verify #{user} (#{event.user.name})"
    
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
        $db.query("UPDATE students SET discord_id='#{user.id}', verified=1 WHERE username='#{escaped}'")

        # PM him a congratulatory message
        user.pm("Congratulations, **#{result['first_name']}**. You are now a verifed Regis Discord User!")
		
        # Make an announcement welcoming him to everyone
        event.bot.find_channel('announcements').first.send_message "@everyone Please welcome **#{result['first_name']} #{result['last_name']}** of **#{result['advisement']}** *(#{event.user.mention})* to the Discord Server!"
		
        # Add 'verified' role
		puts "Adding 'verified' role"
		vrole = server.roles.find{|r| r.name == "verified"}
		user.add_role(vrole)
		
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
		puts "Adding '#{rolename}' role"
		
        # Add grade role
		grole = server.roles.find { |r| r.name == rolename }
        user.add_role(grole)
		
        bots_role_id = server.roles.find { |r| r.name == 'bots' }.id

        # Advisement channel handling
		
		token = event.bot.token
		
		perms = Discordrb::Permissions.new
        perms.can_read_messages = true
        perms.can_send_messages = true
        perms.can_read_message_history = true
        perms.can_mention_everyone = true
		
		large_adv = result['advisement'][0..1]
		small_adv = result['advisement']
		
		# Add the roles for each adv and create channels for each
		[large_adv, small_adv].each do |a|
			advrole = server.roles.find { |r| r.name == a }
			if advrole.nil?
				puts "Creating role"
				advrole = server.create_role
				advrole.name = a
				advrole.hoist = true if a.length <= 2 # This should only hoist large advisement roles
			end
			
			if user.roles.include?(advrole) == false
				puts "Adding role"
				user.add_role(advrole)
			end
			
			puts "Finding channel"
			adv_channel = event.bot.find_channel(a.downcase).first
			if adv_channel.nil?
				puts "Creating channel"
				adv_channel = server.create_channel(a)
				adv_channel.topic = "Private chat for Advisement #{a}"
				channel_id = adv_channel.id
				
				puts "Updating perms"
				Discordrb::API.update_role_overrides(token, adv_channel.id, server.id, 0, perms.bits) # @everyone
				Discordrb::API.update_role_overrides(token, adv_channel.id, advrole.id, perms.bits, 0) # advisement role
				Discordrb::API.update_role_overrides(token, adv_channel.id, bots_role_id, perms.bits, 0) # bots
			end
		end
      else
        user.pm('Incorrect code!')
      end
    end

    nil
  end
end
