require "minichart"
require "victor"
require "shellwords"
require_relative "logging"

class GenerateStats
    def self.generateStats()
        statsGenInterval = 1
        time = Time.new
        statsTime = time.strftime("%Y%m%d%H%M%S%L")
        statsDir = "./monitorstatgen/stats/"
        
        #you want to do this check every time, because its entirely possible
        #that a user has come by and deleted the directory
        Dir.mkdir(statsDir) unless Dir.exist?(statsDir)
        
        #system("./monitorstatgen/statgen.sh > #{statsDir}#{statsTime}.txt")
        cmd = "./monitorstatgen/statgen.sh > #{statsDir}#{statsTime}.txt"
        bash(cmd)

        profilerTime = Time.new
        if (Dir[File.join(statsDir + "/**/*")].length <= 1)
            profilerTime = (Time.new - profilerTime)
            bp1 = "test"
            # we need at least 2 stats file to generate a graph
            sleep(1)
            time = Time.new
            statsTime = time.strftime("%Y%m%d%H%M%S%L")
            #system("./monitorstatgen/statgen.sh > #{statsDir}#{statsTime}.txt")
            bash(cmd)
        end
        sleep(statsGenInterval)
    end

    def self.bash(command)
        escapedCommand = Shellwords.escape(command)
        system "bash -c #{escapedCommand}"
    end
end

class HTMLGen
    include Minichart
    include Victor
    # @htmlGenInterval = 60 #in seconds
    @statCutoff = (60 * 60 * 48) #(60 * 60 * 1) #in seconds
    @statsDir = "./monitorstatgen/stats/"


    def self.htmlGenThread()
        time = Time.new
        statsTime = time.strftime("%Y%m%d%H%M%S%L")
        fileArray = Array.new
        parsedStatArray = Array.new
        
        Log.log("Rotating stats and sorting stat list...", 0)
        fileArray = rotateStatsAndGenerateStatArray()
        Log.log("Stats rotated, generating new stats", 0)
        parsedStatArray = parseStatFiles(fileArray)
        Log.log("Generating HTML content and images", 0)
        generateStatHTML(parsedStatArray)
        # Log.log("HTML generation sleeping for #{@htmlGenInterval}", 0)
        # #sleep before exiting
        # sleep(@htmlGenInterval)
    end

    def self.generatePlotPoints(chartHeight, chartWidth, value, maxValue, currentPoint, totalPoints)
        plotPointXSteps = (chartWidth.to_f / totalPoints.to_f)
        plotPointVerticalSteps = (chartHeight.to_f / maxValue.to_f)

        begin

        plotPoint = (currentPoint * plotPointXSteps).to_i.to_s + "," + (chartHeight - (value * plotPointVerticalSteps)).to_i.to_s

        rescue Exception => e
            puts e
        end

        return plotPoint
    end

    def self.generateSVGChart(valueArray, chartWidth, chartHeight, maxValue, chartBackgroundColor, chartForegroundColor)
        svgStyle = 
        {
            stroke: chartForegroundColor,
            stroke_width: 2,
            fill: chartBackgroundColor
        }
        markerStyle =
        {
            stroke: "#ffffff",
            stroke_width: 1
        }
        chart = SVG.new(width: chartWidth, height: chartHeight)
        chartPlotPoints = ""
        totalPoints = valueArray.length() - 1
        currentPoint = 0
        rightMarkersX = chartWidth - 15
        rightMarkersYInterval = chartHeight / 4
        bottomMarkersXInterval = chartWidth / 30
        bottomMarkersY = chartHeight - 5

        begin
            valueArray.each do |value|
                chartPlotPoints += generatePlotPoints(chartHeight, chartWidth, value, maxValue, currentPoint, totalPoints) + " "
                currentPoint += 1
            end

        rescue Exception => e
            puts e
        end
        chart.build do
            rect(x:0, y: 0, width: chartWidth, height: chartHeight, fill: chartBackgroundColor)
            polyline(points: chartPlotPoints , style: svgStyle)
            line(x1: rightMarkersX, y1: rightMarkersYInterval * 0, x2: chartWidth, y2: rightMarkersYInterval * 0, style: markerStyle )
            line(x1: rightMarkersX, y1: rightMarkersYInterval * 1, x2: chartWidth, y2: rightMarkersYInterval * 1, style: markerStyle )
            line(x1: rightMarkersX, y1: rightMarkersYInterval * 2, x2: chartWidth, y2: rightMarkersYInterval * 2, style: markerStyle )
            line(x1: rightMarkersX, y1: rightMarkersYInterval * 3, x2: chartWidth, y2: rightMarkersYInterval * 3, style: markerStyle )
            #line(x1: rightMarkersX, y1: rightMarkersYInterval * 4, x2: chartWidth, y2: rightMarkersYInterval * 4, style: markerStyle )
            for i in 0..30
                if (i % 5 == 0)
                    bottomMarkersY = chartHeight - 7
                else
                    bottomMarkersY = chartHeight - 3
                end
                line(x1: i * bottomMarkersXInterval, y1: bottomMarkersY, x2: i * bottomMarkersXInterval, y2: chartHeight, style: markerStyle)
            end
        end

        return chart
    end


    def self.generateStatHTML(parsedStatArray)
        chartHeight = 175
        chartWidth = 525
        chartBackgroundColor = "#1f3445"
        chartForegroundColor = "#3899e8"
        chartsSaveFolder = "./content/monitor/images"

        cpuUsed = Array.new
        cpuClockSpeed = Array.new
        cpuTemp = Array.new
        memUsed = Array.new #memUsed is a combination of memTotal - memAvailable
        driveUsedMB = Array.new
        driveAvailableMB = Array.new
        driveKBReads = Array.new
        driveKBWrites = Array.new
        networkKBIn = Array.new
        networkKBOut = Array.new
        
        cpuUsedAggregate = 0.0
        cpuClockSpeedAggregate = 0.0
        cpuTempAggregate = 0.0
        memUsedAggregate = 0.0
        driveUsedMBAggregate = 0.0
        driveKBReadsAggregate = 0.0
        driveKBWritesAggregate = 0.0
        networkKBInAggregate = 0.0
        networkKBOutAggregate = 0.0
        aggregateLoopCount = 0     

        #these are used to hold the most current value for display in the html
        currentCPUUsed = 0.0
        currentCPUClockSpeed = 0.0
        currentCPUTemp = 0.0
        currentMemUsed = 0.0
        currentMemTotal = 0.0    
        currentDriveTotal = 0.0 
        currentDriveUsedMB = 0.0
        currentDriveKBRead = 0.0
        currentDriveKBWrites = 0.0
        currentNetworkKBIn = 0.0
        currentNetworkKBOut = 0.0
        currentUptime = ""           

        Dir.mkdir(chartsSaveFolder) unless Dir.exist?(chartsSaveFolder)        
        
        aggregateCount = parsedStatArray.length / 60
        if (parsedStatArray.length % 60 != 0)
            aggregateCount += 1
        end
        if (aggregateCount < 1)
           aggregateCount = 1
        end        
        parsedStatArray.each do |statHashes|
            cpuUsedAggregate += statHashes["cpuused"].to_f
            cpuClockSpeedAggregate += statHashes["cpuclockspeed"].to_f
            cpuTempAggregate += statHashes["cputemp"].to_f
            memUsedAggregate += ((statHashes["MemTotal"].to_f - statHashes["MemAvailable"].to_f) / 1024)
            driveUsedMBAggregate += statHashes["driveusedmb"].to_f
            driveKBReadsAggregate += statHashes["drivekbreads"].to_f
            driveKBWritesAggregate += statHashes["drivekbwrites"].to_f
            networkKBInAggregate += statHashes["networkkbin"].to_f
            networkKBOutAggregate += statHashes["networkkbout"].to_f

            #these are intentionally = and not += so we just take the last value provided
            currentCPUUsed = statHashes["cpuused"].to_f
            currentCPUClockSpeed = statHashes["cpuclockspeed"].to_f
            currentCPUTemp = statHashes["cputemp"].to_f
            currentMemUsed = ((statHashes["MemTotal"].to_f - statHashes["MemAvailable"].to_f) / 1024)
            currentDriveUsedMB = statHashes["driveusedmb"].to_f
            currentDriveKBRead = statHashes["drivekbreads"].to_f
            currentDriveKBWrites = statHashes["drivekbwrites"].to_f
            currentNetworkKBIn = statHashes["networkkbin"].to_f
            currentNetworkKBOut = statHashes["networkkbout"].to_f
            currentMemTotal = (statHashes["MemTotal"].to_f / 1024)
            currentDriveTotal = statHashes["drivetotalmb"].to_f
            currentUptime = statHashes["systemuptime"]
            
            aggregateLoopCount += 1
            #if we have enough aggregate values, get average now
            if (aggregateLoopCount == aggregateCount)
                cpuUsed << (cpuUsedAggregate / aggregateCount)
                cpuClockSpeed << (cpuClockSpeedAggregate / aggregateCount)
                cpuTemp << (cpuTempAggregate / aggregateCount)
                memUsed << (memUsedAggregate / aggregateCount)
                driveUsedMB << (driveUsedMBAggregate / aggregateCount)
                driveKBReads << (driveKBReadsAggregate / aggregateCount)
                driveKBWrites << (driveKBWritesAggregate / aggregateCount)
                networkKBIn << (networkKBInAggregate / aggregateCount)
                networkKBOut << (networkKBOutAggregate / aggregateCount)
                
                cpuUsedAggregate = 0.0
                cpuClockSpeedAggregate = 0.0
                cpuTempAggregate = 0.0
                memUsedAggregate = 0.0
                driveUsedMBAggregate = 0.0
                driveKBReadsAggregate = 0.0
                driveKBWritesAggregate = 0.0
                networkKBInAggregate = 0.0
                networkKBOutAggregate = 0.0
                
                aggregateLoopCount = 0
            end
        end
        #if we had any remaining values, average them now
        if (aggregateLoopCount != 0)
            cpuUsed << (cpuUsedAggregate / aggregateLoopCount)
            cpuClockSpeed << (cpuClockSpeedAggregate / aggregateLoopCount)
            cpuTemp << (cpuTempAggregate / aggregateLoopCount)
            memUsed << (memUsedAggregate / aggregateLoopCount)
            driveUsedMB << (driveUsedMBAggregate / aggregateLoopCount)
            driveKBReads << (driveKBReadsAggregate / aggregateLoopCount)
            driveKBWrites << (driveKBWritesAggregate / aggregateLoopCount)
            networkKBIn << (networkKBInAggregate / aggregateLoopCount)
            networkKBOut << (networkKBOutAggregate / aggregateLoopCount)
        end        
        
        cpuPercentageChart = generateSVGChart(cpuUsed, chartWidth, chartHeight, 100,
                                              chartBackgroundColor, chartForegroundColor)
        cpuPercentageChart.save(File.join(chartsSaveFolder, "cpuPercentChart.svg"))

        cpuClockChart = generateSVGChart(cpuClockSpeed, chartWidth, chartHeight, 2000, 
                                         chartBackgroundColor, chartForegroundColor)
        cpuClockChart.save(File.join(chartsSaveFolder, "cpuClockChart.svg"))
        
        cpuTempChart = generateSVGChart(cpuTemp, chartWidth, chartHeight, 90,
                                        chartBackgroundColor, chartForegroundColor)
        cpuTempChart.save(File.join(chartsSaveFolder, "cpuTempChart.svg"))

        memUsedChart = generateSVGChart(memUsed, chartWidth, chartHeight, currentMemTotal,
                                        chartBackgroundColor, chartForegroundColor)
        memUsedChart.save(File.join(chartsSaveFolder, "memUsedChart.svg"))

        driveUsedChart = generateSVGChart(driveUsedMB, chartWidth, chartHeight, currentDriveTotal,
                                          chartBackgroundColor, chartForegroundColor)
        driveUsedChart.save(File.join(chartsSaveFolder, "driveUsedChart.svg"))

        driveKBReadsChart = generateSVGChart(driveKBReads, chartWidth, chartHeight, (400 * 1024),
                                            chartBackgroundColor, chartForegroundColor)
        driveKBReadsChart.save(File.join(chartsSaveFolder, "drivesKBReadsChart.svg"))

        driveKBWritesChart = generateSVGChart(driveKBWrites, chartWidth, chartHeight, (400 * 1024),
                                             chartBackgroundColor, chartForegroundColor)
        driveKBWritesChart.save(File.join(chartsSaveFolder, "drivesKBWritesChart.svg"))

        networkTrafficInChart = generateSVGChart(networkKBIn, chartWidth, chartHeight, (1 * 1024 *1024), 
                                                 chartBackgroundColor, chartForegroundColor)
        networkTrafficInChart.save(File.join(chartsSaveFolder, "networkTrafficInChart.svg"))

        networkTrafficOutChart = generateSVGChart(networkKBOut, chartWidth, chartHeight, (1 * 1024 * 1024),
                                                  chartBackgroundColor, chartForegroundColor)
        networkTrafficOutChart.save(File.join(chartsSaveFolder, "networkTrafficOutChart.svg"))


        mergeAndUpdateHTML(currentCPUUsed, currentCPUClockSpeed, currentCPUTemp, currentMemUsed, currentMemTotal,
                           currentDriveTotal, currentDriveUsedMB, currentDriveKBRead, currentDriveKBWrites,
                           currentNetworkKBIn, currentNetworkKBOut, currentUptime)

    end

  

    def self.mergeAndUpdateHTML(currentCPUUsed, currentCPUClockSpeed, currentCPUTemp, currentMemUsed, currentMemTotal,
                                currentDriveTotal, currentDriveUsedMB, currentDriveKBRead, currentDriveKBWrites,
                                currentNetworkKBIn, currentNetworkKBOut, currentUptime)
        
        indexLocation = "./content/monitor/index.html"
        indexTemplateLocation = "./content/monitor/index-template.html"
        htmlContent = File.read(indexTemplateLocation)

        htmlContent.gsub!("{cpuPercentValue}", (currentCPUUsed.round(2)).to_s)
        htmlContent.gsub!("{cpuClockValue}", (currentCPUClockSpeed.round(2)).to_s)
        htmlContent.gsub!("{cpuTempValue}", (currentCPUTemp.round(2)).to_s)
        htmlContent.gsub!("{memUsedValue}", currentMemUsed.to_i.to_s)
        htmlContent.gsub!("{memTotalValue}", (currentMemTotal.round(2)).to_s)
        htmlContent.gsub!("{driveUsedValue}", ((((currentDriveUsedMB.to_f / currentDriveTotal.to_f) * 100).round(2)).to_s))
        htmlContent.gsub!("{driveKBReadsValue}", (currentDriveKBRead.round(2)).to_s)
        htmlContent.gsub!("{driveKBWritesValue}", (currentDriveKBWrites.round(2)).to_s)
        htmlContent.gsub!("{currentNetInValue}", (currentNetworkKBIn.round(2)).to_s)
        htmlContent.gsub!("{currentNetOutValue}", (currentNetworkKBOut.round(2)).to_s)
        htmlContent.gsub!("{uptimeValueRaw}", currentUptime.to_s.gsub("up ", ""))
        htmlContent.gsub!("{generationtime}", Time.new.strftime("%Y-%m-%d %H:%M:%S"))

        File.write(indexLocation, htmlContent)
    end

    def self.parseStatFiles(fileArray)
        statArray = Array.new
        fileArray.each do |file|
            statHash = Hash.new
            IO.foreach(file) do |line|
                statValues = line.chomp.split("=")
                statHash[statValues[0].to_s] = statValues[1]
            end
            statArray << statHash
        end

        return statArray
    end

    def self.rotateStatsAndGenerateStatArray()
        time = Time.new
        txtFiles = File.join(@statsDir, "*.txt")
        returnedArray = Array.new
        Dir.glob(txtFiles) do |file|
            fileStat = File::Stat.new(file)
            cutoffDate = (time - (@statCutoff)) #in seconds
            if fileStat.ctime < cutoffDate
                Log.log("Deleting #{file} as part of log rotation.", 2)
                File.delete(file)
            else
                returnedArray << file
            end
        end

        return returnedArray.sort()
    end
end