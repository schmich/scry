require 'mysql2'
require 'json'
require 'pp'
require 'date'
require 'set'
require 'enumerator'

puts 'Connect to MySQL.'

$client = Mysql2::Client.new(
  host: 'mysql',
  username: 'root',
  password: 'scry',
  database: 'scry',
  encoding: 'utf8mb4',
  flags: Mysql2::Client::MULTI_STATEMENTS | Mysql2::Client::TRANSACTIONS
)

def e(s)
  $client.escape(s)
end

puts 'Connected.'

def timer(what)
  start = Time.now
  puts "Start: #{what}"
  begin
    yield
  ensure
    elapsed = Time.now - start
    puts "🕒  Elapsed: #{elapsed.round(2)}s"
  end
end

def process_file(channel_ids, stream_ids, file)
  create_game = $client.prepare('INSERT INTO games (name) VALUES (?) ON DUPLICATE KEY UPDATE id=LAST_INSERT_ID(id)')

  games = {}
  channel_infos = []
  stream_infos = []
  stream_sample_infos = []
  channel_sample_infos = []
  featured_sample_infos = []

  content = `xz -c -d "#{file}"`
  obj = JSON.parse(content)
  streams = obj['streams']
  featured = obj['featured'] || []

  streams.each do |stream|
    channel_id = stream['channel']['_id']
    if channel_ids.add(channel_id)
      channel_infos << {
        id: channel_id,
        name: stream['channel']['name'],
        display_name: stream['channel']['display_name'],
        created_at: DateTime.parse(stream['channel']['created_at']).to_time
      }
    end

    stream_id = stream['_id']
    if stream_ids.add(stream_id)
      stream_infos << {
        id: stream_id,
        channel_id: channel_id,
        created_at: DateTime.parse(stream['created_at']).to_time
      }
    end

    game_name = stream['game'] || ''
    game_id = games[game_name]
    if game_id.nil?
      create_game.execute(game_name)
      game_id = $client.last_id
      games[game_name] = game_id
    end

    stream_sample_infos << {
      stream_id: stream_id,
      timestamp: stream['at'],
      game_id: game_id,
      viewers: stream['viewers'],
      status: stream['channel']['status'] || '',
      playlist: stream['is_playlist'],
    }

    channel_sample_infos << {
      channel_id: channel_id,
      timestamp: stream['at'],
      followers: stream['channel']['followers'] || 0,
      views: stream['channel']['views'] || 0,
      partner: stream['channel']['partner'] || false,
      language: stream['channel']['language'] || '',
      mature: stream['channel']['mature'] || false
    }
  end

  featured.each do |feature|
    featured_sample_infos << {
      stream_id: feature['stream']['_id'],
      timestamp: feature['at'], 
      title: feature['title'],
      text: feature['text'],
      priority: feature['priority'],
      sponsored: feature['sponsored']
    }
  end

  slice_size = 10_000

  puts 'Insert channels.'
  channel_infos.each_slice(slice_size) do |g|
    query = 'INSERT IGNORE INTO channels (id, name, display_name, created_at) VALUES '
    query += g.map { |i|
      "(#{i[:id]},\"#{e(i[:name])}\",\"#{e(i[:display_name])}\",\"#{i[:created_at]}\")"
    }.join(',')
    result = $client.query(query)
  end

  puts 'Insert streams.'
  stream_infos.each_slice(slice_size) do |g|
    query = 'INSERT IGNORE INTO streams (id, channel_id, created_at) VALUES '
    query += g.map { |r|
      "(#{r[:id]},#{r[:channel_id]},\"#{r[:created_at]}\")"
    }.join(',')
    result = $client.query(query)
  end

  puts 'Insert stream_samples.'
  stream_sample_infos.each_slice(slice_size) do |g|
    query = 'INSERT IGNORE INTO stream_samples (stream_id, timestamp, game_id, viewers, status, playlist) VALUES '
    query += g.map { |r|
      "(#{r[:stream_id]},#{r[:timestamp]},#{r[:game_id]},#{r[:viewers]},\"#{e(r[:status])}\",#{r[:playlist]?1:0})"
    }.join(',')
    result = $client.query(query)
  end

  puts 'Insert channel_samples.'
  channel_sample_infos.each_slice(slice_size) do |g|
    query = 'INSERT IGNORE INTO channel_samples (channel_id, timestamp, followers, views, partner, language, mature) VALUES '
    query += g.map { |r|
      "(#{r[:channel_id]},#{r[:timestamp]},#{r[:followers]},#{r[:views]},#{r[:partner]?1:0},\"#{e(r[:language])}\",#{r[:mature]?1:0})"
    }.join(',')
    result = $client.query(query)
  end

  puts 'Insert featured_samples.'
  featured_sample_infos.each_slice(slice_size) do |g|
    query = 'INSERT IGNORE INTO featured_samples (stream_id, timestamp, title, text, priority, sponsored) VALUES '
    query += g.map { |r|
      "(#{r[:stream_id]},#{r[:timestamp]},\"#{e(r[:title])}\",\"#{e(r[:text])}\",#{r[:priority]},#{r[:sponsored]})"
    }.join(',')
    result = $client.query(query)
  end
end

dir = ARGV[0]
if !dir
  puts 'Specify a directory to import.'
  exit 1
end

resume_from = ARGV[1]
if !resume_from
  puts 'Importing from start.'
else
  puts "Resuming import from #{resume_from}."
end

process = false
base_dir = File.dirname(__FILE__)
import_dir = File.join(base_dir, dir)

channel_ids = Set.new
stream_ids = Set.new

Dir["#{import_dir}/*.json.xz"].each do |file|
  if resume_from
    process = true if file == resume_from
    next if !process
  end

  result = $client.query('SET foreign_key_checks=0')
  result = $client.query('SET unique_checks=0')
  result = $client.query('SET autocommit=0')
  result = $client.query('START TRANSACTION')
  timer("Processing #{file}") do
    process_file(channel_ids, stream_ids, file)
  end
  result = $client.query('COMMIT')
end
