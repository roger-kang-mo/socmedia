require 'mechanize'
require 'open-uri'
require 'pry'

class SocialMediaScraper
  PROTOCOL = "http://"
  PROTOCOL_MATCH = /http(s)?:\/\//
  # NETWORK_NAMES = ["facebook", "gplus", "instagram", "twitter", "linkedin", "pinterest"]
  NETWORK_NAMES = ["facebook", "gplus", "instagram", "twitter", "pinterest"]

  FB_MATCH = /facebook.com/
  TWITTER_MATCH = /twitter.com/
  GPLUS_MATCH = /plus.google.com/
  PINTEREST_MATCH = /pinterest.com/
  IG_MATCH = /instagram.com/
  IG_TOKEN = "1151756832.1fb234f.376e4a229e334a90bbf5cbf60fb1e6a5"
  GPLUS_API_MATCH = /apis.google.com/

  def initialize
    @urls = []
    list = File.open("contacts.txt", "r")
    list.each_line do |line|
      @urls << line.strip if line
    end

    process_list
  end

  def process_list
    limit = 5
    @mechanize = Mechanize.new { |agent|
      agent.user_agent_alias = 'Mac Safari'
    }

    data = {}
    current = 0
    @urls.each do |url|
      data[url] = process_url(url)
      current += 1

      if current == limit
        break
      end
    end

    p data
  end

  def process_url(url)
    page_name = url[0...url.index('.')] #not perfect
    network_data = []

    # begin
    p "============================================"
    p "DATA FOR #{url}"
      @mechanize.get("#{PROTOCOL}#{url}") do |page|
        
        network_data = {}

        NETWORK_NAMES.each do |network|
          data = self.send("get_#{network}", page, page_name)
          network_data[network.to_sym] = data
          p "#{network}: #{data}"
        end
      end
    p "============================================"
    # rescue Exception => e
      # data = e
    # end

    network_data
  end

  def get_facebook(page, page_name)
    likes = nil

    links = page.links_with(:href => FB_MATCH).map { |link| link.href }

    graph_links = links.map { |link| link.gsub(/.+facebook.com\/pages\//, "") }.reject { |link| link.empty? }.uniq

    graph_links.each do |link|
      begin
        data = open("http://graph.facebook.com/?ids=#{link}").read
        data_likes = JSON.parse(data)[page_name]["likes"]
        likes ||= data_likes if data_likes
      rescue OpenURI::HTTPError => e
      end
    end

    unless likes
      
    end

    likes
  end

  def get_gplus(page, page_name)
    pluses = nil
    links = page.links_with(:href => GPLUS_MATCH).map { |link| link.href }.uniq

    links.each do |link|
      link = add_protocol(link)
      @mechanize.get(link) do |gplus_page|
        plus_text = gplus_page.search(".o5a").first.text.gsub(/[a-zA-Z]+/, '').strip
        pluses ||= plus_text if plus_text
      end
    end

    unless pluses

    end

    pluses
  end

  def get_twitter(page, page_name)
    followers = nil
    links = page.links_with(:href => TWITTER_MATCH)
    links = links.map { |link| link.href.gsub(/https:\/\/|http:\/\//, '') }.uniq
    links.reject! { |link| link.match(/twitter.com\/share/) }

    links.each do |link|
      link = add_protocol(link)
      @mechanize.get(link) do |twitter_page|
        stats_items = twitter_page.search('.js-mini-profile-stat')
        if stats_items && stats_items.any?
          follower_text = stats_items.last.text
          followers = follower_text if follower_text.match(/^[0-9]+(K)?$/)
        end
      end
    end

    followers
  end

  def get_instagram(page, page_name)
    followed_by = nil

    links = page.links_with(:href => IG_MATCH).map { |link| link.href }
    links = links.map { |link| link.gsub(/https:\/\/|http:\/\//, '') }.uniq
    possible_names = links.map { |link| link.gsub(IG_MATCH, '').gsub(/\//, '')}.uniq

    possible_names << page_name

    possible_names.each do |name|
      begin
        data = open("https://api.instagram.com/v1/users/search?q=#{name}&access_token=#{IG_TOKEN}").read

        user_id = JSON.parse(data)["data"].first['id']

        user_data = open("https://api.instagram.com/v1/users/#{user_id}?access_token=#{IG_TOKEN}").read
        followed_by_data = JSON.parse(user_data)["data"]["counts"]["followed_by"]
        
        if followed_by_data
          followed_by = followed_by_data
          break
        end
      rescue Exception => e
        followed_by = "Error"
      end
    end
    followed_by
  end

  def get_linkedin(page, page_name)
    data = open("http://www.linkedin.com/countserv/count/share?url=#{page_name}").read
  end

  def get_pinterest(page, page_name)
    likes = nil
    links = page.links_with(:href => /pinterest.com\//).map { |link| link.href }
    links = links.reject { |link| link.match(/pinterest.com\/pin\//) }
    links = links.map { |link| link.gsub(/https:\/\/|http:\/\//, '') }.uniq

    links.each do |link|
      link = add_protocol(link)
      @mechanize.get(link) do |pinterest_page|
        user_stat = pinterest_page.search('.userStats').first.children[4]

        likes = user_stat.text.gsub(/[a-zA-Z]+/, '').strip #likes

        follower_stat = pinterest_page.search('.followersFollowingLinks').first
        followers = follower_stat.search('.FollowerCount').text
        followers = followers.gsub(/[a-zA-Z]+/, '').strip #followers
      end
    end
    likes
  end

  def add_protocol(link)
    link.match(PROTOCOL_MATCH) ? link : "#{PROTOCOL}#{link}"
  end
end

soc = SocialMediaScraper.new
