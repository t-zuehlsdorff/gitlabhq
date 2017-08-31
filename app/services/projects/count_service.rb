module Projects
  # Base class for the various service classes that count project data (e.g.
  # issues or forks).
  class CountService
    def initialize(project)
      @project = project
    end

    def relation_for_count
      raise(
        NotImplementedError,
        '"relation_for_count" must be implemented and return an ActiveRecord::Relation'
      )
    end

    def count
      Rails.cache.fetch(cache_key) { uncached_count }
    end

    def refresh_cache
      Rails.cache.write(cache_key, uncached_count)
    end

    def uncached_count
      relation_for_count.count
    end

    def delete_cache
      Rails.cache.delete(cache_key)
    end

    def cache_key_name
      raise(
        NotImplementedError,
        '"cache_key_name" must be implemented and return a String'
      )
    end

    def cache_key
      ['projects', @project.id, cache_key_name]
    end
  end
end
