class List < ActiveRecord::Base
  belongs_to :board
  belongs_to :label

  enum list_type: { backlog: 0, label: 1, closed: 2 }

  validates :board, :list_type, presence: true
  validates :label, :position, presence: true, if: :label?
  validates :label_id, uniqueness: { scope: :board_id }, if: :label?
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, if: :label?

  before_destroy :can_be_destroyed

  scope :destroyable, -> { where(list_type: list_types[:label]) }
  scope :movable, -> { where(list_type: list_types[:label]) }

  def destroyable?
    label?
  end

  def movable?
    label?
  end

  def title
    label? ? label.name : list_type.humanize
  end

  def as_json(options = {})
    super(options).tap do |json|
      if options.key?(:label)
        json[:label] = label.as_json(
          project: board.project,
          only: [:id, :title, :description, :color]
        )
      end
    end
  end

  private

  def can_be_destroyed
    destroyable?
  end
end
