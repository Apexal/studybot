require 'discordrb'
require 'mysql2'
require 'mail'
require 'yaml'
require 'nokogiri'
require 'date'

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
  event.bot.game = "With Your Mind"
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
