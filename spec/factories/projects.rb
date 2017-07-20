require_relative '../support/test_env'

FactoryGirl.define do
  # Project without repository
  #
  # Project does not have bare repository.
  # Use this factory if you don't need repository in tests
  factory :empty_project, class: 'Project' do
    sequence(:name) { |n| "project#{n}" }
    path { name.downcase.gsub(/\s/, '_') }
    namespace
    creator

    # Behaves differently to nil due to cache_has_external_issue_tracker
    has_external_issue_tracker false

    trait :public do
      visibility_level Gitlab::VisibilityLevel::PUBLIC
    end

    trait :internal do
      visibility_level Gitlab::VisibilityLevel::INTERNAL
    end

    trait :private do
      visibility_level Gitlab::VisibilityLevel::PRIVATE
    end

    trait :import_scheduled do
      import_status :scheduled
    end

    trait :import_started do
      import_status :started
    end

    trait :import_finished do
      import_status :finished
    end

    trait :import_failed do
      import_status :failed
    end

    trait :archived do
      archived true
    end

    trait :access_requestable do
      request_access_enabled true
    end

    trait :with_avatar do
      avatar { File.open(Rails.root.join('spec/fixtures/dk.png')) }
    end

    trait :repository do
      # no-op... for now!
    end

    trait :empty_repo do
      after(:create) do |project|
        raise "Failed to create repository!" unless project.create_repository

        # We delete hooks so that gitlab-shell will not try to authenticate with
        # an API that isn't running
        FileUtils.rm_r(File.join(project.repository_storage_path, "#{project.path_with_namespace}.git", 'hooks'))
      end
    end

    trait :broken_repo do
      after(:create) do |project|
        raise "Failed to create repository!" unless project.create_repository

        FileUtils.rm_r(File.join(project.repository_storage_path, "#{project.path_with_namespace}.git", 'refs'))
      end
    end

    trait :test_repo do
      after :create do |project|
        TestEnv.copy_repo(project,
          bare_repo: TestEnv.factory_repo_path_bare,
          refs: TestEnv::BRANCH_SHA)
      end
    end

    trait(:wiki_enabled)            { wiki_access_level ProjectFeature::ENABLED }
    trait(:wiki_disabled)           { wiki_access_level ProjectFeature::DISABLED }
    trait(:wiki_private)            { wiki_access_level ProjectFeature::PRIVATE }
    trait(:builds_enabled)          { builds_access_level ProjectFeature::ENABLED }
    trait(:builds_disabled)         { builds_access_level ProjectFeature::DISABLED }
    trait(:builds_private)          { builds_access_level ProjectFeature::PRIVATE }
    trait(:snippets_enabled)        { snippets_access_level ProjectFeature::ENABLED }
    trait(:snippets_disabled)       { snippets_access_level ProjectFeature::DISABLED }
    trait(:snippets_private)        { snippets_access_level ProjectFeature::PRIVATE }
    trait(:issues_disabled)         { issues_access_level ProjectFeature::DISABLED }
    trait(:issues_enabled)          { issues_access_level ProjectFeature::ENABLED }
    trait(:issues_private)          { issues_access_level ProjectFeature::PRIVATE }
    trait(:merge_requests_enabled)  { merge_requests_access_level ProjectFeature::ENABLED }
    trait(:merge_requests_disabled) { merge_requests_access_level ProjectFeature::DISABLED }
    trait(:merge_requests_private)  { merge_requests_access_level ProjectFeature::PRIVATE }
    trait(:repository_enabled)      { repository_access_level ProjectFeature::ENABLED }
    trait(:repository_disabled)     { repository_access_level ProjectFeature::DISABLED }
    trait(:repository_private)      { repository_access_level ProjectFeature::PRIVATE }

    # Nest Project Feature attributes
    transient do
      wiki_access_level ProjectFeature::ENABLED
      builds_access_level ProjectFeature::ENABLED
      snippets_access_level ProjectFeature::ENABLED
      issues_access_level ProjectFeature::ENABLED
      merge_requests_access_level ProjectFeature::ENABLED
      repository_access_level ProjectFeature::ENABLED
    end

    after(:create) do |project, evaluator|
      # Builds and MRs can't have higher visibility level than repository access level.
      builds_access_level = [evaluator.builds_access_level, evaluator.repository_access_level].min
      merge_requests_access_level = [evaluator.merge_requests_access_level, evaluator.repository_access_level].min

      project.project_feature
        .update_attributes!(
          wiki_access_level: evaluator.wiki_access_level,
          builds_access_level: builds_access_level,
          snippets_access_level: evaluator.snippets_access_level,
          issues_access_level: evaluator.issues_access_level,
          merge_requests_access_level: merge_requests_access_level,
          repository_access_level: evaluator.repository_access_level
        )

      # Normally the class Projects::CreateService is used for creating
      # projects, and this class takes care of making sure the owner and current
      # user have access to the project. Our specs don't use said service class,
      # thus we must manually refresh things here.
      owner = project.owner

      if owner && owner.is_a?(User) && !project.pending_delete
        project.members.create!(user: owner, access_level: Gitlab::Access::MASTER)
      end

      project.group&.refresh_members_authorized_projects
    end
  end

  # Project with empty repository
  #
  # This is a case when you just created a project
  # but not pushed any code there yet
  factory :project_empty_repo, parent: :empty_project do
    empty_repo
  end

  # Project with broken repository
  #
  # Project with an invalid repository state
  factory :project_broken_repo, parent: :empty_project do
    broken_repo
  end

  # Project with test repository
  #
  # Test repository source can be found at
  # https://gitlab.com/gitlab-org/gitlab-test
  factory :project, parent: :empty_project do
    path { 'gitlabhq' }

    test_repo

    transient do
      create_template nil
    end

    after :create do |project, evaluator|
      TestEnv.copy_repo(project,
        bare_repo: TestEnv.factory_repo_path_bare,
        refs: TestEnv::BRANCH_SHA)

      if evaluator.create_template
        args = evaluator.create_template

        project.add_user(args[:user], args[:access])

        project.repository.create_file(
          args[:user],
          ".gitlab/#{args[:path]}/bug.md",
          'something valid',
          message: 'test 3',
          branch_name: 'master')
        project.repository.create_file(
          args[:user],
          ".gitlab/#{args[:path]}/template_test.md",
          'template_test',
          message: 'test 1',
          branch_name: 'master')
        project.repository.create_file(
          args[:user],
          ".gitlab/#{args[:path]}/feature_proposal.md",
          'feature_proposal',
          message: 'test 2',
          branch_name: 'master')
      end
    end
  end

  factory :forked_project_with_submodules, parent: :empty_project do
    path { 'forked-gitlabhq' }

    after :create do |project|
      TestEnv.copy_repo(project,
        bare_repo: TestEnv.forked_repo_path_bare,
        refs: TestEnv::FORKED_BRANCH_SHA)
    end
  end

  factory :redmine_project, parent: :project do
    has_external_issue_tracker true

    after :create do |project|
      project.create_redmine_service(
        active: true,
        properties: {
          'project_url' => 'http://redmine/projects/project_name_in_redmine',
          'issues_url' => 'http://redmine/projects/project_name_in_redmine/issues/:id',
          'new_issue_url' => 'http://redmine/projects/project_name_in_redmine/issues/new'
        }
      )
    end
  end

  factory :jira_project, parent: :project do
    has_external_issue_tracker true
    jira_service
  end

  factory :kubernetes_project, parent: :empty_project do
    kubernetes_service
  end

  factory :prometheus_project, parent: :empty_project do
    after :create do |project|
      project.create_prometheus_service(
        active: true,
        properties: {
          api_url: 'https://prometheus.example.com'
        }
      )
    end
  end
end
