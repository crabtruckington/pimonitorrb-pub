require "minichart"
require "victor"
require_relative "logging"

class GenerateStats
    def self.generateStats()
        statsGenInterval = 5
        time = Time.new
        statsTime = time.strftime("%Y%m%d%H%M%S%L")
        statsDir = "./monitorstatgen/stats/"
        
        Dir.mkdir(statsDir) unless Dir.exist?(statsDir)
        
        system("./monitorstatgen/statgen.sh > #{statsDir}#{statsTime}.txt")
        if (Dir[File.join(statsDir + "/**/*")].length <= 1)
            # we need at least 2 stats file to generate a graph
            sleep(1)
            time = Time.new
            statsTime = time.strftime("%Y%m%d%H%M%S%L")
            system("./monitorstatgen/statgen.sh > #{statsDir}#{statsTime}.txt")
        end
        sleep(statsGenInterval)
    end
end


class HTMLGen
    include Minichart
    include Victor
    @htmlGenInterval = 60 #in seconds
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
        Log.log("HTML generation sleeping for #{@htmlGenInterval}", 0)
        #sleep before exiting
        sleep(@htmlGenInterval)
    end

    def self.generatePlotPoints(chartHeight, chartWidth, value, maxValue, currentPoint, totalPoints)
        plotPointXSteps = (chartWidth.to_f / totalPoints.to_f)
        plotPointVerticalSteps = (chartHeight.to_f / maxValue.to_f)

        plotPoint = (currentPoint * plotPointXSteps).to_i.to_s + "," + (chartHeight - (value * plotPointVerticalSteps)).to_i.to_s

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

        valueArray.each do |value|
            chartPlotPoints += generatePlotPoints(chartHeight, chartWidth, value, maxValue, currentPoint, totalPoints) + " "
            currentPoint += 1
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
        cpuUsed = Array.new #cpuUsed is a combination of User and System to get total percentage load
        #cpuUser = Array.new
        #cpuSystem = Array.new
        cpuIdle = Array.new
        cpuClockSpeed = Array.new
        cpuTemp = Array.new
        memUsed = Array.new #memUsed is a combination of memTotal - memAvailable
        memTotal = Array.new
        #memFree = Array.new
        #memAvailable = Array.new
        driveTotalMB = Array.new
        driveUsedMB = Array.new
        driveAvailableMB = Array.new
        driveKBReads = Array.new
        driveKBWrites = Array.new
        networkKBIn = Array.new
        networkKBOut = Array.new
        uptime = Array.new
        cpuUsedAggregate = 0.0
        cpuClockSpeedAggregate = 0.0
        cpuTempAggregate = 0.0
        memUsedAggregate = 0.0
        memTotalAggregate = 0.0    
        driveTotalAggregate = 0.0 
        driveUsedMBAggregate = 0.0
        driveKBReadsAggregate = 0.0
        driveKBWritesAggregate = 0.0
        networkKBInAggregate = 0.0
        networkKBOutAggregate = 0.0
        uptimeAggregate = 0.0   
        aggregateLoopCount = 0     


        Dir.mkdir(chartsSaveFolder) unless Dir.exist?(chartsSaveFolder)
        
        
        aggregateCount = parsedStatArray.length / 60
        if (parsedStatArray.length % 60 != 0)
            aggregateCount += 1
        end
        if (aggregateCount < 1)
           aggregateCount = 1
        end


        
        parsedStatArray.each do |statHashes|
            cpuUsedAggregate += statHashes["cpuuser"].to_f + statHashes["cpusystem"].to_f
            cpuClockSpeedAggregate += statHashes["cpuclockspeed"].to_f
            cpuTempAggregate += statHashes["cputemp"].to_f
            memUsedAggregate += ((statHashes["MemTotal"].to_f - statHashes["MemAvailable"].to_f) / 1024)
            driveUsedMBAggregate += statHashes["driveusedmb"].to_f
            driveKBReadsAggregate += statHashes["drivekbreads"].to_f
            driveKBWritesAggregate += statHashes["drivekbwrites"].to_f
            networkKBInAggregate += statHashes["networkkbin"].to_f
            networkKBOutAggregate += statHashes["networkkbout"].to_f

            #these are intentionally = and not += so we just take the last value provided
            memTotalAggregate = (statHashes["MemTotal"].to_f / 1024)
            driveTotalAggregate = statHashes["drivetotalmb"].to_f
            uptimeAggregate = statHashes["systemuptime"]

            
            aggregateLoopCount += 1
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
        # feed in the singleton values
        memTotal << memTotalAggregate 
        driveTotalMB << driveTotalAggregate
        uptime << uptimeAggregate

            # cpuUsed << statHashes["cpuuser"].to_f + statHashes["cpusystem"].to_f
            # cpuClockSpeed << statHashes["cpuclockspeed"].to_f
            # cpuTemp << statHashes["cputemp"].to_f
            # memUsed << (statHashes["MemTotal"].to_f - statHashes["MemAvailable"].to_f) / 1024 #in MB
            # #memTotal << (statHashes["MemTotal"].to_f / 1024)
            # #driveTotalMB << statHashes["drivetotalmb"].to_f
            # driveUsedMB << statHashes["driveusedmb"].to_f
            # driveKBReads << statHashes["drivekbreads"].to_f
            # driveKBWrites << statHashes["drivekbwrites"].to_f
            # networkKBIn << statHashes["networkkbin"].to_f
            # networkKBOut << statHashes["networkkbout"].to_f
            # #uptime << statHashes["systemuptime"] # this is the date the system started
        # end

        
        cpuPercentageChart = generateSVGChart(cpuUsed, chartWidth, chartHeight, 100,
                                                  chartBackgroundColor, chartForegroundColor)
        cpuPercentageChart.save(File.join(chartsSaveFolder, "cpuPercentChart.svg"))

        cpuClockChart = generateSVGChart(cpuClockSpeed, chartWidth, chartHeight, 2000, 
                                             chartBackgroundColor, chartForegroundColor)
        cpuClockChart.save(File.join(chartsSaveFolder, "cpuClockChart.svg"))
        
        cpuTempChart = generateSVGChart(cpuTemp, chartWidth, chartHeight, 90,
                                        chartBackgroundColor, chartForegroundColor)
        cpuTempChart.save(File.join(chartsSaveFolder, "cpuTempChart.svg"))

        memUsedChart = generateSVGChart(memUsed, chartWidth, chartHeight, memTotal[0],
                                        chartBackgroundColor, chartForegroundColor)
        memUsedChart.save(File.join(chartsSaveFolder, "memUsedChart.svg"))

        driveUsedChart = generateSVGChart(driveUsedMB, chartWidth, chartHeight, driveTotalMB[0],
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


        mergeAndUpdateHTML(cpuUsed, cpuClockSpeed, cpuTemp, memUsed, memTotal, driveTotalMB, driveUsedMB, driveAvailableMB,
                           driveKBReads, driveKBWrites, networkKBIn, networkKBOut, uptime)

    end

  

    def self.mergeAndUpdateHTML(cpuUsed, cpuClockSpeed, cpuTemp, memUsed, memTotal, driveTotalMB, driveUsedMB, driveAvailableMB,
                                driveKBReads, driveKBWrites, networkKBIn, networkKBOut, uptime)
        
        indexLocation = "./content/monitor/index.html"
        indexTemplateLocation = "./content/monitor/index-template.html"
        htmlContent = File.read(indexTemplateLocation)

        htmlContent.gsub!("{cpuPercentValue}", (cpuUsed[cpuUsed.length() - 1].round(2)).to_s)
        htmlContent.gsub!("{cpuClockValue}", (cpuClockSpeed[cpuClockSpeed.length() - 1].round(2)).to_s)
        htmlContent.gsub!("{cpuTempValue}", (cpuTemp[cpuTemp.length() - 1].round(2)).to_s)
        htmlContent.gsub!("{memUsedValue}", memUsed[memUsed.length() - 1].to_i.to_s)
        htmlContent.gsub!("{memTotalValue}", (memTotal[0].round(2)).to_s)
        htmlContent.gsub!("{driveUsedValue}", ((((driveUsedMB[driveUsedMB.length - 1].to_f / driveTotalMB[0].to_f) * 100).round(2)).to_s))
        htmlContent.gsub!("{driveKBReadsValue}", (driveKBReads[driveKBReads.length() - 1].round(2)).to_s)
        htmlContent.gsub!("{driveKBWritesValue}", (driveKBWrites[driveKBWrites.length() - 1].round(2)).to_s)
        htmlContent.gsub!("{currentNetInValue}", (networkKBIn[networkKBIn.length() - 1].round(2)).to_s)
        htmlContent.gsub!("{currentNetOutValue}", (networkKBOut[networkKBOut.length() - 1].round(2)).to_s)
        htmlContent.gsub!("{uptimeValueRaw}", uptime[0].to_s.gsub("up ", ""))
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