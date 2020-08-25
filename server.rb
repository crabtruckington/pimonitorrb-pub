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
        elsif (part == ".")
        #again do nothing, this is the same directory            
        elsif (part == ".." || part == "...") 
            #we COULD pop off a directory but I dont see any good reason to support this
            #instead we will log this as a probably attempt to scan for vulns, since
            #100% of the instances I see doing this are just that
            
            #clean.pop   
            if loggedDangerousRequest == 0
                Log.log("User at #{ipAddr} made dangerous request: #{requestContent} , it was sanitized")
                loggedDangerousRequest = 1
            end
        else
            clean << part  
        end
    end

    File.join(WEB_ROOT, *clean)
end


t1 = Thread.new do
    loopCount = 0
    genStatsPageEveryX = 30
    #generate stats on startup, then do it every X stats loops
    
    GenerateStats.generateStats()
    Log.log("Stats generated", 0)
    HTMLGen.htmlGenThread()

    while true do
        GenerateStats.generateStats()
        Log.log("Stats generated", 0)
        loopCount += 1
        if (loopCount == genStatsPageEveryX)
            HTMLGen.htmlGenThread()
            Log.log("Garbage Collecting", 1)
            GC.start()
            loopCount = 0
        end
    end
end


# t2 = Thread.new do
#     while true do
#         HTMLGen.htmlGenThread()
#         Log.log("Garbage collecting", 0)
#         GC.start()        
#     end
# end


server = TCPServer.new('localhost', 6689)

loop do
    #socket = server.accept
    Thread.start(server.accept) do |socket|  
        requestContent = socket.gets    
        path = sanitizeUserRequests(requestContent, socket.peeraddr)
        ServeRequest.serveRequest(socket, path)
    end
end

