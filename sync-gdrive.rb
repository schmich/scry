# Download rclone: https://rclone.org/downloads/
# Configure for Google Drive: see https://rclone.org/drive/
# Create remote for Google Drive called gdrive.

def confirm(prompt)
  print "#{prompt} "
  yes = gets.downcase.strip[0] == 'y'
  puts 'Skipping.' if !yes
  yes
end

remote = 'gdrive'
local = 'D:\\'

remotes = `rclone listremotes`.lines.map(&:strip)
if !remotes.include?("#{remote}:")
  puts "No #{remote} remote found."
  exit 1
end

if confirm('Deduplicate files in /Scry?')
  puts 'Deduplicating files.'
  system("rclone dedupe -vv #{remote}:Scry")
end

if confirm("Copy /Scry to #{local}?")
  puts 'Copying.'
  Dir.chdir(local) do
    system("rclone copy -vv #{remote}:Scry /")
  end
end
