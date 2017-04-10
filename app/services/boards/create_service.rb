module Boards
  class CreateService < BaseService
    def execute
      if project.boards.empty?
        create_board!
      else
        project.boards.first
      end
    end

    private

    def create_board!
      board = project.boards.create
      board.lists.create(list_type: :closed)

      board
    end
  end
end
