require_relative "../canvas_base_resolver"

module LMS
  module GraphQL
    module Resolvers
      module Canvas
        class ListCountsForTodoItem < CanvasBaseResolver
          type Boolean, null: false
          argument :include, String, required: false
          def resolve(include: nil)
            context[:canvas_api].proxy(
              "LIST_COUNTS_FOR_TODO_ITEMS",
              {
                "include": include              },
              nil,
            ).parsed_response
          end
        end
      end
    end
  end
end