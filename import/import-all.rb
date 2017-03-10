Dir['data/*'].sort.each do |d|
  next if !Dir.exist?(d)
  puts "Importing #{d}"
  system("docker-compose -f docker-compose.yml -f docker-utils.yml run -d mysql-runner /root/import.rb \"#{d}\"")
  sleep 5
  id = `docker ps -l -q`.strip
  puts "Container ID: #{id}"
  system("docker logs -f #{id}")
  puts "Finished #{d}"
end
