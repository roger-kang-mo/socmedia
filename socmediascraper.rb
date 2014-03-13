require 'mechanize'
require 'open-uri'
require 'pry'

class SocialMediaScraper
  PROTOCOL = "http://"
  PROTOCOL_MATCH = /http(s)?:\/\//
  # NETWORK_NAMES = ["facebook", "gplus", "instagram", "twitter", "linkedin", "pinterest"]
  NETWORK_NAMES = ["facebook", "gplus", "instagram", "twitter", "pinterest"]

  COLUMN_HEADERS = "website| facebook_links| facebook_likes| gplus_links| gplus_pluses| instagram_links| instagram_followers| twitter_links| twitter_followers| pinterest_links| pinterest_followers\n"
  ERRORED_SITE_CONTENTS = "[]|[]|[]|[]|[]|[]|[]|[]|[]|[]|[]"

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
    @mechanize = Mechanize.new { |agent|
      agent.user_agent_alias = 'Mac Safari'
    }

    data = {}

    File.open('out.txt', 'w') do |file_obj|
      @file = file_obj
      # @file.write(COLUMN_HEADERS)
      @urls.each do |url|
        data[url] = process_url(url)
      end
    end
  end

  def process_url(url)
    page_name = url[0...url.index('.')] #not perfect
    network_data = []
    to_write = url

    p "============================================"
    p "DATA FOR #{url}"
    # @file.write(url)
    begin
      @mechanize.get(add_protocol(url)) do |page|
        
        network_data = {}

        NETWORK_NAMES.each do |network|
          links, data = self.send("get_#{network}", page, page_name)
          network_data[network.to_sym] = data
          p "#{network}: #{data}"
          # @file.write(", #{links}, #{data}")
          to_write << "| #{links}| #{data}"
        end
      end
      p "============================================"
      @file.write("#{to_write}\n")
    rescue Exception => e
      @file.write("#{url} - errored| #{ERRORED_SITE_CONTENTS}\n")
    end


    network_data
  end

  def get_facebook(page, page_name)
    likes = []

    links = page.links_with(:href => FB_MATCH).map { |link| link.href.downcase }
    
    links = links.reject { |link| link.match(/facebook.com\/sharer.php/) }
    links = prefer_page_name(links, page_name)
    links = sanitize_links(links)
    graph_links = links.map { |link| link.gsub(/.+(facebook.com\/pages\/|facebook.com\/)/, "") }.reject { |link| link.empty? }.uniq
    graph_links.map! { |link| link.index("/") ? link[0...link.index("/")] : link }

    graph_links.each do |link|
      begin
        data = open("http://graph.facebook.com/?ids=#{link}").read
        parsed_data = JSON.parse(data)
        if parsed_data.any? && parsed_data[link]
          data_likes = parsed_data[link]["likes"] 
          likes << data_likes if data_likes
        end
      rescue OpenURI::HTTPError => e
        puts e
      end
    end

    [links, likes.uniq]
  end

  def get_gplus(page, page_name)
    pluses = []
    links = page.links_with(:href => GPLUS_MATCH).map { |link| link.href.downcase }.uniq

    links.each do |link|
      link = add_protocol(link)
      begin
        @mechanize.get(link) do |gplus_page|
          plus_text = gplus_page.search(".o5a").first
          plus_text = plus_text.text.gsub(/[a-zA-Z]+/, '').strip if plus_text
          pluses << plus_text if plus_text
        end
      rescue Exception => e
        puts e
      end
    end

    [links, pluses.uniq]
  end

  def get_twitter(page, page_name)
    followers = []
    links = page.links_with(:href => TWITTER_MATCH)
    links = links.map { |link| link.href.downcase.gsub(/https:\/\/|http:\/\//, '') }.uniq
    links = links.reject { |link| link.match(/twitter.com\/(share|intent|search)/) }
    links = links.reject { |link| link.match(/twitter.com\/.+\/statuses/) }
    links = sanitize_links(links)

    links.each do |link|
      link = add_protocol(link)
      begin
        @mechanize.get(link) do |twitter_page|
          stats_items = twitter_page.search('.js-mini-profile-stat')
          if stats_items && stats_items.any?
            follower_text = stats_items.last.text.gsub(',', '')
            followers << follower_text if follower_text.match(/^[0-9]+(K)?$/)
            break;
          end
        end
      rescue Exception => e
        puts e
      end
    end

    [links, followers.uniq]
  end

  def get_instagram(page, page_name)
    followed_by = []

    links = page.links_with(:href => IG_MATCH).map { |link| link.href }
    links = links.map { |link| link.gsub(/https:\/\/|http:\/\//, '') }.uniq
    links = sanitize_links(links)
    possible_names = links.map { |link| link.gsub(IG_MATCH, '').gsub(/\//, '')}.uniq


    possible_names << page_name

    possible_names.each do |name|
      begin
        data = open("https://api.instagram.com/v1/users/search?q=#{name}&access_token=#{IG_TOKEN}").read
        parsed_data = JSON.parse(data)["data"]
        if parsed_data.any?
          user_id = parsed_data.first['id']

          user_data = open("https://api.instagram.com/v1/users/#{user_id}?access_token=#{IG_TOKEN}").read
          followed_by_data = JSON.parse(user_data)["data"]["counts"]["followed_by"]
          
          if followed_by_data
            followed_by << followed_by_data
            break
          end
        end
      rescue Exception => e
        puts e
      end
    end
    [links, followed_by.uniq]
  end

  def get_linkedin(page, page_name)
    data = open("http://www.linkedin.com/countserv/count/share?url=#{page_name}").read
  end

  def get_pinterest(page, page_name)
    likes = []
    followers = []
    links = page.links_with(:href => /pinterest.com\//).map { |link| link.href }
    links = links.reject { |link| link.match(/(pinterest.com\/pin\/|javascript)/) }
    links = sanitize_links(links)
    links = links.map { |link| link.gsub(/https:\/\/|http:\/\//, '') }.uniq

    links = prefer_page_name(links, page_name)

    links.each do |link|
      link = add_protocol(link)
      begin
        @mechanize.get(link) do |pinterest_page|
          user_stat = pinterest_page.search('.userStats').first
          if user_stat
            user_stat = user_stat.children[4] 

            likes_text = user_stat.text
            likes << likes_text.gsub(/[a-zA-Z\n]+/, '').strip if likes_text #likes

            follower_stat = pinterest_page.search('.followersFollowingLinks').first
            followers_text = follower_stat.search('.FollowerCount').text
            followers << followers_text.gsub(/[a-zA-Z\n]+/, '').strip if followers_text #followers
          end
        end
      rescue Exception => e
        puts e
      end
    end

    [links, followers.uniq]
  end

  def prefer_page_name(links, page_name)
    links.each_with_index do |link, index|
      if link.include? page_name
        links.unshift(link).uniq unless index == 0
        break
      end
    end

    links
  end

  def sanitize_links(links)
    links.map { |link| link.gsub(/\r\n|\r|\n/, '') }
  end

  def add_protocol(link)
    link.match(PROTOCOL_MATCH) ? link : "#{PROTOCOL}#{link}"
  end
end

soc = SocialMediaScraper.new
