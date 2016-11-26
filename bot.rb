require 'discordrb'
require 'mysql2'
require 'mail'
require 'yaml'
require 'date'
require 'sinatra'

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
$unallowed = ['Phys Ed', 'Guidance', 'Speech', 'Advisement', 'Health', 'Amer']

bot.bucket :abusable, limit: 3, time_span: 60, delay: 10
bot.bucket :study, limit: 10, time_span: 60, delay: 5
bot.bucket :reporting, limit: 1, time_span: 120, delay: 60

bot.set_role_permission(152956497679220736, 1)
bot.set_role_permission(200261631974834176, 2)
bot.set_user_permission(152621041976344577, 3)
bot.set_user_permission(152189849284247553, 3)

bot.include! StartupEvents
bot.include! RegistrationEvents
bot.include! RegistrationCommands
bot.include! GroupCommands
bot.include! GroupEvents
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
bot.include! ModeratorCommands
#bot.include! NicknameEvents

begin
  bot.run :async
rescue Interrupt
  save_hierarchy
  puts 'Shutting down...'
  bot.stop
end

server = bot.server(150_739_077_757_403_137)

# SINATRA
set :bind, '0.0.0.0'
enable :sessions

get '*' do
  session['info'] ||= []
  session['logged_in'] ||= false

  @user = server.members.find { |m| m.id == session['user_id'] } if session['logged_in']
  @username = session['username']
  @logged_in = session['logged_in']
  @studymode = @user.display_name.start_with? "[S]" if @logged_in
  @info = session['info']
  session['info'] = []
  pass
end

get '/login' do
  secret_code = params['code']
  if secret_code.nil? or secret_code.empty?
    session['info'] << 'Failed to login!'
    redirect back
  end

  session['user_id'] = nil
  $db.query("SELECT username, discord_id FROM discord_codes WHERE code='#{secret_code}'").each do |row|
    session['user_id'] = Integer(row['discord_id'])
    session['username'] = row['username']
  end
  
  if session['user_id'].nil?
    session['info'] << 'Failed to login!'
    redirect back
  end

  session['info'] << "You have logged in!"
  session['logged_in'] = true

  redirect to('/')
end

get '/logout' do
  session['logged_in'] = false
  session['user_id'] = nil
  session['username'] = nil
  session['info'] << 'You have logged out.'
  redirect back
end

get '/' do
  puts session['info']
  @channels = server.text_channels.sort { |a,b| a.name <=> b.name }
  @students = $db.query('SELECT id, username, first_name, last_name, advisement, mpicture, discord_id FROM students WHERE verified=1 ORDER BY advisement, last_online ASC')
  @students.each { |s| s['discord_user'] = server.members.find { |m| m.id == Integer(s['discord_id']) }}

  erb :index, layout: :layout
end

get '/studymode' do
  redirect(to('/')) unless session['logged_in']
  
  user = server.members.find { |m| m.id == session['user_id'] }
  toggle_studymode(server, user)
  
  redirect back
end

get '/groups' do
  redirect(to('/')) unless session['logged_in']
  
  @title = 'Groups'

  @owns_group = false

  @groups = $db.query('SELECT * FROM groups').to_a
  @groups.each do |g|
    # Assign member list
    role = server.roles.find { |r| r.id == Integer(g['role_id']) }
    g['member_ids'] = server.members.find_all { |m| m.roles.include? role }.map { |m| m.id }
    @owns_group = true if g['creator'] == session['username']
  end

  erb :groups, layout: :layout
end

get '/groups/:id' do
  redirect(to('/')) unless session['logged_in']
  
  group_id = Integer(params['id'])
  @group = $db.query("SELECT * FROM groups WHERE id='#{group_id}'").first
  if @group.nil?
    session['info'] << 'Failed to find group!'
    redirect back
    return
  end
  
  @title = "Group #{@group['name']}"
  
  role = server.roles.find { |r| r.id == Integer(@group['role_id']) }
  @group['members'] = []
  server.members.find_all { |m| m.roles.include? role }.each do |m|
    info = $db.query("SELECT * FROM students WHERE discord_id='#{m.id}'").first
    @group['members'] << { info: info, discord: m } unless info.nil?
  end
  
  erb :group, layout: :layout
end

post '/groups/:id/join' do
  redirect(to('/')) unless session['logged_in']
  
  group_id = params['id']
  user = server.members.find { |m| m.id == session['user_id'] }
  group = add_user_to_group(server, user, group_id)

  session['info'] << "Joined group '#{group['name']}'!"
  redirect back
end

post '/groups/:id/leave' do
  redirect(to('/')) unless session['logged_in']
  
  group_id = params['id']
  user = server.members.find { |m| m.id == session['user_id'] }
  group = remove_user_from_group(server, user, group_id)

  session['info'] << "Left group '#{group['name']}'!"
  redirect back
end

post '/groups/create' do
  redirect(to('/')) unless session['logged_in']
  
  # Check for missing data
  if params['name'].nil? or params['name'].empty? or params['description'].empty? or params['description'].nil?
    session['info'] << 'Missing data to create group!'
    redirect back
    return
  end

  name = params['name']
  description = params['description']
  is_private = params['public'].nil?
  user = server.members.find { |m| m.id == session['user_id'] }

  group = create_group(server, user, name, description, is_private)
  session['info'] << "Created group #{group['name']}!"

  redirect back
end