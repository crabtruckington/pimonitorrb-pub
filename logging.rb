require 'logger'


class Log
    @isInit = 0
    @logLocation = "./pimonitorrb.log"
    @logginglevel = 0 # 0 = DEBUG, 1 = INFO, 2 = WARN, 3 = ERROR, 4 = FATAL, 5 = UNKNOWN
    @logger
    @loggerTerm    

    def self.init()
        @logger = Logger.new(@logLocation, 10, 10485760) #weekly, 10 megs rotation
        @logger.formatter = proc {|severity, datetime, progname, msg| 
                                "[#{datetime}]: [#{severity}] #{msg}\r\n"}
        @logger.level = @logginglevel
        @loggerTerm = Logger.new(STDOUT)
        @loggerTerm.formatter = proc {|severity, datetime, progname, msg| 
                                "[#{datetime}]: [#{severity}] #{msg}\r\n"}
        @loggerTerm.level = @logginglevel
        @isInit = 1
    end

    def self.log(message, logLevel)
        if @isInit == 0
            self.init()
            self.log(message, logLevel)
        else
            case logLevel
            when 0
                @logger.debug("#{message.dump}")
                @loggerTerm.debug("#{message.dump}")
            when 1
                @logger.info("#{message.dump}")
                @loggerTerm.info("#{message.dump}")
            when 2
                @logger.warn("#{message.dump}")
                @loggerTerm.warn("#{message.dump}")
            when 3
                @logger.error("#{message.dump}")
                @loggerTerm.error("#{message.dump}")
            when 4
                @logger.fatal("#{message.dump}")
                @loggerTerm.fatal("#{message.dump}")
            else
                @logger.unknown("#{message.dump}")
                @loggerTerm.unknown("#{message.dump}")
            end
        end
    end
end

