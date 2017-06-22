require Rails.root.join('db/migrate/limits_to_mysql')
require Rails.root.join('db/migrate/markdown_cache_limits_to_mysql')
require Rails.root.join('db/migrate/merge_request_diff_file_limits_to_mysql')

desc "GitLab | Add limits to strings in mysql database"
task add_limits_mysql: :environment do
  puts "Adding limits to schema.rb for mysql"
  LimitsToMysql.new.up
  MarkdownCacheLimitsToMysql.new.up
  MergeRequestDiffFileLimitsToMysql.new.up
end
