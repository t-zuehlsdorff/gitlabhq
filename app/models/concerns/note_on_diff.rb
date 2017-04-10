# Contains functionality shared between `DiffNote` and `LegacyDiffNote`.
module NoteOnDiff
  extend ActiveSupport::Concern

  def diff_note?
    true
  end

  def diff_file
    raise NotImplementedError
  end

  def diff_line
    raise NotImplementedError
  end

  def for_line?(line)
    raise NotImplementedError
  end

  def original_line_code
    raise NotImplementedError
  end

  def diff_attributes
    raise NotImplementedError
  end
end
