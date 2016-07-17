module StatusCommands
  extend Discordrb::Commands::CommandContainer
  
  statuses = ['Looking to Play']
  command(:setstatus, description: "Set your status")
    
  end
end