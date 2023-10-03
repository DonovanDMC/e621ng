# frozen_string_literal: true

require "digest/md5"
require "net/http"
require "tempfile"

# Uncomment to see detailed logs
# ActiveRecord::Base.logger = ActiveSupport::Logger.new($stdout)


def create_user(name, level, created_at = nil)
  user = User.find_or_initialize_by(name: name) do |usr|
    usr.created_at = created_at unless created_at.nil?
    usr.password = name
    usr.password_confirmation = name
    usr.password_hash = ""
    usr.email = "#{name}@e621.local"
    usr.level = level
    yield(usr) if block_given?
  end
  user.save(validate: false) if user.new_record?


  ApiKey.create(user_id: user.id, key: name)

  user
end

def apply_flags(user)
  user.can_upload_free = true
  user.can_approve_posts = true
end

admin = create_user("admin", User::Levels::ADMIN, 2.weeks.ago) { |user| apply_flags(user) }
create_user("admin_new", User::Levels::ADMIN) { |user| apply_flags(user) }
create_user("bd_admin", User::Levels::ADMIN, 2.weeks.ago) { |user| apply_flags(user); user.is_bd_staff = true }
create_user("bd_admin_new", User::Levels::ADMIN) { |user| apply_flags(user); user.is_bd_staff = true }
create_user(Danbooru.config.system_user, User::Levels::JANITOR, 2.weeks.ago) { |user| apply_flags(user) }
create_user("moderator", User::Levels::MODERATOR)
create_user("moderator_old", User::Levels::MODERATOR, 2.weeks.ago)
create_user("janitor", User::Levels::JANITOR) { |user| apply_flags(user) }
create_user("janitor_old", User::Levels::JANITOR, 2.weeks.ago) { |user| apply_flags(user) }
create_user("former_staff", User::Levels::FORMER_STAFF)
create_user("former_staff_old", User::Levels::FORMER_STAFF, 2.weeks.ago)
create_user("contributor", User::Levels::CONTRIBUTOR)
create_user("contributor_old", User::Levels::CONTRIBUTOR, 2.weeks.ago)
create_user("privileged", User::Levels::PRIVILEGED)
create_user("privileged_old", User::Levels::PRIVILEGED, 2.weeks.ago)
create_user("member", User::Levels::MEMBER)
create_user("member_old", User::Levels::MEMBER, 2.weeks.ago)
create_user("blocked", User::Levels::BLOCKED)
create_user("blocked_old", User::Levels::BLOCKED, 2.weeks.ago)
create_user("anonymous", User::Levels::ANONYMOUS)
create_user("anonymous_old", User::Levels::ANONYMOUS, 2.weeks.ago)

ForumCategory.find_or_create_by!(name: "Tag Alias and Implication Suggestions") do |category|
  category.can_view = 0
end

def api_request(path)
  puts "GET https://e621.net#{path}";
  response = HTTParty.get("https://e621.net#{path}", {
    headers: { "User-Agent" => "e621ng/seeding" },
  })
  JSON.parse(response.body)
end

def import_posts
  ENV["DANBOORU_DISABLE_THROTTLES"] = "1"
  resources = YAML.load_file Rails.root.join("db/seeds.yml")
  if resources['tags']&.include?('order:random')
    resources['tags'] << "randseed:#{Digest::MD5.hexdigest(Time.now.to_s)}"
  end
  search_tags = resources['post_ids'].nil? || resources['post_ids'].empty? ? resources['tags'] : ["id:#{resources['post_ids'].join(',')}"]
  json = api_request("/posts.json?limit=#{ENV.fetch('SEED_POST_COUNT', 100)}&tags=#{search_tags.join('%20')}")
  json["posts"].each do |post|

    post["tags"].each do |category, tags|
      Tag.find_or_create_by_name_list(tags.map { |tag| "#{category}:#{tag}" })
    end

    url = post["file"]["url"]
    url = "https://static1.e621.net/data/#{post['file']['md5'][0..1]}/#{post['file']['md5'][2..3]}/#{post['file']['md5']}.#{post['file']['ext']}" if url.nil?
    puts url

    post["sources"] << "https://e621.net/posts/#{post['id']}"
    service = UploadService.new({
      uploader: CurrentUser.user,
      uploader_ip_addr: CurrentUser.ip_addr,
      direct_url: url,
      tag_string: post["tags"].values.flatten.join(" "),
      source: post["sources"].join("\n"),
      description: post["description"],
      rating: post["rating"],
    })
    service.start!
  end
end

def import_mascots
  api_request("/mascots.json").each do |mascot|
    puts mascot["url_path"]
    Mascot.create!(
      creator: CurrentUser.user,
      mascot_file: Downloads::File.new(mascot["url_path"]).download!,
      display_name: mascot["display_name"],
      background_color: mascot["background_color"],
      artist_url: mascot["artist_url"],
      artist_name: mascot["artist_name"],
      available_on_string: Danbooru.config.app_name,
      active: mascot["active"],
      )
  end
end

unless Rails.env.test?
  CurrentUser.user = admin
  CurrentUser.ip_addr = "127.0.0.1"
  import_posts
  import_mascots
end
