require 'socket'
require 'uri'
require_relative "serveRequest"
require_relative "logging"
require_relative "statsgen"

# base directory
WEB_ROOT = './content'

def sanitizeUserRequests(requestContent, ipAddr)
    request_uri  = requestContent.split(" ")[1]
    path = URI.unescape(URI(request_uri).path)  
    clean = []
  
    parts = path.split("/")
  
    loggedDangerousRequest = 0
    parts.each do |part|
      if part.empty? 
        #do nothing
      elsif part == "." || part == ".." || part == "..."
        
      #elsif part == ".."
        #clean.pop   #im pretty sure I dont want to support this shit
        if loggedDangerousRequest == 0
          Log.log("User at #{ipAddr} made dangerous request: #{requestContent} , it was sanitized")
          loggedDangerousRequest = 1
        end
      else
        clean << part  
      end

      #next if part.empty? || part == '.'
      #part == '..' ? clean.pop : clean << part
    end

    File.join(WEB_ROOT, *clean)
end

t1 = Thread.new do
  StatsGen.statsGenThread()
end

server = TCPServer.new('localhost', 6689)

loop do
  #socket = server.accept
  Thread.start(server.accept) do |socket|  
    requestContent = socket.gets    
    path = sanitizeUserRequests(requestContent, socket.peeraddr)
    ServeRequest.serveRequest(socket, path)
  end
end

