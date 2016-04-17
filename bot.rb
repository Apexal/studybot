require 'discordrb'
require 'mysql2'
require 'mail'
require 'yaml'
require 'nokogiri'
require 'date'

require 'pry'

$events = Nokogiri::HTML(open("calendar.html")).xpath("//div[@id='main']//a[contains(text(), ';')]").map do |e|
	parts = e.text.gsub(";", "").gsub(",", "").split(" ")
	day = e.xpath('./../../../../../../..//tr[@class="hb"]//strong').text.gsub(/[^0-9]/, '')
	
	now = Time.now
	date = DateTime.new(now.year, now.month, Integer(day))
	
	{:date => date, :adv => parts[0], :course => parts[1...-1].join(" "), :teacher => parts[-1]}
end

$CONFIG = YAML::load_file('./config.yaml')

require './modules/registration.rb'
require './modules/rooms.rb'
require './modules/games.rb'
require './modules/quotes.rb'
require './modules/voicechannels.rb'
require './modules/utils.rb'

Mail.defaults do
  delivery_method :smtp, address: 'smtp.gmail.com',
                         port: 587,
                         user_name: $CONFIG["auth"]["gmail"]["username"],
                         password: $CONFIG["auth"]["gmail"]["passkey"],
                         authentication: :plain,
                         enable_starttls_auto: true
end

$db = Mysql2::Client.new(host: $CONFIG["auth"]["mysql"]["host"], username: $CONFIG["auth"]["mysql"]["username"], password: $CONFIG["auth"]["mysql"]["password"], database: $CONFIG["auth"]["mysql"]["database"])

bot = Discordrb::Commands::CommandBot.new advanced_functionality: true, token: $CONFIG["auth"]["discord"]["token"], application_id: $CONFIG["auth"]["discord"]["application_id"], prefix: $CONFIG["options"]["bot"]["prefix"]

bot.ready do |event|
  puts "Ready!"
	server = bot.server(150739077757403137)

	perms = Discordrb::Permissions.new
	perms.can_read_message_history = true
	perms.can_read_messages = true
	perms.can_send_messages = true

	djrole = server.roles.find{|r| r.name == "dj"}
	server.text_channels.each do |c|
		if c.name == "voice-channel" || c.name == "music"
			puts "Deleting ##{c.name}"
			c.delete
		else
			Discordrb::API.update_role_overrides(bot.token, c.id, djrole.id, 0, perms.bits)
		end
	end

	server.voice_channels.find_all{|r| r.name.include? "Room"}.each do |c|
		c_name = "voice-channel"
		c_name = c.name unless c.name != "Music"
		
		text_channel = server.create_channel c_name
		text_channel.topic = "Private chat for all those in your voice channel."
		
		# Give the current user and BOTS access to it, restrict @everyone
		c.users.each do |u|
			puts u.name
			Discordrb::API.update_user_overrides(bot.token, text_channel.id, u.id, perms.bits, 0)
		end
		Discordrb::API.update_role_overrides(bot.token, text_channel.id, server.roles.find{|r| r.name == "bots"}.id, perms.bits, 0)
		Discordrb::API.update_role_overrides(bot.token, text_channel.id, server.id, 0, perms.bits)

		# Link the id's of both channels together
		$hierarchy[c.id] = text_channel.id
	end

	server.users.each do |u|
		if !!u.game
			$playing[u.id] = u.game
			puts "#{u.name} is playing #{u.game}"
			game_channel = server.voice_channels.find {|c| c.name == $playing[u.id]}
			if game_channel.nil? && $playing.values.count(u.game) >= 2
			  puts "Creating Room for #{u.game}"
			  server.create_channel($playing[u.id], 'voice')
			end
		end
	end
end

bot.bucket :abusable, limit: 3, time_span: 60, delay: 10
bot.include! RegistrationEvents
bot.include! RegistrationCommands
bot.include! RoomCommands
bot.include! GameEvents
bot.include! VoiceChannelEvents
bot.include! UtilityEvents
bot.include! UtilityCommands
bot.include! QuoteCommands
bot.include! Suppressor

bot.run

