require "pg"
require_relative "configs"

# apparently holding open pg connections is good? So we will just have 1 database connection.
class SQLMethods
    @connection = PG::Connection.open(Configs.getConfigValue("postgresConnString"))
    def self.insertStats(columns, values)
        
        @connection.exec_params("INSERT INTO monitorstats (#{columns}) VALUES (#{values});")
        #connection.close()
    end

    def self.getComputedStatAggregate(ntileValue, returnedColumn, computeColumn1, computeColumn2)
        results = Array.new
        statsCutoff = (Time.new - Configs.getConfigValue("statsRetentionPeriod")).strftime("%Y-%m-%d %H:%M:%S")
        sqlcmd = "with aggregatestats (#{computeColumn1}, #{computeColumn2}, ntile) as ( " +
                 "select #{computeColumn1}, #{computeColumn2}, NTILE(#{ntileValue}) OVER(ORDER BY statsdate ASC) from monitorstats " +
                 "WHERE statsdate > '#{statsCutoff}' " +
                 ")" +
                 "SELECT AVG(#{computeColumn1} - #{computeColumn2}) as #{returnedColumn} from aggregatestats GROUP BY ntile ORDER BY ntile ASC"

        #connection = PG::Connection.open(Configs.getConfigValue("postgresConnString"))
        pgresults = @connection.exec(sqlcmd)
        #connection.close()

        pgresults.each_row do |row|
            results << row[0].to_f
        end

        return results
    end


    def self.getStatAggregate(ntileValue, column)
        results = Array.new
        statsCutoff = (Time.new - Configs.getConfigValue("statsRetentionPeriod")).strftime("%Y-%m-%d %H:%M:%S")
        sqlcmd = "with aggregatestats (#{column}, ntile) as ( " +
                 "select #{column}, NTILE(#{ntileValue}) OVER(ORDER BY statsdate ASC) from monitorstats " +
                 "WHERE statsdate > '#{statsCutoff}' " +
                 ")" +
                 "SELECT AVG(#{column}) from aggregatestats GROUP BY ntile ORDER BY ntile ASC"

        #connection = PG::Connection.open(Configs.getConfigValue("postgresConnString"))
        pgresults = @connection.exec(sqlcmd)
        #connection.close()

        pgresults.each_row do |row|
            results << row[0].to_f
        end

        return results
    end

    def self.getMostRecentStatValue(column)
        #connection = PG::Connection.open(Configs.getConfigValue("postgresConnString"))
        pgresults = @connection.exec("SELECT #{column} FROM monitorstats ORDER BY statsdate DESC LIMIT 1")
        #connection.close()
        
        return pgresults.getvalue(0,0)
    end

end
