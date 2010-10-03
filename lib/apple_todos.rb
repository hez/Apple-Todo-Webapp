require 'rubygems'
require 'net/imap'
require 'mail'

module AppleMailTodo
  class Server
    # :server, :port, :username, :password
    DEFAULTS = { :folder_name => 'Apple Mail To Do', :port => 993 }

    def initialize( config )
      @config = DEFAULTS.merge( config )
    end

    def todos
      @todos ||= fetch_todos
      @todos
    end

    def close
      server.disconnect
    end

  private

    def fetch_todos
      puts "fetching"
      todos = TodosCollection.new
      server.examine( @config[:folder_name] )
      todo = nil
      server.search(["NOT", "DELETED"]).each do | message_id |
        messages = server.fetch( message_id, "RFC822" )
        messages.each do | m |
          mail = Mail::Message.new(m.attr["RFC822"]) 
          todos << parse_todo( mail )
        end
      end
      todos
    end

    def server
      @server ||= connect_server
      @server
    end

    def connect_server
      imap = Net::IMAP.new( @config[:server], @config[:port], true )
      imap.login(@config[:username], @config[:password])
      imap
    end

    def parse_todo( mail_message )
      temp = mail_message.body.parts[0].body.to_s
#puts temp.inspect
      subject = temp.sub( /.*\222(.*)\222.*/m, '\1' )
      calendar = temp.sub( /.*\r\nIs stored in the (.*) calendar\.\r\n.*/m, '\1' )
      complete = !temp.include?( "\r\nIs incomplete.\r\n" )
      completed_on = nil
      completed_on = temp.sub( /.*\r\nWas completed on ([^.]*)\.\r\n.*/m, '\1' ) if complete
      has_due_date = !temp.include?( "\r\nHas no due date.\r\n" )
      due_on = nil
      due_on = temp.sub( /.*\r\nIs due on ([^.]*)\.\r\n.*/m, '\1' ) if has_due_date
      priority = !temp.include?( 'Has no priority' )
      priority = ( priority ? temp.sub( /.*\r\nHas (.*) priority\.\r\n.*/m, '\1' ).to_sym : :no_priority )
      has_note = !temp.include?( "\r\nHas no note." )
      note = nil
      note = temp.sub( /.*\r\nContains the note \223(.*)\224.*/m, '\1' ) if has_note
      Todo.new( subject, complete, completed_on, calendar, priority, due_on, note )
    end
  end

  class TodosCollection < Array
    %w{no_priority low medium high}.each do | p |
      class_eval( "def #{p}; TodosCollection.new(select { | x | x.priority == :#{p} }); end" )
    end
    def complete; TodosCollection.new(select { | x | x.complete }); end
    def incomplete; TodosCollection.new(select { | x | !x.complete }); end
  end

  Todo = Struct.new( :subject, :complete, :completed_on, :calendar, :priority, :due_date, :note )
end
