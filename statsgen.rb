require "minichart"
require "victor"
require "shellwords"
require_relative "logging"

class GenerateStats
    def self.generateStats()
        statsGenInterval = 1
        statsTime = Time.new.strftime("%Y%m%d%H%M%S%L")
        statsDir = "./monitorstatgen/stats/"
        cmd = "./monitorstatgen/statgen.sh > #{statsDir}#{statsTime}.txt"
        
        #you want to do this check every time, because its entirely possible
        #that a user has come by and deleted the directory
        Dir.mkdir(statsDir) unless Dir.exist?(statsDir)
        
        bash(cmd)

        profilerTime = Time.new
        if (Dir[File.join(statsDir + "/**/*")].length <= 1)
            # we need at least 2 stats file to generate a graph
            #you can set a breakpoint here or puts out the time to see how long the above "if" takes
            #mostly this was used to profile huge directories (24k files) to see how long it takes
            #to ask the file system for a count. It doesnt take long on ext4 partitions, <100ms
            profilerTime = (Time.new - profilerTime)
            bp1 = "test"
            sleep(1)
            statsTime = Time.new.strftime("%Y%m%d%H%M%S%L")
            cmd = "./monitorstatgen/statgen.sh > #{statsDir}#{statsTime}.txt"
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


    def self.generateStatHTML(parsedStatArray)
        #chartHeight = 175
        #chartWidth = 525
        chartHeightSmall = 100
        chartWidthSmall = 315
        chartHeightMedium = 125
        chartWidthMedium = 825
        chartHeightLarge = 150
        chartWidthLarge = 1700

        chartBackgroundColor = "#1f3445"
        chartForegroundColor = "#3899e8"
        chartsSaveFolder = "./content/monitor/images"
        parsedStatArrayLength = parsedStatArray.length

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
        aggregateLoopCountSmall = 0
        aggregateLoopCountMedium = 0
        aggregateLoopCountLarge = 0

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
        
        aggregateSizeSmall = 78 # 40 # 42 is a point ~ every 8.75 pixels
        aggregateSizeMedium =  205 # 91
        aggregateSizeLarge = 425 # 208
        
        aggregateCountSmall = parsedStatArrayLength / aggregateSizeSmall
        aggregateCountMedium = parsedStatArrayLength / aggregateSizeMedium
        aggregateCountLarge = parsedStatArrayLength / aggregateSizeLarge

        if (parsedStatArray.length % aggregateSizeSmall != 0)
            aggregateCountSmall += 1
        end
        if (aggregateCountSmall < 1)
           aggregateCountSmall = 1
        end

        if (parsedStatArray.length % aggregateSizeMedium != 0)
            aggregateCountMedium += 1
        end
        if (aggregateCountMedium < 1)
           aggregateCountMedium = 1
        end

        if (parsedStatArray.length % aggregateSizeLarge != 0)
            aggregateCountLarge += 1
        end
        if (aggregateCountLarge < 1)
           aggregateCountLarge = 1
        end

        Dir.mkdir(chartsSaveFolder) unless Dir.exist?(chartsSaveFolder)  
        
        parsedStatArray.each_with_index do |statHashes, index|
            cpuUsedAggregate += statHashes["cpuused"].to_f
            cpuClockSpeedAggregate += statHashes["cpuclockspeed"].to_f
            cpuTempAggregate += statHashes["cputemp"].to_f
            memUsedAggregate += ((statHashes["MemTotal"].to_f - statHashes["MemAvailable"].to_f) / 1024)
            driveUsedMBAggregate += statHashes["driveusedmb"].to_f
            driveKBReadsAggregate += statHashes["drivekbreads"].to_f
            driveKBWritesAggregate += statHashes["drivekbwrites"].to_f
            networkKBInAggregate += statHashes["networkkbin"].to_f
            networkKBOutAggregate += statHashes["networkkbout"].to_f

            #we only want the last value
            if (index == parsedStatArrayLength - 1)
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
            end

            aggregateLoopCountSmall += 1
            aggregateLoopCountMedium += 1
            aggregateLoopCountLarge += 1
            #if we have enough aggregate values, get average now
            if (aggregateLoopCountLarge == aggregateCountLarge)
                cpuUsed << (cpuUsedAggregate / aggregateCountLarge)
                memUsed << (memUsedAggregate / aggregateCountLarge)
                
                cpuUsedAggregate = 0.0
                memUsedAggregate = 0.0
                
                aggregateLoopCountLarge = 0
            end
            if (aggregateLoopCountMedium == aggregateCountMedium)
                cpuClockSpeed << (cpuClockSpeedAggregate / aggregateCountMedium)
                cpuTemp << (cpuTempAggregate / aggregateCountMedium)
                cpuClockSpeedAggregate = 0.0
                cpuTempAggregate = 0.0
                
                aggregateLoopCountMedium = 0
            end
            if (aggregateLoopCountSmall == aggregateCountSmall)
                driveUsedMB << (driveUsedMBAggregate / aggregateCountSmall)
                driveKBReads << (driveKBReadsAggregate / aggregateCountSmall)
                driveKBWrites << (driveKBWritesAggregate / aggregateCountSmall)
                networkKBIn << (networkKBInAggregate / aggregateCountSmall)
                networkKBOut << (networkKBOutAggregate / aggregateCountSmall)
                driveUsedMBAggregate = 0.0
                driveKBReadsAggregate = 0.0
                driveKBWritesAggregate = 0.0
                networkKBInAggregate = 0.0
                networkKBOutAggregate = 0.0
                
                aggregateLoopCountSmall = 0
            end
        end
        #if we had any remaining values, average them now
        if (aggregateLoopCountLarge != 0)
            cpuUsed << (cpuUsedAggregate / aggregateLoopCountLarge)
            memUsed << (memUsedAggregate / aggregateLoopCountLarge)
        end        
        if (aggregateLoopCountMedium != 0)
            cpuClockSpeed << (cpuClockSpeedAggregate / aggregateLoopCountMedium)
            cpuTemp << (cpuTempAggregate / aggregateLoopCountMedium)
        end
        if (aggregateLoopCountSmall != 0)
            driveUsedMB << (driveUsedMBAggregate / aggregateLoopCountSmall)
            driveKBReads << (driveKBReadsAggregate / aggregateLoopCountSmall)
            driveKBWrites << (driveKBWritesAggregate / aggregateLoopCountSmall)
            networkKBIn << (networkKBInAggregate / aggregateLoopCountSmall)
            networkKBOut << (networkKBOutAggregate / aggregateLoopCountSmall)
        end
        
        #large charts
        cpuPercentageChart = generateSVGChart(cpuUsed, chartWidthLarge, chartHeightLarge, 100,
                                              chartBackgroundColor, chartForegroundColor)
        cpuPercentageChart.save(File.join(chartsSaveFolder, "cpuPercentChart.svg"))

        memUsedChart = generateSVGChart(memUsed, chartWidthLarge, chartHeightLarge, currentMemTotal,
                                        chartBackgroundColor, chartForegroundColor)
        memUsedChart.save(File.join(chartsSaveFolder, "memUsedChart.svg"))

        #medium charts
        cpuClockChart = generateSVGChart(cpuClockSpeed, chartWidthMedium, chartHeightMedium, 2000, 
                                         chartBackgroundColor, chartForegroundColor)
        cpuClockChart.save(File.join(chartsSaveFolder, "cpuClockChart.svg"))
        
        cpuTempChart = generateSVGChart(cpuTemp, chartWidthMedium, chartHeightMedium, 90,
                                        chartBackgroundColor, chartForegroundColor)
        cpuTempChart.save(File.join(chartsSaveFolder, "cpuTempChart.svg"))

        #small charts
        driveUsedChart = generateSVGChart(driveUsedMB, chartWidthSmall, chartHeightSmall, currentDriveTotal,
                                          chartBackgroundColor, chartForegroundColor)
        driveUsedChart.save(File.join(chartsSaveFolder, "driveUsedChart.svg"))

        driveKBReadsChart = generateSVGChart(driveKBReads, chartWidthSmall, chartHeightSmall, (400 * 1024),
                                            chartBackgroundColor, chartForegroundColor)
        driveKBReadsChart.save(File.join(chartsSaveFolder, "drivesKBReadsChart.svg"))

        driveKBWritesChart = generateSVGChart(driveKBWrites, chartWidthSmall, chartHeightSmall, (400 * 1024),
                                             chartBackgroundColor, chartForegroundColor)
        driveKBWritesChart.save(File.join(chartsSaveFolder, "drivesKBWritesChart.svg"))

        networkTrafficInChart = generateSVGChart(networkKBIn, chartWidthSmall, chartHeightSmall, (1 * 1024 *1024), 
                                                 chartBackgroundColor, chartForegroundColor)
        networkTrafficInChart.save(File.join(chartsSaveFolder, "networkTrafficInChart.svg"))

        networkTrafficOutChart = generateSVGChart(networkKBOut, chartWidthSmall, chartHeightSmall, (1 * 1024 * 1024),
                                                  chartBackgroundColor, chartForegroundColor)
        networkTrafficOutChart.save(File.join(chartsSaveFolder, "networkTrafficOutChart.svg"))


        mergeAndUpdateHTML(currentCPUUsed, currentCPUClockSpeed, currentCPUTemp, currentMemUsed, currentMemTotal,
                           currentDriveTotal, currentDriveUsedMB, currentDriveKBRead, currentDriveKBWrites,
                           currentNetworkKBIn, currentNetworkKBOut, currentUptime)

    end
    



    def self.generatePlotPoints(chartHeight, chartWidth, value, maxValue, currentPoint, totalPoints)
        plotPointXSteps = (chartWidth.to_f / totalPoints.to_f)
        plotPointVerticalSteps = (chartHeight.to_f / maxValue.to_f)

        begin
            pointX = (currentPoint * plotPointXSteps).to_i
            pointY = (chartHeight + 1 - (value * plotPointVerticalSteps)).to_i
            if (pointY <= 0)
                pointY = 1
            end
            #chartHeight + 1 because we want the 2px stroke to ride the top of the chart
            plotPoint = (pointX).to_s + "," + (pointY).to_s

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
                #chartHeight - 1 because we want the 2px stroke to ride the top of the chart
                chartPlotPoints += generatePlotPoints(chartHeight - 1, chartWidth, value, maxValue, currentPoint, totalPoints) + " "
                currentPoint += 1
            end

        rescue Exception => e
            puts e
        end
        chart.build do
            rect(x:0, y: 0, width: chartWidth, height: chartHeight, fill: chartBackgroundColor)
            polyline(points: chartPlotPoints , style: svgStyle)
            #the first x marker needs to sit at 1, not 0, so the whole thing shows in the chart
            line(x1: rightMarkersX, y1: 1,                         x2: chartWidth, y2: 1,                         style: markerStyle )
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



end