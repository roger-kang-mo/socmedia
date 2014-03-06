require 'mechanize'
require 'open-uri'
require 'pry'

class SocialMediaScraper
  PROTOCOL = "http://"
  PROTOCOL_MATCH = /http(s)?:\/\//
  NETWORK_NAMES = ["facebook", "gplus", "instagram", "twitter", "linkedin"]

  URLS = ["simplelivingmama.com", "theebookreport.com"]

  FB_MATCH = /facebook.com/
  TWITTER_MATCH = /twitter.com/
  GPLUS_MATCH = /plus.google.com/
  PINTEREST_MATCH = /pinterest.com/
  IG_MATCH = /instagram.com/
  IG_TOKEN = "1151756832.1fb234f.376e4a229e334a90bbf5cbf60fb1e6a5"

  def initialize
    process_list
  end

  def process_list
    @mechanize = Mechanize.new { |agent|
      agent.user_agent_alias = 'Mac Safari'
    }

    data = {}

    URLS.each do |url|
      data[url] = process_url(url)
    end

    p data
  end

  def process_url(url)
    page_name = url[0...url.index('.')] #not perfect
    network_data = []

    # begin
      @mechanize.get("#{PROTOCOL}#{url}") do |page|
        
        network_data = {}

        NETWORK_NAMES.each do |network|
          data = self.send("get_#{network}", page, page_name)
          network_data[network.to_sym] = data
        end
      end
    # rescue Exception => e
      # data = e
    # end

    network_data
  end

  def get_facebook(page, page_name)
    likes = nil

    links = page.links_with(:href => FB_MATCH).map { |link| link.href }

    links = links.map { |link| link.gsub(/.+facebook.com\//, "") }.reject { |link| link.empty? }.uniq

    links.each do |link|
      data = open("http://graph.facebook.com/?ids=#{page_name}").read
      data_likes = JSON.parse(data)[page_name]["likes"]
      likes ||= data_likes if data_likes
    end

    likes
  end

  def get_gplus(page, page_name)
    pluses = nil
    links = page.links_with(:href => GPLUS_MATCH).map { |link| link.href }.uniq

    links.each do |link|
      link = link.match(PROTOCOL_MATCH) ? link : "#{PROTOCOL}#{link}"
      @mechanize.get(link) do |gplus_page|
        plus_text = gplus_page.search(".o5a").first.text.gsub(/[a-zA-Z]+/, '').strip
        pluses ||= plus_text if plus_text
      end
    end

    pluses
  end

  def get_twitter(page, page_name)
    followers = nil
    links = page.links_with(:href => TWITTER_MATCH)
    links = links.map { |link| link.href.gsub(/https:\/\/|http:\/\//, '') }.uniq

    links.each do |link|
      link = link.match(PROTOCOL_MATCH) ? link : "#{PROTOCOL}#{link}"
      @mechanize.get(link) do |twitter_page|
        follower_text = twitter_page.search('.js-mini-profile-stat').last.text
        followers ||= follower_text if follower_text.match(/^[0-9]+(K)?$/)
      end
    end

    followers
  end

  def get_instagram(page, page_name)
    followed_by = nil

    begin
      data = open("https://api.instagram.com/v1/users/search?q=#{page_name}&access_token=#{IG_TOKEN}").read
      user_id = JSON.parse(data)["data"].first['id']

      user_data = open("https://api.instagram.com/v1/users/#{user_id}?access_token=#{IG_TOKEN}").read
      followed_by = JSON.parse(user_data)["data"]["counts"]["followed_by"]
    rescue Exception => e
      followed_by = e
    end
    followed_by
  end

  def get_linkedin(page, page_name)
    data = open("http://www.linkedin.com/countserv/count/share?url=#{page_name}").read
  end

  def get_pinterest(page, page_name)
    likes = nil
    links = page.links_with(:href => /pinterest.com\//).map { |link| link.href }
    links = links.reject { |link| link.match(/pinterest.com\/pint\//)}.uniq

    user_stat = page.search('.userStats').first.children[4]

    user_stat.text.gsub(/[a-zA-Z]+/, '').strip
    likes
  end
end

soc = SocialMediaScraper.new