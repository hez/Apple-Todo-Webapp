require 'rubygems'
require 'sinatra/base'
require 'erb'
require 'lib/apple_todos'

class TodosServer < Sinatra::Base
  configure do
    @@todos_server = AppleMailTodo::Server.new(
        :server => 'mail.example.com',
        :port => 993,
        :username => 'username',
        :password => 'secret'
    )
  end

  get '/' do
    @todos = @@todos_server.todos
    erb :index
  end

  get '/incomplete' do
    @todos = @@todos_server.todos.incomplete
    erb :index
  end
end
