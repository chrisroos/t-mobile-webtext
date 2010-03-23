#!/usr/bin/env ruby

require 'rubygems'
require 'hpricot'
require 'cgi'


# Arguments
unless ARGV.length == 4
  puts "Usage: t-mobile-webtext.rb username password recipient message"
  exit 1
end
USERNAME, PASSWORD, RECIPIENT, message = ARGV
MESSAGE = CGI.escape(message)


# Constants
COOKIE_JAR = File.join(File.dirname(__FILE__), 't-mobile-cookies')


# Methods
def quoted_value(value)
  "\"#{value}\"" if value
end

def curl_arg(key, value)
  prefix, separator = (key.length == 1) ? ['-', ''] : ['--', ' ']
  ["#{prefix}#{key}", quoted_value(value)].join(separator)
end

def curl(url, options)
  options << ['silent', nil]
  curl_args = options.collect { |(key, value)| curl_arg(key, value) }.join(' ')
  cmd = %%curl "#{url}" #{curl_args}%
  # puts cmd
  `#{cmd}`
end

def save_html(filename, html)
  File.open(filename, 'w') { |f| f.puts(html) }
end


# Get the login page, store the cookie and extract the token from the login form
html = curl('https://www.t-mobile.co.uk/service/your-account/login/', [
  ['cookie-jar' => COOKIE_JAR]
])
doc = Hpricot(html)
token_element = doc.at("input[@name='org.apache.struts.taglib.html.TOKEN']")
token_value = token_element.attributes['value']


# Login and store the cookies
html = curl('https://www.t-mobile.co.uk/service/your-account/login/', [
  ['d',          'submit=Log+in'],
  ['d',          "username=#{USERNAME}"],
  ['d',          "password=#{PASSWORD}"],
  ['d',          "org.apache.struts.taglib.html.TOKEN=#{token_value}"],
  ['cookie',     COOKIE_JAR],
  ['cookie-jar', COOKIE_JAR],
  ['L',          nil]
])


# Get the send-message page and extract the token from the send-message form
html = curl('https://www.t-mobile.co.uk/service/your-account/private/wgt/send-text-preparing/', [
  ['cookie', COOKIE_JAR]
])
doc = Hpricot(html)
token_element = doc.at("input[@name='org.apache.struts.taglib.html.TOKEN']")
token_value = token_element.attributes['value']


# Send a message
html = curl('https://www.t-mobile.co.uk/service/your-account/private/wgt/send-text-processing/', [
  ['d',      "org.apache.struts.taglib.html.TOKEN=#{token_value}"],
  ['d',      "selectedRecipients=#{RECIPIENT}"],
  ['d',      "message=#{MESSAGE}"],
  ['d',      "submit=Send"],
  ['cookie', COOKIE_JAR],
  ['L',      nil]
])
# save_html 't-mobile-text-sent.html', html

if html =~ /The message has been sent successfully!/
  puts 'SUCCESS!'
else
  # Get the confirmation page (the previous thingy uses an http refresh to redirect this page if we don't have confirmation that the message was sent)
  html = curl('https://www.t-mobile.co.uk/service/your-account/private/wgt/sent-confirmation/', [
    ['cookie', COOKIE_JAR]
  ])
  # save_html 'wem.html', html
  if html =~ /The message has been sent successfully!/
    puts "SUCCESS"
  else
    puts "FAILED"
  end
end