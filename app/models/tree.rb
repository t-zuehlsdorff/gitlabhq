class Tree
  include Gitlab::MarkupHelper

  attr_accessor :repository, :sha, :path, :entries

  def initialize(repository, sha, path = '/', recursive: false)
    path = '/' if path.blank?

    @repository = repository
    @sha = sha
    @path = path
    @recursive = recursive

    git_repo = @repository.raw_repository
    @entries = get_entries(git_repo, @sha, @path, recursive: @recursive)
  end

  def readme
    return @readme if defined?(@readme)

    available_readmes = blobs.select do |blob|
      Gitlab::FileDetector.type_of(blob.name) == :readme
    end

    previewable_readmes = available_readmes.select do |blob|
      previewable?(blob.name)
    end

    plain_readmes = available_readmes.select do |blob|
      plain?(blob.name)
    end

    # Prioritize previewable over plain readmes
    readme_tree = previewable_readmes.first || plain_readmes.first

    # Return if we can't preview any of them
    if readme_tree.nil?
      return @readme = nil
    end

    readme_path = path == '/' ? readme_tree.name : File.join(path, readme_tree.name)

    @readme = repository.blob_at(sha, readme_path)
  end

  def trees
    @entries.select(&:dir?)
  end

  def blobs
    @entries.select(&:file?)
  end

  def submodules
    @entries.select(&:submodule?)
  end

  def sorted_entries
    trees + blobs + submodules
  end

  private

  def get_entries(git_repo, sha, path, recursive: false)
    current_path_entries = Gitlab::Git::Tree.where(git_repo, sha, path)
    ordered_entries = []

    current_path_entries.each do |entry|
      ordered_entries << entry

      if recursive && entry.dir?
        ordered_entries.concat(get_entries(git_repo, sha, entry.path, recursive: true))
      end
    end

    ordered_entries
  end
end
