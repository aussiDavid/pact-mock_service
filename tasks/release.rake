RELEASE_NOTES_TEMPLATE_PATH = "packaging/RELEASE_NOTES.md.template"
RELEASE_NOTES_PATH = "build/RELEASE_NOTES.md"

require 'conventional_changelog'

task :generate_changelog do
  require 'pact/mock_service/version'
  ConventionalChangelog::Generator.new.generate! version: "v#{Pact::MockService::VERSION}"
end

desc 'Tag for release'
task :tag_for_release do | t, args |
  require 'pact/mock_service/version'
  version = Pact::MockService::VERSION
  command = "git tag -a v#{version} -m \"chore(release): version #{version}\" && git push origin v#{version}"
  puts command
  puts `#{command}`
end

desc 'Generate release notes'
task :generate_release_notes, [:tag] do | t, args |
  require 'fileutils'
  FileUtils.mkdir_p File.dirname(RELEASE_NOTES_PATH)
  tag = args[:tag]
  release_notes_template = File.read(RELEASE_NOTES_TEMPLATE_PATH)
  release_notes_content = release_notes_template.gsub("<TAG_NAME>", tag)
  release_notes_content = release_notes_content.gsub("<PACKAGE_VERSION>", VERSION)
  File.open(RELEASE_NOTES_PATH, "w") { |file| file << release_notes_content }
end

desc 'Upload release notes'
task :upload_release_notes, [:repository_slug, :tag] do |t, args |
  require 'octokit'
  stack = Faraday::RackBuilder.new do |builder|
    builder.response :logger do | logger |
      logger.filter(/(Authorization: )(.*)/,'\1[REMOVED]')
    end
    builder.use Octokit::Response::RaiseError
    builder.adapter Faraday.default_adapter
  end
  Octokit.middleware = stack

  access_token = ENV.fetch('GITHUB_ACCESS_TOKEN')
  repository_slug = args[:repository_slug]
  tag = args[:tag]
  release_name = "#{PACKAGE_NAME}-#{VERSION}"

  client = Octokit::Client.new(access_token: access_token)
  release_notes_content = File.read(RELEASE_NOTES_PATH)
  release =  client.release_for_tag repository_slug, tag
  client.update_release release.url, name: release_name, body: release_notes_content
end
