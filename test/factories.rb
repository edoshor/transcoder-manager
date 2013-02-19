FactoryGirl.define do

  factory :source do
    sequence(:name) {|n| "source#{n}" }
    sequence(:port) {|n| 3000 + n }
    host '192.168.2.1'
  end

  factory :preset do
    ignore do
      video_count 1
      audio_count 7
    end

    sequence(:name) {|n| "preset#{n}" }

    after(:create) do |preset, evaluator|
      create_list(:video_track, evaluator.video_count) +
      create_list(:audio_track, evaluator.audio_count)
      .each do |track|
        preset.tracks.push track
      end
    end

  end

  factory :video_track, class: :Track do
    gain 0
    num_channels 0
    profile_number { 1 + rand(100) }
  end

  factory :audio_track, class: :Track do
    gain { rand(51) }
    num_channels { 1 + rand(1) }
    profile_number { 101 + rand(155) }
  end

  factory :transcoder do
    sequence(:name) {|n| "transcoder#{n}" }
    sequence(:host) {|n| "10.66.132.#{n}" }
    port 10000
    status_port 11000

    initialize_with { new(attributes) }
  end

  factory :scheme, class: Scheme do
    sequence(:name) {|n| "scheme#{n}" }
    preset
    association :src1 , factory: :source, strategy: :create
    association :src2 , factory: :source, strategy: :create
    audio_mappings { preset.tracks.map { |t| rand(preset.tracks.size)} }
  end
end