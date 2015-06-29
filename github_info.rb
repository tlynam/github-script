#https://gist.github.com/seuros/75aca71d7a5a378fcdb5
require 'httparty'
require 'geocoder'
require 'uri'
require 'cgi'
require 'json'

class GithubInfo
  def initialize
    @github_username = ARGV[0]
  end

  def output
    json = {
      github_username: @github_username,
      github_id: basic_data[:github_id],
      followers_count: basic_data[:followers_count],
      email: basic_data[:email],
      location: {
        name: basic_data[:location],
        long: long_lat[:long],
        lat: long_lat[:lat]
      },
      hireable: basic_data[:hireable],
      public_languages: public_languages,
      public_orgs: public_orgs
    }
    puts JSON.pretty_generate(json)
  end

  private

  def basic_data
    @basic_data ||= begin
      response = HTTParty.get("https://api.github.com/users/#{@github_username}").to_hash
      basic_data = {}
      basic_data[:github_id] = response['id']
      basic_data[:followers_count] = response['followers']
      basic_data[:email] = response['email']
      basic_data[:location] = response['location']
      basic_data[:hireable] = response['hireable']
      basic_data[:organizations_url] = response['organizations_url']
      basic_data[:repos_url] = response['repos_url']
      basic_data
    end
  end

  def long_lat
    @long_lat ||= begin
      lat, long = Geocoder.coordinates(basic_data[:location])
      {
        long: long,
        lat: lat
      }
    end
  end

  def public_languages
    @public_languages ||= begin
      repos = HTTParty.get(basic_data[:repos_url]).to_a
      org_groups = repos.group_by { |repo| repo['language'] }
      sorted_groups = org_groups.sort_by { |_, projects| projects.size }.reverse
      sorted_groups.map { |lang| lang[0] }.compact
    end
  end

  def public_orgs
    @public_orgs ||= begin
      public_orgs = []
      organizations = HTTParty.get(basic_data[:organizations_url]).to_a
      organizations.each do |org|
        url = HTTParty.get(org['url'])['html_url']
        uri = URI.parse(org['avatar_url'])
        avatar_url = URI::HTTPS.build(host: uri.host, path: uri.path).to_s
        params = CGI.parse(uri.query)

        public_orgs << {
          github_username: org['login'],
          github_id: org['id'],
          url: url,
          avatar_url: avatar_url,
          avatar_version: Integer(params['v'].first)
        }
      end
      public_orgs
    end
  end
end

github_info = GithubInfo.new
github_info.output

