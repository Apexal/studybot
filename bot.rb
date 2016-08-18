require 'discordrb'
require 'mysql2'
require 'mail'
require 'yaml'
require 'date'

puts 'STARTING UP'

$CONFIG = YAML::load_file('./config.yaml')
puts 'Loaded Config'

# Auto requires all modules
Dir["#{File.dirname(__FILE__)}/modules/*.rb"].each { |file| require file }
puts 'Loaded modules'

Mail.defaults do
  delivery_method :smtp, address: 'smtp.gmail.com',
  port: 587,
  user_name: $CONFIG['auth']['gmail']['username'],
  password: $CONFIG['auth']['gmail']['passkey'],
  authentication: :plain,
  enable_starttls_auto: true
end
puts 'Loaded mail'

$db = Mysql2::Client.new(host: $CONFIG['auth']['mysql']['host'], username: $CONFIG['auth']['mysql']['username'], password: $CONFIG['auth']['mysql']['password'], database: $CONFIG['auth']['mysql']['database'])
puts 'Connected to DB'

bot = Discordrb::Commands::CommandBot.new(
  advanced_functionality: true,
  token: $CONFIG['auth']['discord']['token'],
  chain_args_delim: '}',
  application_id: $CONFIG['auth']['discord']['application_id'],
  prefix: $CONFIG['options']['bot']['prefix']
)

$token = bot.token
$unallowed = %w(Phys Guidance Speech Advisement Health Amer)

bot.bucket :abusable, limit: 3, time_span: 60, delay: 10
bot.bucket :study, limit: 10, time_span: 60, delay: 5

bot.set_role_permission(152956497679220736, 1)
bot.set_role_permission(200261631974834176, 2)
bot.set_user_permission(152189849284247553, 2)

bot.include! StartupEvents
bot.include! RegistrationEvents
bot.include! RegistrationCommands
bot.include! RoomCommands
bot.include! RoomEvents
bot.include! GameEvents
bot.include! VoiceChannelEvents
bot.include! UtilityEvents
bot.include! UtilityCommands
bot.include! WorkCommands
bot.include! QuoteCommands
bot.include! Suppressor
bot.include! CourseCommands
bot.include! SpecialRoomEvents
bot.include! SteamCommands
#bot.include! NicknameEvents

begin
  bot.run :async
  school_loop
  bot.sync
rescue Interrupt
  puts 'Shutting down...'
  bot.stop
end