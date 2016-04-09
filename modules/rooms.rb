class DummyRoleWriter
  def write(bits); end
end

module RoomCommands
  extend Discordrb::Commands::CommandContainer

  # List of special channels
  joinable = %w(gaming memes meta)

  command(:join, description: 'Join a special channel. `!join channelname`') do |event, channel_name|

    if event.channel.private?
      channel = event.server.channels.find { |c| c.name == channel_name }

      if !channel.nil? && joinable.include?(channel_name)
        token = event.bot.token
        user_id = event.user.id
        channel_id = channel.id

        Discordrb::API.update_user_overrides(token, channel_id, user_id, 0, 0)
        event.user.pm "You have joined ##{channel_name}!"
      else
        event.user.pm "You can only join/leave **#{joinable.join ', '}**. Try `!join memes`"
      end
    else
      event.user.pm "`!join` and `!leave` are only available in PM's. Try using them here!"
      event.message.delete
    end

    nil
  end

  command(:leave, description: 'Leave a special channel.') do |event, channel_name|
    if event.channel.private?
      channel = event.server.channels.find { |c| c.name == channel_name }

      if !channel.nil? && joinable.include?(channel_name)
        token = event.bot.token
        user_id = event.user.id
        channel_id = channel.id

        deny_perms = Discordrb::Permissions.new(0, DummyRoleWriter.new)
        deny_perms.can_read_messages = true
        deny_perms.can_send_messages = true
        deny_perms.can_read_message_history = true
        deny_perms.can_mention_everyone = true

        Discordrb::API.update_user_overrides(token, channel_id, user_id, 0, deny_perms.bits)
        event.user.pm "You have left ##{channel_name}!"
      else
        event.user.pm "You can only join/leave **#{joinable.join ', '}**. Try `!leave memes`"
      end
    else
      event.user.pm "`!join` and `!leave` are only available in PM's. Try using them here!"
      event.message.delete
    end

    nil
  end
end
