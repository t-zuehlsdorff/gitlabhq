FactoryGirl.define do
  factory :issue do
    title { generate(:title) }
    author
    project

    trait :confidential do
      confidential true
    end

    trait :opened do
      state :opened
    end

    trait :closed do
      state :closed
    end

    factory :closed_issue, traits: [:closed]
    factory :reopened_issue, traits: [:opened]

    factory :labeled_issue do
      transient do
        labels []
      end

      after(:create) do |issue, evaluator|
        issue.update_attributes(labels: evaluator.labels)
      end
    end
  end
end
