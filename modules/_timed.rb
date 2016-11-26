require 'json'
require 'time'
require 'date'

DATE_FORMAT = '%Y-%m-%d'.freeze
TIME_FORMAT = '%I:%M %p'.freeze

$sd = JSON.parse(File.read('./resources/schedule_days.json'))

def summer?
  now = Date.parse(Time.now.to_s)
  today = now.strftime(DATE_FORMAT)

  # Before, or during school year?
  return today < $sd.keys.sort.first
end

def school_day?
  now = Time.now
  now_str = now.strftime(DATE_FORMAT)

  return false if $sd[now_str].nil?
  return true
end

def get_sd
  now = Time.now
  now_str = now.strftime(DATE_FORMAT)
  $sd[now_str]
end

def during_school?
  now = Time.now
  now_str = now.strftime(DATE_FORMAT)
  return false if $sd[now_str].nil?

  # Check if during school hours
  start_time = Time.strptime('08:40 AM', TIME_FORMAT)
  end_time = Time.strptime('02:50 PM', TIME_FORMAT)

  return true if now >= start_time and now <= end_time
  return false
end
