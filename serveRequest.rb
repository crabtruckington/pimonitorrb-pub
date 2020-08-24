require 'socket'
require 'uri'
require_relative "logging"

class ServeRequest
    # Map extensions to their content type
    CONTENT_TYPE_MAPPING = 
    {
        "html"  => "text/html",
        "htm"   => "text/html",
        "txt"   => "text/plain",
        "png"   => "image/png",
        "jpg"   => "image/jpeg",
        "jpeg"  => "image/jpeg",
        "svg"   => "image/svg+xml",
        "ico"   => "image/x-icon"
    }

    # Treat as binary data if content type cannot be found
    DEFAULT_CONTENT_TYPE = 'application/octet-stream'

    def self.contentType(path)
        ext = File.extname(path).split(".").last
        CONTENT_TYPE_MAPPING.fetch(ext, DEFAULT_CONTENT_TYPE)
    end


    def self.serveRequest(socket, path)
        begin
            remote_ip = socket.peeraddr

            if path.include? "monitorstatgen"
                Log.log("Client tried to access monitorstatsgen from #{remote_ip}", 3)
                respondWith404(socket, path)
        
            #serve explicit file request
            elsif File.exist?(path) && !File.directory?(path)
                File.open(path, "rb") do |file|
                    socket.print "HTTP/1.1 200 OK\r\n" +
                                "Content-Type: #{contentType(file)}\r\n" +
                                "Content-Length: #{file.size}\r\n" +
                                "Connection: close\r\n"
                    socket.print "\r\n"
        
                    IO.copy_stream(file, socket)
                    Log.log("200 OK #{path} , #{remote_ip}", 1)            
                end
        
            #serve implicit index request if possible, or 404
            elsif File.directory?(path)
                potentialIndex = File.join(path, "index.html")
                if File.exists?(potentialIndex)
                    File.open(potentialIndex, "rb") do |file|
                        socket.print "HTTP/1.1 200 OK\r\n" +
                                    "Content-Type: #{contentType(file)}\r\n" +
                                    "Content-Length: #{file.size}\r\n" +
                                    "Connection: close\r\n"
                        socket.print "\r\n"
            
                        IO.copy_stream(file, socket)
                        Log.log("200 OK , redirected #{path} to #{potentialIndex} , #{remote_ip}", 1)
                    end
                else
                    respondWith404(socket, path)
                end
        
            #no content available to serv
            else
                respondWith404(socket, path)
            end
        
            socket.close
        rescue Exception => e
            Log.log("Exception serving request for #{path} , #{socket.peeraddr}\r\n#{e}")
        end
    end


    def self.respondWith404(socket, path)
        remote_ip = socket.peeraddr
        message = "404 File not found\r\n"
      
        socket.print "HTTP/1.1 404 Not Found\r\n" +
                     "Content-Type: text/plain\r\n" +
                     "Content-Length: #{message.size}\r\n" +
                     "Connection: close\r\n"
        socket.print "\r\n"      
        socket.print message

        Log.log("404 NOT FOUND #{path} , #{remote_ip}", 1)
    end
end
