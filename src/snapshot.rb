require 'json'
require 'timeout'
require 'uri'
require 'open-uri'

def paginate(url)
  offset = 0
  uri = URI.parse(url)
  loop do
    uri.query = {
      'limit': 100,
      'offset': offset
    }.map { |k, v| "#{URI.encode(k.to_s)}=#{URI.encode(v.to_s)}" }.join('&')

    yield uri.to_s

    offset += 80
  end
end

def attempt(count:, error:)
  begin
    yield
  rescue => e
    $stderr.puts "#{error}\nError: #{e}"

    count -= 1
    if count == 0
      $stderr.puts 'Not retrying, abort.'
      exit 1
    end

    sleep 5
    retry
  end
end

def download(client_id, source_url)
  paginate(source_url) do |url|
    attempt(count: 10, error: "Failed to download #{url}.") do
      Timeout::timeout(5) do
        headers = {
          'Accept' => 'application/vnd.twitchtv.v3+json',
          'Client-ID' => client_id
        }

        $stderr.puts "Download #{url}."
        open(url, headers) do |f|
          resp = JSON.parse(f.read)
          raise 'Error in response.' if !resp['error'].nil?
          return if !(yield resp)
        end
      end
    end 
  end
end

def normalize(stream)
  ['_links', 'preview', 'delay'].each do |attr|
    stream.delete(attr)
  end

  channel = stream['channel']
  ['_links', 'logo', 'video_banner', 'profile_banner', 'banner', 'background', 'game', 'profile_banner_background_color', 'delay', 'url'].each do |attr|
    channel.delete(attr)
  end
end

def streams(client_id)
  all = {}

  download(client_id, 'https://api.twitch.tv/kraken/streams') do |resp|
    streams = resp['streams']
    has_streams = !streams.nil? && !streams.empty?

    if has_streams
      timestamp = Time.now.to_i
      streams.each do |stream|
        normalize(stream)
        stream['at'] = timestamp
        all[stream['_id']] = stream
      end
    end

    has_streams
  end

  all.values
end

def featured(client_id)
  all = {}

  download(client_id, 'https://api.twitch.tv/kraken/streams/featured') do |resp|
    featured = resp['featured']
    has_featured = !featured.nil? && !featured.empty?

    if has_featured
      timestamp = Time.now.to_i
      featured.each do |featured|
        stream = featured['stream']
        normalize(stream)
        featured.delete('_links')
        featured.delete('image')
        featured['at'] = timestamp
        all[stream['_id']] = featured
      end
    end

    has_featured
  end

  all.values
end

def snapshot(client_id)
  {
    'streams' => streams(client_id),
    'featured' => featured(client_id)
  }
end

client_id = ARGV[0]
if !client_id
  $stderr.puts 'Client ID not specified, abort.'
  exit 1
end

puts JSON.dump(snapshot(client_id))
