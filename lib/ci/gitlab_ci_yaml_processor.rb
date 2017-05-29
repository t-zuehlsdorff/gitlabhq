module Ci
  class GitlabCiYamlProcessor
    ValidationError = Class.new(StandardError)

    include Gitlab::Ci::Config::Entry::LegacyValidationHelpers

    attr_reader :path, :cache, :stages, :jobs

    def initialize(config, path = nil)
      @ci_config = Gitlab::Ci::Config.new(config)
      @config = @ci_config.to_hash
      @path = path

      unless @ci_config.valid?
        raise ValidationError, @ci_config.errors.first
      end

      initial_parsing
    rescue Gitlab::Ci::Config::Loader::FormatError => e
      raise ValidationError, e.message
    end

    def jobs_for_ref(ref, tag = false, trigger_request = nil)
      @jobs.select do |_, job|
        process?(job[:only], job[:except], ref, tag, trigger_request)
      end
    end

    def jobs_for_stage_and_ref(stage, ref, tag = false, trigger_request = nil)
      jobs_for_ref(ref, tag, trigger_request).select do |_, job|
        job[:stage] == stage
      end
    end

    def builds_for_ref(ref, tag = false, trigger_request = nil)
      jobs_for_ref(ref, tag, trigger_request).map do |name, _|
        build_attributes(name)
      end
    end

    def builds_for_stage_and_ref(stage, ref, tag = false, trigger_request = nil)
      jobs_for_stage_and_ref(stage, ref, tag, trigger_request).map do |name, _|
        build_attributes(name)
      end
    end

    def builds
      @jobs.map do |name, _|
        build_attributes(name)
      end
    end

    def build_attributes(name)
      job = @jobs[name.to_sym] || {}
      {
        stage_idx: @stages.index(job[:stage]),
        stage: job[:stage],
        commands: job[:commands],
        tag_list: job[:tags] || [],
        name: job[:name].to_s,
        allow_failure: job[:ignore],
        when: job[:when] || 'on_success',
        environment: job[:environment_name],
        coverage_regex: job[:coverage],
        yaml_variables: yaml_variables(name),
        options: {
          image: job[:image],
          services: job[:services],
          artifacts: job[:artifacts],
          cache: job[:cache],
          dependencies: job[:dependencies],
          after_script: job[:after_script],
          environment: job[:environment]
        }.compact
      }
    end

    def self.validation_message(content)
      return 'Please provide content of .gitlab-ci.yml' if content.blank?

      begin
        Ci::GitlabCiYamlProcessor.new(content)
        nil
      rescue ValidationError, Psych::SyntaxError => e
        e.message
      end
    end

    private

    def initial_parsing
      ##
      # Global config
      #
      @before_script = @ci_config.before_script
      @image = @ci_config.image
      @after_script = @ci_config.after_script
      @services = @ci_config.services
      @variables = @ci_config.variables
      @stages = @ci_config.stages
      @cache = @ci_config.cache

      ##
      # Jobs
      #
      @jobs = @ci_config.jobs

      @jobs.each do |name, job|
        # logical validation for job

        validate_job_stage!(name, job)
        validate_job_dependencies!(name, job)
        validate_job_environment!(name, job)
      end
    end

    def yaml_variables(name)
      variables = (@variables || {})
        .merge(job_variables(name))

      variables.map do |key, value|
        { key: key.to_s, value: value, public: true }
      end
    end

    def job_variables(name)
      job = @jobs[name.to_sym]
      return {} unless job

      job[:variables] || {}
    end

    def validate_job_stage!(name, job)
      return unless job[:stage]

      unless job[:stage].is_a?(String) && job[:stage].in?(@stages)
        raise ValidationError, "#{name} job: stage parameter should be #{@stages.join(", ")}"
      end
    end

    def validate_job_dependencies!(name, job)
      return unless job[:dependencies]

      stage_index = @stages.index(job[:stage])

      job[:dependencies].each do |dependency|
        raise ValidationError, "#{name} job: undefined dependency: #{dependency}" unless @jobs[dependency.to_sym]

        unless @stages.index(@jobs[dependency.to_sym][:stage]) < stage_index
          raise ValidationError, "#{name} job: dependency #{dependency} is not defined in prior stages"
        end
      end
    end

    def validate_job_environment!(name, job)
      return unless job[:environment]
      return unless job[:environment].is_a?(Hash)

      environment = job[:environment]
      validate_on_stop_job!(name, environment, environment[:on_stop])
    end

    def validate_on_stop_job!(name, environment, on_stop)
      return unless on_stop

      on_stop_job = @jobs[on_stop.to_sym]
      unless on_stop_job
        raise ValidationError, "#{name} job: on_stop job #{on_stop} is not defined"
      end

      unless on_stop_job[:environment]
        raise ValidationError, "#{name} job: on_stop job #{on_stop} does not have environment defined"
      end

      unless on_stop_job[:environment][:name] == environment[:name]
        raise ValidationError, "#{name} job: on_stop job #{on_stop} have different environment name"
      end

      unless on_stop_job[:environment][:action] == 'stop'
        raise ValidationError, "#{name} job: on_stop job #{on_stop} needs to have action stop defined"
      end
    end

    def process?(only_params, except_params, ref, tag, trigger_request)
      if only_params.present?
        return false unless matching?(only_params, ref, tag, trigger_request)
      end

      if except_params.present?
        return false if matching?(except_params, ref, tag, trigger_request)
      end

      true
    end

    def matching?(patterns, ref, tag, trigger_request)
      patterns.any? do |pattern|
        match_ref?(pattern, ref, tag, trigger_request)
      end
    end

    def match_ref?(pattern, ref, tag, trigger_request)
      pattern, path = pattern.split('@', 2)
      return false if path && path != self.path
      return true if tag && pattern == 'tags'
      return true if !tag && pattern == 'branches'
      return true if trigger_request.present? && pattern == 'triggers'

      if pattern.first == "/" && pattern.last == "/"
        Regexp.new(pattern[1...-1]) =~ ref
      else
        pattern == ref
      end
    end
  end
end
