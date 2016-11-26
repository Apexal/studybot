
module Server
    require 'sinatra'

    def initialize(bot)
        
    end

    set :run, true
    set :bind, '0.0.0.0'

    get '/' do
        'Hello world!'
    end
end