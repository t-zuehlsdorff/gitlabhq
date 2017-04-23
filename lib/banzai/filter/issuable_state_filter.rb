module Banzai
  module Filter
    # HTML filter that appends state information to issuable links.
    # Runs as a post-process filter as issuable state might change whilst
    # Markdown is in the cache.
    #
    # This filter supports cross-project references.
    class IssuableStateFilter < HTML::Pipeline::Filter
      VISIBLE_STATES = %w(closed merged).freeze

      def call
        return doc unless context[:issuable_state_filter_enabled]

        extractor = Banzai::IssuableExtractor.new(project, current_user)
        issuables = extractor.extract([doc])

        issuables.each do |node, issuable|
          if VISIBLE_STATES.include?(issuable.state) && node.inner_html == issuable.reference_link_text(project)
            node.content += " (#{issuable.state})"
          end
        end

        doc
      end

      private

      def current_user
        context[:current_user]
      end

      def project
        context[:project]
      end
    end
  end
end
