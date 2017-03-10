require 'mysql2'
require 'oj'
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

puts 'Connected.'

def timer(what)
  start = Time.now
  print "#{what}..."
  begin
    yield
  ensure
    elapsed = Time.now - start
    puts "#{elapsed.round(2)}s"
  end
end

def parse_file(file, game_ids, channels, channel_samples, streams, stream_samples, featured_samples, channel_ids, stream_ids)
  create_game = $client.prepare('INSERT INTO games (name) VALUES (?) ON DUPLICATE KEY UPDATE id=LAST_INSERT_ID(id)')

  content = `xz -c -d "#{file}"`
  obj = Oj.load(content, mode: :compat, time_format: :ruby)
  featured = obj['featured'] || []

  obj['streams'].each do |stream|
    channel_id = stream['channel']['_id']
    if channel_ids.add(channel_id)
      channels << {
        id: channel_id,
        name: stream['channel']['name'] || '',
        display_name: stream['channel']['display_name'] || '',
        created_at: DateTime.parse(stream['channel']['created_at']).to_time
      }
    end

    stream_id = stream['_id']
    if stream_ids.add(stream_id)
      streams << {
        id: stream_id,
        channel_id: channel_id,
        created_at: DateTime.parse(stream['created_at']).to_time
      }
    end

    game_name = stream['game'] || ''
    game_id = game_ids[game_name]
    if game_id.nil?
      create_game.execute(game_name)
      game_id = $client.last_id
      game_ids[game_name] = game_id
    end

    stream_samples << {
      stream_id: stream_id,
      timestamp: stream['at'],
      game_id: game_id,
      viewers: stream['viewers'],
      status: stream['channel']['status'] || '',
      playlist: (stream['is_playlist'] || false) ? 1 : 0
    }

    channel_samples << {
      channel_id: channel_id,
      timestamp: stream['at'],
      followers: stream['channel']['followers'] || 0,
      views: stream['channel']['views'] || 0,
      partner: (stream['channel']['partner'] || false) ? 1 : 0,
      language: stream['channel']['language'] || '',
      mature: (stream['channel']['mature'] || false) ? 1 : 0
    }
  end

  featured.each do |feature|
    featured_samples << {
      stream_id: feature['stream']['_id'],
      timestamp: feature['at'], 
      title: feature['title'] || '',
      text: feature['text'] || '',
      priority: feature['priority'],
      sponsored: (feature['sponsored'] || false) ? 1 : 0
    }
  end
end

def insert_records(channels, channel_samples, streams, stream_samples, featured_samples)
  def e(s)
    $client.escape(s)
  end

  timer('Insert records') do
    $client.query('SET foreign_key_checks=0')
    $client.query('SET unique_checks=0')
    $client.query("SET sql_log_bin=0")
    $client.query('START TRANSACTION')

    batch = 5_000

    channels.each_slice(batch) do |rs|
      query = 'INSERT IGNORE INTO channels (id, name, display_name, created_at) VALUES '
      query += rs.map { |r|
        "(#{r[:id]},\"#{e(r[:name])}\",\"#{e(r[:display_name])}\",\"#{r[:created_at]}\")"
      }.join(',')
      $client.query(query)
    end

    channel_samples.each_slice(batch) do |rs|
      query = 'INSERT IGNORE INTO channel_samples (channel_id, timestamp, followers, views, partner, language, mature) VALUES '
      query += rs.map { |r|
        "(#{r[:channel_id]},#{r[:timestamp]},#{r[:followers]},#{r[:views]},#{r[:partner]},\"#{e(r[:language])}\",#{r[:mature]})"
      }.join(',')
      $client.query(query)
    end

    streams.each_slice(batch) do |rs|
      query = 'INSERT IGNORE INTO streams (id, channel_id, created_at) VALUES '
      query += rs.map { |r|
        "(#{r[:id]},#{r[:channel_id]},\"#{r[:created_at]}\")"
      }.join(',')
      $client.query(query)
    end

    stream_samples.each_slice(batch) do |rs|
      query = 'INSERT IGNORE INTO stream_samples (stream_id, timestamp, game_id, viewers, status, playlist) VALUES '
      query += rs.map { |r|
        "(#{r[:stream_id]},#{r[:timestamp]},#{r[:game_id]},#{r[:viewers]},\"#{e(r[:status])}\",#{r[:playlist]})"
      }.join(',')
      $client.query(query)
    end

    featured_samples.each_slice(batch) do |rs|
      query = 'INSERT IGNORE INTO featured_samples (stream_id, timestamp, title, text, priority, sponsored) VALUES '
      query += rs.map { |r|
        "(#{r[:stream_id]},#{r[:timestamp]},\"#{e(r[:title])}\",\"#{e(r[:text])}\",#{r[:priority]},#{r[:sponsored]})"
      }.join(',')
      $client.query(query)
    end

    $client.query('COMMIT')
  end
end

def import(dir, resume_from)
  $client.query("SET SESSION tx_isolation='READ-UNCOMMITTED'")

  channel_ids = Set.new
  stream_ids = Set.new
  game_ids = {}

  groups = Dir["#{dir}/*.json.xz"].sort.drop_while { |f| resume_from && (f != resume_from) }.each_slice(2)
  groups.each do |group|
    channels = []
    channel_samples = []
    streams = []
    stream_samples = []
    featured_samples = []

    group.each do |file|
      timer("Parse #{file}") do
        parse_file(file, game_ids, channels, channel_samples, streams, stream_samples, featured_samples, channel_ids, stream_ids)
      end
    end

    insert_records(channels, channel_samples, streams, stream_samples, featured_samples)
  end
end

dir = ARGV[0]
if !dir
  puts 'Specify a directory to import.'
  exit 1
end

resume_from = ARGV[1]
if !resume_from
  puts 'Import from start.'
else
  puts "Resume import from #{resume_from}."
end

base_dir = File.dirname(__FILE__)
import_dir = File.join(base_dir, dir)

import(import_dir, resume_from)
