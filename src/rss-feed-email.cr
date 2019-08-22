require "rss"
require "email"
require "redis"

redis = Redis.new(url: ENV["REDIS_URL"])
LOGGER = Logger.new(STDOUT, level: Logger::ERROR)
summary = ENV["RSS_FEED_SUMMARY"]? || "Manjaro"
url = ENV["RSS_FEED_URL"]? || "https://forum.manjaro.org/c/announcements/stable-updates.rss"
password = ENV["RSS_FEED_PASSWORD"]
emto = ENV["RSS_FEED_TO"]
emfrom = ENV["RSS_FEED_FROM"]? || "rss-feed@mail.ru"
smtp = ENV["RSS_FEED_SMTP"]? || "smtp.mail.ru"
port = ENV["RSS_FEED_PORT"]? || 25

begin
  # Parse RSS feed
  feed = RSS.parse url
  e = feed.items.first
  esubject = e.title.split(" - ").first
  current_date = Time.local.to_s("%e").to_i  
  pub_date = ENV["RSS_FEED_DATE"]? || e.pubDate.split(" ").skip(1).first

  if [pub_date.to_i , pub_date.to_i].includes?(current_date)
  	unless redis.get("lock") == "true"
  	  # Create email message
	  email = EMail::Message.new
	  email.from         "#{emfrom}"
	  email.to           "#{emto}"
	  email.subject      "#{summary} #{esubject}"
	  email.message_html "#{e.pubDate}\n#{e.description}\n"

	  # Set SMTP client configuration
	  config = EMail::Client::Config.new("#{smtp}", port.to_i)
	
	  # Use TLS to send email
	  config.use_tls
		
	  # Use SMTP AUTH for user authentication.
	  config.use_auth("#{emfrom}", "#{password}")
    
	  # Set email client name.
	  config.client_name = "RssFeed"   
	      
      # Set connection timeout to 10 sec.
	  config.connect_timeout = 10 	  
	  
	  # Create SMTP client object
	  client = EMail::Client.new(config)

	  client.start do
	    send(email)
	    redis.set("lock", "true") unless redis.get("lock") == "true"
	  end
	end 
  else
    redis.set("lock", "false") if redis.get("lock") == "true"
    exit
  end
  
rescue error
  LOGGER.fatal error
end
