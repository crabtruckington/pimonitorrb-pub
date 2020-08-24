require "minichart"
require "victor"
require_relative "logging"

class StatsGen
    include Minichart
    include Victor
    @statsInterval = 10 #in seconds
    @statCutoff = (60 * 60 * 1) #in seconds
    @statsDir = "./monitorstatgen/stats/"

    def self.statsGenThread()
        time = Time.new
        statsTime = time.strftime("%Y%m%d%H%M%S%L")
        fileArray = Array.new
        parsedStatArray = Array.new
        
        Log.log("Generating new stats...", 0)
        Dir.mkdir(@statsDir) unless Dir.exist?(@statsDir)
        system("./monitorstatgen/statgen.sh > #{@statsDir}#{statsTime}.txt")
        if (Dir[File.join(@statsDir + "/**/*")].length <= 1)
            # we need at least 2 stats file to generate a graph
            time = Time.new
            statsTime = time.strftime("%Y%m%d%H%M%S%L")
            system("./monitorstatgen/statgen.sh > #{@statsDir}#{statsTime}.txt")
        end
        Log.log("Stats generated, rotating stats and sorting stat list...", 0)
        fileArray = rotateStatsAndGenerateStatArray()
        Log.log("Stats rotated, generating new stats", 0)
        parsedStatArray = parseStatFiles(fileArray)
        Log.log("Generating HTML content and images", 0)
        generateStatHTML(parsedStatArray)
        Log.log("Garbage collecting", 0)
        GC.start()
        Log.log("Stats generation sleeping for #{@statsInterval}", 0)
        sleep(@statsInterval)
        statsGenThread()
    end

    def self.generatePlotPoints(chartHeight, chartWidth, value, maxValue, currentPoint, totalPoints)
        plotPointXSteps = (chartWidth.to_f / totalPoints.to_f)
        plotPointVerticalSteps = (chartHeight.to_f / maxValue.to_f)

        plotPoint = (currentPoint * plotPointXSteps).to_i.to_s + "," + (chartHeight + 50 - (value * plotPointVerticalSteps)).to_i.to_s

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
            chartPlotPoints += generatePlotPoints(chartHeight - 50, chartWidth, value, maxValue, currentPoint, totalPoints) + " "
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
        chartHeight = 150
        chartWidth = 400
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


        Dir.mkdir(chartsSaveFolder) unless Dir.exist?(chartsSaveFolder)
        parsedStatArray.each do |statHashes|
            cpuUsed << statHashes["cpuuser"].to_f + statHashes["cpusystem"].to_f
            #cpuUser << statHashes["cpuuser"]
            #cpuSystem << statHashes["cpusystem"]
            cpuIdle << statHashes["cpuidle"].to_f
            cpuClockSpeed << statHashes["cpuclockspeed"].to_f
            cpuTemp << statHashes["cputemp"].to_f
            memUsed << (statHashes["MemTotal"].to_f - statHashes["MemAvailable"].to_f) / 1024 #in MB
            memTotal << (statHashes["MemTotal"].to_f / 1024)
            #memFree << statHashes["MemFree"]
            #memAvailable << statHashes["MemAvailable"]
            driveTotalMB << statHashes["drivetotalmb"].to_f
            driveUsedMB << statHashes["driveusedmb"].to_f
            driveAvailableMB << statHashes["driveavailablemb"].to_f
            driveKBReads << statHashes["drivekbreads"].to_f
            driveKBWrites << statHashes["drivekbwrites"].to_f
            networkKBIn << statHashes["networkkbin"].to_f
            networkKBOut << statHashes["networkkbout"].to_f
            uptime << statHashes["systemuptime"] # this is the date the system started
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
        htmlContent.gsub!("{cpuClockValue}", cpuClockSpeed[cpuClockSpeed.length() - 1].to_s)
        htmlContent.gsub!("{cpuTempValue}", cpuTemp[cpuTemp.length() - 1].to_s)
        htmlContent.gsub!("{memUsedValue}", memUsed[memUsed.length() - 1].to_i.to_s)
        htmlContent.gsub!("{memTotalValue}", memTotal[0].to_s)
        htmlContent.gsub!("{driveUsedValue}", ((((driveUsedMB[driveUsedMB.length - 1].to_f / driveTotalMB[0].to_f) * 100).round(2)).to_s))
        htmlContent.gsub!("{driveKBReadsValue}", driveKBReads[driveKBReads.length() - 1].to_s)
        htmlContent.gsub!("{driveKBWritesValue}", driveKBWrites[driveKBWrites.length() - 1].to_s)
        htmlContent.gsub!("{currentNetInValue}", networkKBIn[networkKBIn.length() - 1].to_s)
        htmlContent.gsub!("{currentNetOutValue}", networkKBOut[networkKBOut.length() - 1].to_s)
        htmlContent.gsub!("{uptimeValueRaw}", uptime[uptime.length() - 1].to_s)

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