require 'json'
require 'net/http'
require 'date'

$HOST = "JIRA-HOST"
$USERNAME = "JIRA-USERNAME"
$PASSWORD = "JIRA-PASSWORD"
$RAPID_VIEW_ID = "RAPID-VIEW-ID"

sprintQuery = "#{$HOST}/rest/greenhopper/1.0/sprintquery/#{$RAPID_VIEW_ID}?includeFutureSprints=false"
burndownQuery = "#{$HOST}/rest/greenhopper/1.0/rapid/charts/scopechangeburndownchart.json?rapidViewId=#{$RAPID_VIEW_ID}&sprintId=%s"

def fetch(uri)
  request = Net::HTTP::Get.new(uri)
  request.basic_auth $USERNAME, $PASSWORD

  Net::HTTP.start(uri.hostname, uri.port) do |http|
    JSON.parse(http.request(request).body)
  end
end

def date(time)
  Time.at(time.to_i / 1000).to_date
end

def pointsPerStory(changes, story)
  points = 0
  changes.values.each do |change|
    if change[0]['key'] == story && !change[0]['statC'].nil?
      points += change[0]['statC']['newValue'].nil? ? 0 : change[0]['statC']['newValue']
    end
  end
  points
end

def pointsPerDate(changes, startTime)
  pointsPerDate = {}
  points = 0

  changes.each do |change|
    isBeforeStart = change[0].to_i <= startTime
    isAdded = !change[1][0]['added'].nil?
    isDone = !change[1][0]['column'].nil? && !change[1][0]['column']['done'].nil?
    story = change[1][0]['key']
    key = (isBeforeStart ? date(startTime) : date(change[0]))

    pointsPerDate[key] = [] unless pointsPerDate.key?(key)

    next unless isAdded || isDone
    points += ((isDone ? -pointsPerStory(changes, story) : pointsPerStory(changes, story)))
    isBeforeStart ? pointsPerDate[key][0] = points : pointsPerDate[key] << points
  end

  pointsPerDate[Date.today] = [points] unless pointsPerDate.key?(Date.today)
  pointsPerDate
end

def remainingValues(startDate, endDate, pointsPerDate)
  dataPoints = []
  i = 0

  startDate.upto(endDate).each do |date|
    next unless !date.saturday? && !date.sunday?
    if pointsPerDate.key?(date)
      pointsPerDate[date].each_with_index do |points, index|
        dataPoints << { label: date.strftime('%-d %b'), x: "#{i}.#{index + 10}", y: points }
      end
    end
    i += 1
  end
  dataPoints
end

def guideline(startDate, endDate, pointsPerDate)
  labels = startDate.upto(endDate).select { |date| !date.saturday? && !date.sunday? }.map { |date| date.strftime('%-d %b') }
  points = pointsPerDate[startDate][0].step(0, -(pointsPerDate[startDate][0] / (labels.count - 1))).to_a

  labels.map.with_index { |label, index| { label: label, x: index, y: points[index] } }
end

SCHEDULER.every '30m', first_in: 0 do |_job|
  activeSprint = fetch(URI(sprintQuery))['sprints'].find { |sprint| sprint['state'].eql? 'ACTIVE' }
  burndown = fetch(URI(burndownQuery % activeSprint['id']))
  startDate = date(burndown['startTime'])
  endDate = date(burndown['endTime'])
  pointsPerDate = pointsPerDate(burndown['changes'], burndown['startTime'])
  remainingValues = remainingValues(startDate, endDate, pointsPerDate)
  guideline = guideline(startDate, endDate, pointsPerDate)
  data = [{ type: 'line', markerType: 'none', dataPoints: guideline }, { type: 'stepLine', markerType: 'none', dataPoints: remainingValues }]

  send_event('burndown', container: 'burndownChart', data: data, title: 'Burndown Chart')
end
