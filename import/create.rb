require 'mysql2'
require 'json'
require 'pp'
require 'date'
require 'set'
require 'enumerator'

client = Mysql2::Client.new(
  host: 'mysql',
  username: 'root',
  password: 'scry',
  encoding: 'utf8mb4',
  flags: Mysql2::Client::MULTI_STATEMENTS | Mysql2::Client::TRANSACTIONS
)

def run_multi(query)
  result = client.query(create)
  while client.next_result
    result = client.store_result
  end
end

drop = <<SQL
  DROP DATABASE IF EXISTS scry;
  CREATE DATABASE scry
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

  USE scry;
SQL

create = <<SQL
  CREATE TABLE channels (
    id BIGINT NOT NULL,
    name VARCHAR(64) NOT NULL,
    display_name VARCHAR(64) NOT NULL,
    created_at DATETIME NOT NULL,
    PRIMARY KEY (id)
  );

  CREATE TABLE games (
    id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(512) NOT NULL,
    PRIMARY KEY (id)
  );

  ALTER TABLE games ADD UNIQUE (name);

  CREATE TABLE streams (
    id BIGINT NOT NULL AUTO_INCREMENT,
    channel_id BIGINT NOT NULL,
    created_at DATETIME,
    PRIMARY KEY (id)
  );

  ALTER TABLE streams
    ADD CONSTRAINT fk_streams_channel_id
    FOREIGN KEY (channel_id)
    REFERENCES channels(id);

  CREATE TABLE stream_samples (
    stream_id BIGINT NOT NULL,
    timestamp INT NOT NULL,
    game_id INT NOT NULL,
    viewers INT NOT NULL,
    status VARCHAR(512) NOT NULL,
    playlist BOOLEAN NOT NULL,
    PRIMARY KEY (stream_id, timestamp)
  );

  ALTER TABLE stream_samples
    ADD CONSTRAINT fk_stream_samples_stream_id
    FOREIGN KEY (stream_id)
    REFERENCES streams(id);

  ALTER TABLE stream_samples
    ADD CONSTRAINT fk_stream_samples_game_id
    FOREIGN KEY (game_id)
    REFERENCES games(id);

  CREATE TABLE channel_samples (
    channel_id BIGINT NOT NULL,
    timestamp INT NOT NULL,
    followers INT NOT NULL,
    views INT NOT NULL,
    partner BOOLEAN NOT NULL,
    language VARCHAR(8) NOT NULL,
    mature BOOLEAN NOT NULL,
    PRIMARY KEY (channel_id, timestamp)
  );

  ALTER TABLE channel_samples
    ADD CONSTRAINT fk_channel_samples_channel_id
    FOREIGN KEY (channel_id)
    REFERENCES channels(id);

  CREATE TABLE featured_samples (
    stream_id BIGINT NOT NULL,
    timestamp INT NOT NULL,
    title VARCHAR(256) NOT NULL,
    text VARCHAR(2048) NOT NULL,
    priority INT NOT NULL,
    sponsored BOOLEAN NOT NULL,
    PRIMARY KEY (stream_id, timestamp)
  );

  ALTER TABLE featured_samples
    ADD CONSTRAINT fk_featured_samples_stream_id
    FOREIGN KEY (stream_id)
    REFERENCES streams(id);
SQL

run_multi(drop)
run_multi(create)
