module ProtectedRef
  extend ActiveSupport::Concern

  included do
    belongs_to :project

    validates :name, presence: true
    validates :project, presence: true

    delegate :matching, :matches?, :wildcard?, to: :ref_matcher
  end

  def commit
    project.commit(self.name)
  end

  class_methods do
    def protected_ref_access_levels(*types)
      types.each do |type|
        has_many :"#{type}_access_levels", dependent: :destroy # rubocop:disable Cop/ActiveRecordDependent

        validates :"#{type}_access_levels", length: { is: 1, message: "are restricted to a single instance per #{self.model_name.human}." }

        accepts_nested_attributes_for :"#{type}_access_levels", allow_destroy: true
      end
    end

    def protected_ref_accessible_to?(ref, user, action:)
      access_levels_for_ref(ref, action: action).any? do |access_level|
        access_level.check_access(user)
      end
    end

    def developers_can?(action, ref)
      access_levels_for_ref(ref, action: action).any? do |access_level|
        access_level.access_level == Gitlab::Access::DEVELOPER
      end
    end

    def access_levels_for_ref(ref, action:)
      self.matching(ref).map(&:"#{action}_access_levels").flatten
    end

    def matching(ref_name, protected_refs: nil)
      ProtectedRefMatcher.matching(self, ref_name, protected_refs: protected_refs)
    end
  end

  private

  def ref_matcher
    @ref_matcher ||= ProtectedRefMatcher.new(self)
  end
end
