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

  Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
    JSON.parse(http.request(request).body)
  end
end

def date(time)
  Time.at(time.to_i / 1000).to_date
end

def pointsPerStory(changesPerDate, story)
  points = 0
  changesPerDate.values.each do |changes|
    changes.each do |change|
      if change['key'] == story && !change['statC'].nil?
        points += change['statC']['newValue'].nil? ? 0 : change['statC']['newValue']
      end
    end
  end
  points
end

def pointsPerDate(changesPerDate, startTime, endTime)
  pointsPerDate = {}
  points = 0

  changesPerDate.each do |changes|
    isBeforeStart = changes[0].to_i <= startTime
    key = (isBeforeStart ? date(startTime) : date(changes[0]))
    pointsPerDate[key] = [] unless pointsPerDate.key?(key)

    changes[1].each do |change|
      isAdded = !change['added'].nil?
      isDone = !change['column'].nil? && !change['column']['done'].nil?
      story = change['key']

      if isAdded || isDone
        points += ((isDone ? -pointsPerStory(changesPerDate, story) : pointsPerStory(changesPerDate, story)))
        isBeforeStart ? pointsPerDate[key][0] = points : pointsPerDate[key] << points
      end
    end
  end
  lastKey = date(endTime) < Date.today ? date(endTime) : Date.today
  pointsPerDate[lastKey] = [points] unless pointsPerDate.key?(lastKey)
  pointsPerDate
end

def remainingValues(startDate, endDate, pointsPerDate)
  dataPoints = []
  i = 0

  startDate.upto(endDate).each do |date|
    if pointsPerDate.key?(date)
      pointsPerDate[date].each_with_index do |points, index|
        dataPoints << {label: date.strftime('%-d %b'), x: "#{i}.#{index == 0 ? 0 : index + 10}", y: points}
      end
    end
    i += 1
  end
  dataPoints
end

def guideline(startDate, endDate, pointsPerDate)
  labels = startDate.upto(endDate).map { |date| date.strftime('%-d %b') }
  weekdays = (startDate.upto(endDate).reject { |date| date.saturday? || date.sunday? }.count) - 1
  points = pointsPerDate[startDate][0].step(0, -(pointsPerDate[startDate][0] / weekdays)).to_a
  startDate.upto(endDate).each.with_index do |date, index|
    if date.saturday? || date.sunday?
      points.insert(index, points[index])
    end
  end
  labels.map.with_index { |label, index| {label: label, x: index, y: points[index]} }
end

SCHEDULER.every '30m', first_in: 0 do |_job|
  activeSprint = fetch(URI(sprintQuery))['sprints'].find { |sprint| sprint['state'].eql? 'ACTIVE' }
  burndown = fetch(URI(burndownQuery % activeSprint['id']))
  startDate = date(burndown['startTime'])
  endDate = date(burndown['endTime'])
  pointsPerDate = pointsPerDate(burndown['changes'], burndown['startTime'], burndown['endTime'])
  remainingValues = remainingValues(startDate, endDate, pointsPerDate)
  guideline = guideline(startDate, endDate, pointsPerDate)
  data = [{type: 'line', markerType: 'none', dataPoints: guideline}, {type: 'stepLine', markerType: 'none', dataPoints: remainingValues}]

  send_event('burndown', container: 'burndownChart', data: data, title: 'Burndown Chart')
end
