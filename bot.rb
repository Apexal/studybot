require 'discordrb'
require 'mysql2'
require 'mail'
require 'yaml'
require 'date'

require 'pry'

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
  application_id: $CONFIG['auth']['discord']['application_id'],
  prefix: $CONFIG['options']['bot']['prefix']
)

$token = bot.token
$unallowed = %w(Phys Guidance Speech Advisement Health Amer)

bot.bucket :abusable, limit: 3, time_span: 60, delay: 10
bot.bucket :study, limit: 10, time_span: 60, delay: 5

def delete_channel(server, channel, count=1)
  return if channel.nil?
  
  puts "Deleting voice-channel #{channel.name} and associated #voice-channel"
  begin
    channel.delete
  rescue
    puts 'Failed to delete voice-channel'
  end
  begin
    server.text_channels.find{|t| t.id == $hierarchy[channel.id]}.delete
    $hierarchy.delete channel.id
  rescue => e
    puts 'Failed to find/delete associated #voice-channel'
    puts e
    if count < 2
      sleep 1.1
      delete_channel(server, channel, count + 1)
    end
  end
end

$groups = nil
def handle_group_voice_channels(server)
  if $groups.nil?
    $groups = $db.query('SELECT * FROM groups WHERE creator != "server"')
  end
  
  $groups.each do |row|
    group_role = server.roles.find{|r| r.id==Integer(row['role_id'])}
    unless group_role.nil?
      # Get count of online group members
      total_count = server.members.find_all { |m| m.role? group_role }.length
      count = server.online_members.find_all { |m| m.role? group_role }.length
      channel = server.voice_channels.find { |c| c.name == "Group #{row['name']}" }
      perms = Discordrb::Permissions.new
      perms.can_connect = true
      
      minimum = (total_count * 0.25).floor > 5 ? (total_count * 0.25).floor > minimum : 5 
      
      if count > minimum
        #puts "Over #{minimum} online members in #{row['name']}"
        if channel.nil? and server.voice_channels.find { |c| c.name == row['name'] }.nil?
          channel = server.create_channel("Group #{row['name']}", 'voice')
          channel.define_overwrite(group_role, perms, 0)
          Discordrb::API.update_role_overrides($token, channel.id, server.id, 0, perms.bits)
        end
      else
        delete_channel(server, channel) unless channel.nil?
        # puts 'Less than 5 online members in #{row['name']}'
      end
    end
  end
end

def replace_mentions(message)
  message.strip!
  message.gsub! '**', ''
  message.gsub! '@everyone', '**everyone**'
  message.gsub! '@here', '**here**'
  words = message.split ' '
  done = []
  words.each_with_index do |w, i|
    w.sub!('(', '')
    w.sub!(')', '')
    w.sub!('"', '')
    if w.start_with? '<@' and w.end_with? '>'
      id = w.sub('<@!', '').sub('<@', '').sub('>', '') # Get ID 
      if !done.include? id and /\A\d+\z/.match(id)
        user = $db.query("SELECT username FROM students WHERE discord_id=#{id}")
        if user.count > 0
          user = user.first
          rep = "**@#{user["username"]}**" # replacement
          message.gsub! "<@#{id}>", rep # Only works when they don't have a nickname
          message.gsub! "<@!#{id}>", rep
        end
        done << id
      end
    end
  end

  return message.sub('@', '') if words.length == 1 and done == 1

  return message
end

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
#bot.include! NicknameEvents

bot.run #:async

#bot.profile.avatar = File.open('./resources/Regis_crest.jpeg', 'rb')

#bot.sync
