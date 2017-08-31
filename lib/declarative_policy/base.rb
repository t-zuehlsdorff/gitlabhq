module DeclarativePolicy
  class Base
    # A map of ability => list of rules together with :enable
    # or :prevent actions. Used to look up which rules apply to
    # a given ability. See Base.ability_map
    class AbilityMap
      attr_reader :map
      def initialize(map = {})
        @map = map
      end

      # This merge behavior is different than regular hashes - if both
      # share a key, the values at that key are concatenated, rather than
      # overridden.
      def merge(other)
        conflict_proc = proc { |key, my_val, other_val| my_val + other_val }
        AbilityMap.new(@map.merge(other.map, &conflict_proc))
      end

      def actions(key)
        @map[key] ||= []
      end

      def enable(key, rule)
        actions(key) << [:enable, rule]
      end

      def prevent(key, rule)
        actions(key) << [:prevent, rule]
      end
    end

    class << self
      # The `own_ability_map` vs `ability_map` distinction is used so that
      # the data structure is properly inherited - with subclasses recursively
      # merging their parent class.
      #
      # This pattern is also used for conditions, global_actions, and delegations.
      def ability_map
        if self == Base
          own_ability_map
        else
          superclass.ability_map.merge(own_ability_map)
        end
      end

      def own_ability_map
        @own_ability_map ||= AbilityMap.new
      end

      # an inheritable map of conditions, by name
      def conditions
        if self == Base
          own_conditions
        else
          superclass.conditions.merge(own_conditions)
        end
      end

      def own_conditions
        @own_conditions ||= {}
      end

      # a list of global actions, generated by `prevent_all`. these aren't
      # stored in `ability_map` because they aren't indexed by a particular
      # ability.
      def global_actions
        if self == Base
          own_global_actions
        else
          superclass.global_actions + own_global_actions
        end
      end

      def own_global_actions
        @own_global_actions ||= []
      end

      # an inheritable map of delegations, indexed by name (which may be
      # autogenerated)
      def delegations
        if self == Base
          own_delegations
        else
          superclass.delegations.merge(own_delegations)
        end
      end

      def own_delegations
        @own_delegations ||= {}
      end

      # all the [rule, action] pairs that apply to a particular ability.
      # we combine the specific ones looked up in ability_map with the global
      # ones.
      def configuration_for(ability)
        ability_map.actions(ability) + global_actions
      end

      ### declaration methods ###

      def delegate(name = nil, &delegation_block)
        if name.nil?
          @delegate_name_counter ||= 0
          @delegate_name_counter += 1
          name = :"anonymous_#{@delegate_name_counter}"
        end

        name = name.to_sym

        if delegation_block.nil?
          delegation_block = proc { @subject.__send__(name) } # rubocop:disable GitlabSecurity/PublicSend
        end

        own_delegations[name] = delegation_block
      end

      # Declares a rule, constructed using RuleDsl, and returns
      # a PolicyDsl which is used for registering the rule with
      # this class. PolicyDsl will call back into Base.enable_when,
      # Base.prevent_when, and Base.prevent_all_when.
      def rule(&b)
        rule = RuleDsl.new(self).instance_eval(&b)
        PolicyDsl.new(self, rule)
      end

      # A hash in which to store calls to `desc` and `with_scope`, etc.
      def last_options
        @last_options ||= {}.with_indifferent_access
      end

      # retrieve and zero out the previously set options (used in .condition)
      def last_options!
        last_options.tap { @last_options = nil }
      end

      # Declare a description for the following condition. Currently unused,
      # but opens the potential for explaining to users why they were or were
      # not able to do something.
      def desc(description)
        last_options[:description] = description
      end

      def with_options(opts = {})
        last_options.merge!(opts)
      end

      def with_scope(scope)
        with_options scope: scope
      end

      def with_score(score)
        with_options score: score
      end

      # Declares a condition. It gets stored in `own_conditions`, and generates
      # a query method based on the condition's name.
      def condition(name, opts = {}, &value)
        name = name.to_sym

        opts = last_options!.merge(opts)
        opts[:context_key] ||= self.name

        condition = Condition.new(name, opts, &value)

        self.own_conditions[name] = condition

        define_method(:"#{name}?") { condition(name).pass? }
      end

      # These next three methods are mainly called from PolicyDsl,
      # and are responsible for "inverting" the relationship between
      # an ability and a rule. We store in `ability_map` a map of
      # abilities to rules that affect them, together with a
      # symbol indicating :prevent or :enable.
      def enable_when(abilities, rule)
        abilities.each { |a| own_ability_map.enable(a, rule) }
      end

      def prevent_when(abilities, rule)
        abilities.each { |a| own_ability_map.prevent(a, rule) }
      end

      # we store global prevents (from `prevent_all`) separately,
      # so that they can be combined into every decision made.
      def prevent_all_when(rule)
        own_global_actions << [:prevent, rule]
      end
    end

    # A policy object contains a specific user and subject on which
    # to compute abilities. For this reason it's sometimes called
    # "context" within the framework.
    #
    # It also stores a reference to the cache, so it can be used
    # to cache computations by e.g. ManifestCondition.
    attr_reader :user, :subject, :cache
    def initialize(user, subject, opts = {})
      @user = user
      @subject = subject
      @cache = opts[:cache] || {}
    end

    # helper for checking abilities on this and other subjects
    # for the current user.
    def can?(ability, new_subject = :_self)
      return allowed?(ability) if new_subject == :_self

      policy_for(new_subject).allowed?(ability)
    end

    # This is the main entry point for permission checks. It constructs
    # or looks up a Runner for the given ability and asks it if it passes.
    def allowed?(*abilities)
      abilities.all? { |a| runner(a).pass? }
    end

    # The inverse of #allowed?, used mainly in specs.
    def disallowed?(*abilities)
      abilities.all? { |a| !runner(a).pass? }
    end

    # computes the given ability and prints a helpful debugging output
    # showing which
    def debug(ability, *a)
      runner(ability).debug(*a)
    end

    desc "Unknown user"
    condition(:anonymous, scope: :user, score: 0) { @user.nil? }

    desc "By default"
    condition(:default, scope: :global, score: 0) { true }

    def repr
      subject_repr =
        if @subject.respond_to?(:id)
          "#{@subject.class.name}/#{@subject.id}"
        else
          @subject.inspect
        end

      user_repr =
        if @user
          @user.to_reference
        else
          "<anonymous>"
        end

      "(#{user_repr} : #{subject_repr})"
    end

    def inspect
      "#<#{self.class.name} #{repr}>"
    end

    # returns a Runner for the given ability, capable of computing whether
    # the ability is allowed. Runners are cached on the policy (which itself
    # is cached on @cache), and caches its result. This is how we perform caching
    # at the ability level.
    def runner(ability)
      ability = ability.to_sym
      @runners ||= {}
      @runners[ability] ||=
        begin
          delegated_runners = delegated_policies.values.compact.map { |p| p.runner(ability) }
          own_runner = Runner.new(own_steps(ability))
          delegated_runners.inject(own_runner, &:merge_runner)
        end
    end

    # Helpers for caching. Used by ManifestCondition in performing condition
    # computation.
    #
    # NOTE we can't use ||= here because the value might be the
    # boolean `false`
    def cache(key, &b)
      return @cache[key] if cached?(key)
      @cache[key] = yield
    end

    def cached?(key)
      !@cache[key].nil?
    end

    # returns a ManifestCondition capable of computing itself. The computation
    # will use our own @cache.
    def condition(name)
      name = name.to_sym
      @_conditions ||= {}
      @_conditions[name] ||=
        begin
          raise "invalid condition #{name}" unless self.class.conditions.key?(name)
          ManifestCondition.new(self.class.conditions[name], self)
        end
    end

    # used in specs - returns true if there is no possible way for any action
    # to be allowed, determined only by the global :prevent_all rules.
    def banned?
      global_steps = self.class.global_actions.map { |(action, rule)| Step.new(self, rule, action) }
      !Runner.new(global_steps).pass?
    end

    # A list of other policies that we've delegated to (see `Base.delegate`)
    def delegated_policies
      @delegated_policies ||= self.class.delegations.transform_values do |block|
        new_subject = instance_eval(&block)

        # never delegate to nil, as that would immediately prevent_all
        next if new_subject.nil?

        policy_for(new_subject)
      end
    end

    def policy_for(other_subject)
      DeclarativePolicy.policy_for(@user, other_subject, cache: @cache)
    end

    protected

    # constructs steps that come from this policy and not from any delegations
    def own_steps(ability)
      rules = self.class.configuration_for(ability)
      rules.map { |(action, rule)| Step.new(self, rule, action) }
    end
  end
end
