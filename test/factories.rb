FactoryGirl.define do

  factory :capture do
    sequence(:name) { |n| "capture#{n}" }
    sequence(:host) { |n| "192.168.2.#{n}" }
    input1 { rand(1..65365) }
    input2 { rand(1..65365) }
    input3 { rand(1..65365) }
    input4 { rand(1..65365) }
  end

  factory :source do
    sequence(:name) { |n| "source#{n}" }
    association :capture, factory: :capture, strategy: :create
    input { rand(1..4) }
  end

  factory :preset do
    ignore do
      video_count 1
      audio_count 7
    end

    sequence(:name) { |n| "preset#{n}" }

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
    profile_number { rand(1..100) }
  end

  factory :audio_track, class: :Track do
    gain { rand(1..50) }
    num_channels { rand(1..2) }
    profile_number { rand(101..255) }
  end

  factory :transcoder do
    sequence(:name) { |n| "transcoder#{n}" }
    sequence(:host) { |n| "10.65.6.#{n}" }
    port 10000
    status_port 11000

    initialize_with { new(attributes) }
  end

  factory :slot do
    slot_id {rand(0..255) }
    scheme
    transcoder
  end

  factory :scheme, class: Scheme do
    sequence(:name) { |n| "scheme#{n}" }
    preset
    association :src1 , factory: :source, strategy: :create
    association :src2 , factory: :source, strategy: :create
    audio_mappings { preset.tracks.map { |t| rand(preset.tracks.size) } }
  end

  factory :event do
    sequence(:name) { |n| "event#{n}" }
  end
end