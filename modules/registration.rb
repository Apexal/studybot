module RegistrationEvents
  extend Discordrb::EventContainer

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
    "In Progress"
  end

  command(:verify, description: "Prove your identity. Usage: `!verify code`") do |event, code|
    # Make sure they passed a code!
    if code != nil
      # Change hex code back into characters
      username = code.scan(/../).map { |x| x.hex.chr }.join


    end
  end
end
