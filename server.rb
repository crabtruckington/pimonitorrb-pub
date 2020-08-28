require 'socket'
require 'uri'
require_relative "serveRequest"
require_relative "logging"
require_relative "statsgen"
require_relative "configs"
require_relative "sqlHelpers"

# base directory
WEBROOT = Configs.getConfigValue("webRoot")

def sanitizeUserRequests(requestContent, ipAddr)
    if requestContent.empty?
        raise "Server Received Empty Request"
    else
        requestURI  = requestContent.split(" ")[1]
    end
    path = URI.unescape(URI(requestURI).path)  
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

    File.join(WEBROOT, *clean)
end
    
#generate stats on startup
GenerateStats.generateStats()
Log.log("Stats generated", 0)


t1 = Thread.new do
    while true do
        begin            
            GenerateStats.generateStats()
            Log.log("Stats generated", 0) 
        rescue => e
            Log.log("Error generating stats: " + e.to_s, 3)            
        end
    end
end

#we want to run this in its own thread so we can see how intensive it is in the stats
t2 = Thread.new do
    while true do
        begin
            HTMLGen.htmlGenThread()
            Log.log("HTML generated, sleeping...", 0)
            sleep(Configs.getConfigValue("htmlGenSleep"))
        rescue => e
            Log.log("Error generating html: " + e.to_s, 3)
            retry            
        end
        GC.start()        
    end
end

t3 = Thread.new do
    while true do
        begin
            SQLMethods.cleanUpOldStats(Configs.getConfigValue("statsRetentionPeriod"))
            Log.log("Cleaned up old stats", 1)
            sleep(Configs.getConfigValue("statsRetentionSchedule"))
        rescue => e
            Log.log("Error cleaning up old stats!!!: " + e.to_s, 4)
        end
    end
end

server = TCPServer.new(Configs.getConfigValue("serverHost"), Configs.getConfigValue("serverPort"))

loop do
    #socket = server.accept
    Thread.start(server.accept) do |socket|  
        begin
            requestContent = socket.gets        
            path = sanitizeUserRequests(requestContent, socket.peeraddr)
            ServeRequest.serveRequest(socket, path)    
        rescue Exception => e
            Log.log("Exception serving request, " + e.to_s, 4)
        end
    end
end
