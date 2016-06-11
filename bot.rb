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

# Auto requires all modules
Dir["#{File.dirname(__FILE__)}/modules/*.rb"].each { |file| require file }

Mail.defaults do
  delivery_method :smtp, address: 'smtp.gmail.com',
                         port: 587,
                         user_name: $CONFIG["auth"]["gmail"]["username"],
                         password: $CONFIG["auth"]["gmail"]["passkey"],
                         authentication: :plain,
                         enable_starttls_auto: true
end

$db = Mysql2::Client.new(host: $CONFIG["auth"]["mysql"]["host"], username: $CONFIG["auth"]["mysql"]["username"], password: $CONFIG["auth"]["mysql"]["password"], database: $CONFIG["auth"]["mysql"]["database"])

bot = Discordrb::Commands::CommandBot.new(advanced_functionality: true, 
										  token: $CONFIG["auth"]["discord"]["token"], 
										  application_id: $CONFIG["auth"]["discord"]["application_id"], 
										  prefix: $CONFIG["options"]["bot"]["prefix"])

$token = bot.token

bot.bucket :abusable, limit: 3, time_span: 60, delay: 10
bot.bucket :study, limit: 10, time_span: 60, delay: 5

def handle_group_voice_channels(server)
	$db.query("SELECT * FROM groups WHERE creator != 'server'").each do |row|
		group_role = server.roles.find{|r| r.id==Integer(row['role_id'])}
		if !group_role.nil?
			# Get count of online group members
			count = server.online_members.find_all{|m| m.role? group_role}.length
			channel = server.voice_channels.find{|c| c.name == "Group #{row['name']}"}
			
			perms = Discordrb::Permissions.new
			perms.can_connect = true
			
			if count > 5
				puts "Over 5 online members in #{row['name']}"
				if channel.nil? and server.voice_channels.find{|c| c.name==row['name']}.nil?
					channel = server.create_channel("Group #{row['name']}", type='voice')
					Discordrb::API.update_role_overrides($token, channel.id, server.id, 0, perms.bits)
					channel.define_overwrite(group_role, perms, 0)
				end
			else
				if !channel.nil?
					channel.delete
				end
				puts "Less than 5 online members in #{row['name']}"
			end
		end
	end
end

def replace_mentions(message)
	message.strip!
	message.gsub! "**", ""
	
	message.gsub! "@everyone", "**everyone**"
	message.gsub! "@here", "**here**"
	
	words = message.split " "
	
	done = []
	words.each_with_index do |w, i|
		w.sub!("(", "")
		w.sub!(")", "")
		w.sub!("'", "")
		
		if w.start_with? "<@" and w.end_with? ">"
			id = w.sub("<@!", "").sub("<@", "").sub(">", "") # Get ID 
			
			if !done.include? id and /\A\d+\z/.match(id)
				user = $db.query("SELECT username FROM students WHERE discord_id=#{id}")
				
				if user.count > 0
					user = user.first
					rep = "**@#{user['username']}**" # replacement
					
					message.gsub! "<@#{id}>", rep # Only works when they don't have a nickname
					message.gsub! "<@!#{id}>", rep
				end
				
				done << id
			end
		end
	end
	
	if words.length == 1 and done == 1
		return message.sub("@", "")
	end
	
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
bot.include! QuoteCommands
bot.include! Suppressor
bot.include! CourseCommands
#bot.include! NicknameEvents

bot.run :async

bot.profile.avatar = File.open('./Regis_crest.jpeg', 'rb')

bot.sync
