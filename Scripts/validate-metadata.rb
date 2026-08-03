#!/usr/bin/env ruby
# frozen_string_literal: true

# Validates fastlane/metadata against App Store Connect's limits, locally.
#
# `deliver`'s `verify_only` is not this. It verifies a *binary* package, and a
# metadata-only lane passes no ipa or pkg, so it crashes in
# IpaUploadPackageBuilder before any metadata is looked at. A pull request has
# no build to verify and must not write to the live listing either, so the
# check it can usefully run is this one: the files on disk, on their own.

require 'uri'

ROOT = File.expand_path('../fastlane/metadata', __dir__)

# Character limits as App Store Connect enforces them. A field absent from this
# table is unknown to this script and reported as such — a typo in a filename
# is silently ignored by deliver, which is exactly the mistake worth catching.
LOCALE_FIELDS = {
  'name' => 30,
  'subtitle' => 30,
  'description' => 4000,
  'keywords' => 100,
  'promotional_text' => 170,
  'release_notes' => 4000,
  'marketing_url' => 255,
  'privacy_url' => 255,
  'support_url' => 255,
  'apple_tv_privacy_policy' => nil
}.freeze

REQUIRED_LOCALE_FIELDS = %w[name description keywords support_url].freeze

URL_FIELDS = %w[marketing_url privacy_url support_url].freeze

ROOT_FIELDS = {
  'copyright' => 100,
  'primary_category' => nil,
  'secondary_category' => nil,
  'primary_first_sub_category' => nil,
  'primary_second_sub_category' => nil,
  'secondary_first_sub_category' => nil,
  'secondary_second_sub_category' => nil
}.freeze

REVIEW_FIELDS = {
  'first_name' => 50,
  'last_name' => 50,
  'phone_number' => 50,
  'email_address' => 255,
  'demo_user' => 255,
  'demo_password' => 255,
  'notes' => 4000
}.freeze

# App Store Connect's own keys, as deliver writes them.
CATEGORIES = %w[
  BOOKS BUSINESS DEVELOPER_TOOLS EDUCATION ENTERTAINMENT FINANCE FOOD_AND_DRINK
  GAMES GRAPHICS_AND_DESIGN HEALTH_AND_FITNESS LIFESTYLE MAGAZINES_AND_NEWSPAPERS
  MEDICAL MUSIC NAVIGATION NEWS PHOTO_AND_VIDEO PRODUCTIVITY REFERENCE
  SHOPPING SOCIAL_NETWORKING SPORTS STICKERS TRAVEL UTILITIES WEATHER
].freeze

problems = []

def read(path)
  File.read(path).strip
end

def relative(path)
  path.sub("#{File.dirname(ROOT)}/", 'fastlane/')
end

# Anything that is not a locale directory is either a known top-level field or
# review_information; a locale is a directory holding *.txt.
entries = Dir.children(ROOT).sort
locales = entries.select { |e| File.directory?(File.join(ROOT, e)) && e != 'review_information' }

problems << 'fastlane/metadata holds no locale directory' if locales.empty?

# Every locale carries the same fields. A half-written locale uploads a listing
# with blank fields rather than failing, so mismatch is the error.
field_sets = locales.to_h do |locale|
  [locale, Dir.children(File.join(ROOT, locale)).grep(/\.txt\z/).map { |f| File.basename(f, '.txt') }.sort]
end

reference_locale, reference_fields = field_sets.first
field_sets.each do |locale, fields|
  next if fields == reference_fields

  missing = reference_fields - fields
  extra = fields - reference_fields
  detail = []
  detail << "missing #{missing.join(', ')}" unless missing.empty?
  detail << "only here: #{extra.join(', ')}" unless extra.empty?
  problems << "#{locale} does not match #{reference_locale} (#{detail.join('; ')})"
end

locales.each do |locale|
  dir = File.join(ROOT, locale)

  Dir.children(dir).sort.each do |entry|
    path = File.join(dir, entry)
    field = File.basename(entry, '.txt')

    unless entry.end_with?('.txt') && LOCALE_FIELDS.key?(field)
      problems << "#{relative(path)}: not a field deliver uploads — deliver ignores it silently"
      next
    end

    value = read(path)
    limit = LOCALE_FIELDS[field]

    if value.empty?
      problems << "#{relative(path)}: required, but empty" if REQUIRED_LOCALE_FIELDS.include?(field)
      next
    end

    if limit && value.length > limit
      problems << "#{relative(path)}: #{value.length} characters, limit is #{limit}"
    end

    next unless URL_FIELDS.include?(field)

    uri = URI.parse(value) rescue nil # rubocop:disable Style/RescueModifier
    problems << "#{relative(path)}: not an https URL (#{value})" unless uri.is_a?(URI::HTTPS)
  end

  REQUIRED_LOCALE_FIELDS.each do |field|
    path = File.join(dir, "#{field}.txt")
    problems << "#{relative(path)}: required, but absent" unless File.exist?(path)
  end
end

ROOT_FIELDS.each do |field, limit|
  path = File.join(ROOT, "#{field}.txt")
  next unless File.exist?(path)

  value = read(path)
  next if value.empty?

  problems << "#{relative(path)}: #{value.length} characters, limit is #{limit}" if limit && value.length > limit
end

%w[primary_category secondary_category].each do |field|
  path = File.join(ROOT, "#{field}.txt")
  value = File.exist?(path) ? read(path) : ''

  if field == 'primary_category' && value.empty?
    problems << "#{relative(path)}: required, but empty"
    next
  end

  next if value.empty?

  problems << "#{relative(path)}: #{value} is not an App Store category" unless CATEGORIES.include?(value)
end

copyright_path = File.join(ROOT, 'copyright.txt')
problems << 'fastlane/metadata/copyright.txt: required, but empty' if !File.exist?(copyright_path) || read(copyright_path).empty?

review_dir = File.join(ROOT, 'review_information')
if File.directory?(review_dir)
  Dir.children(review_dir).sort.each do |entry|
    path = File.join(review_dir, entry)
    field = File.basename(entry, '.txt')

    unless entry.end_with?('.txt') && REVIEW_FIELDS.key?(field)
      problems << "#{relative(path)}: not a review_information field deliver uploads"
      next
    end

    value = read(path)
    limit = REVIEW_FIELDS[field]
    problems << "#{relative(path)}: #{value.length} characters, limit is #{limit}" if value.length > limit
  end
end

if problems.empty?
  puts "fastlane/metadata is valid (#{locales.sort.join(', ')})."
  exit 0
end

warn "fastlane/metadata has #{problems.length} problem#{'s' unless problems.length == 1}:"
problems.each { |problem| warn "  - #{problem}" }
exit 1
