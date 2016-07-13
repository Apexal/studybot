module NicknameEvents
  extend Discordrb::EventContainer
  member_update do |event|
    results = $db.query("SELECT username FROM students WHERE discord_id='#{event.user.id}'")
    return if results.count == 0

    username = results.first['username']
    max = 32
    allowed_length = max - (username.length + 2)
    name = event.user.display_name.split(' [')[0][0..allowed_length - 2]
    puts name.length + (username.length + 3)
    if !event.user.display_name.include? " [#{username}]" and !name.include? " [#{username}]"
      event.user.nick = "#{name} [#{username}]"
    end
  end
end
