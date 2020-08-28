require "victor"
require "shellwords"
require_relative "logging"
require_relative "configs"
require_relative "sqlHelpers"

class GenerateStats
    @statInterval = Configs.getConfigValue("statsGenInterval")
    def self.generateStats()
        statsGenInterval = @statInterval
        cmd = "./monitorstatgen/statgen.sh"
        columnList = ""
        valueList = ""
        
        stats = bash(cmd)

        stats.each_line do |line|
            statValues = line.chomp.split("=")
            if (statValues[0] == "systemuptime")
                columnList << statValues[0].to_s << ","
                valueList << "'" << statValues[1].to_s << "',"
            else
                columnList << statValues[0].to_s << ","
                valueList << statValues[1].to_s << ","
            end
        end

        columnList.delete_suffix!(",")
        valueList.delete_suffix!(",")

        SQLMethods.insertStats(columnList, valueList)

        sleep(statsGenInterval)
    end

    def self.bash(command)
        escapedCommand = Shellwords.escape(command)
        result = `bash -c #{escapedCommand}`.chomp
        return result
    end
end

class HTMLGen
    include Victor
    @statsgenStartTime

    def self.htmlGenThread()
        @statsgenStartTime = Time.new
        Log.log("Generating HTML content and images", 0)
        generateStatHTML()
    end

    def self.generateStatHTML()
        #chartHeight = 175 #default sizes if you want 3x3 column stat page
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

        aggregateSizeSmall = 78 # 40 # 42 is a point ~ every 8.75 pixels
        aggregateSizeMedium =  205 # 91
        aggregateSizeLarge = 425 # 208

        #big chart
        cpuUsed = Array.new
        memUsed = Array.new #memUsed is a combination of memTotal - memAvailable
        
        #medium chart
        cpuClockSpeed = Array.new
        cpuTemp = Array.new

        #small chart
        driveUsedMB = Array.new
        driveKBReads = Array.new
        driveKBWrites = Array.new
        networkKBIn = Array.new
        networkKBOut = Array.new


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

        SQLMethods.openSharedConnection()
        cpuUsed = SQLMethods.getStatAggregate(aggregateSizeLarge, "cpuused")
        memUsed = SQLMethods.getComputedStatAggregate(aggregateSizeLarge, "memused", "memtotal", "memavailable")

        cpuClockSpeed = SQLMethods.getStatAggregate(aggregateSizeMedium, "cpuclockspeed")
        cpuTemp = SQLMethods.getStatAggregate(aggregateSizeMedium, "cputemp")

        driveUsedMB = SQLMethods.getStatAggregate(aggregateSizeSmall, "driveusedmb")
        driveKBReads = SQLMethods.getStatAggregate(aggregateSizeSmall, "drivekbreads")
        driveKBWrites = SQLMethods.getStatAggregate(aggregateSizeSmall, "drivekbwrites")
        networkKBIn = SQLMethods.getStatAggregate(aggregateSizeSmall, "networkkbin")
        networkKBOut = SQLMethods.getStatAggregate(aggregateSizeSmall, "networkkbout")

        currentCPUUsed = SQLMethods.getMostRecentStatValue("cpuused").to_f
        currentCPUClockSpeed = SQLMethods.getMostRecentStatValue("cpuclockspeed").to_f
        currentCPUTemp = SQLMethods.getMostRecentStatValue("cputemp").to_f
        currentMemTotal = SQLMethods.getMostRecentStatValue("memtotal").to_f
        currentMemUsed = (currentMemTotal - SQLMethods.getMostRecentStatValue("memavailable").to_f)
        currentDriveUsedMB = SQLMethods.getMostRecentStatValue("driveusedmb").to_f
        currentDriveTotal = SQLMethods.getMostRecentStatValue("drivetotalmb").to_f
        currentDriveKBRead = SQLMethods.getMostRecentStatValue("drivekbreads").to_f
        currentDriveKBWrites = SQLMethods.getMostRecentStatValue("drivekbwrites").to_f
        currentNetworkKBIn = SQLMethods.getMostRecentStatValue("networkkbin").to_f
        currentNetworkKBOut = SQLMethods.getMostRecentStatValue("networkkbout").to_f
        currentUptime = SQLMethods.getMostRecentStatValue("systemuptime")
        SQLMethods.closeSharedConnection()

        
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
            plotPoint = (pointX).to_s << "," << (pointY).to_s

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
                chartPlotPoints << generatePlotPoints(chartHeight - 1, chartWidth, value, maxValue, currentPoint, totalPoints) << " "
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
        htmlContent.gsub!("{memUsedValue}", (currentMemUsed / 1024).to_i.to_s)
        htmlContent.gsub!("{memTotalValue}", ((currentMemTotal / 1024).round(2)).to_s)
        htmlContent.gsub!("{driveUsedValue}", ((((currentDriveUsedMB.to_f / currentDriveTotal.to_f) * 100).round(2)).to_s))
        htmlContent.gsub!("{driveKBReadsValue}", (currentDriveKBRead.round(2)).to_s)
        htmlContent.gsub!("{driveKBWritesValue}", (currentDriveKBWrites.round(2)).to_s)
        htmlContent.gsub!("{currentNetInValue}", (currentNetworkKBIn.round(2)).to_s)
        htmlContent.gsub!("{currentNetOutValue}", (currentNetworkKBOut.round(2)).to_s)
        htmlContent.gsub!("{uptimeValueRaw}", currentUptime.to_s.gsub("up ", ""))
        htmlContent.gsub!("{generationtime}", (Time.new.strftime("%Y-%m-%d %H:%M:%S") + ", took " +
                                              (Time.new - @statsgenStartTime).round(2).to_s + " seconds"))

        File.write(indexLocation, htmlContent)
    end

end