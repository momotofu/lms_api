require_relative "../canvas_base_mutation"
require_relative "../../types/canvas/favorite"
module LMS
  module GraphQL
    module Mutations
      module Canvas
        class RemoveCourseFromFavorite < CanvasBaseMutation
          argument :id, ID, required: true
          field :favorite, LMS::GraphQL::Types::Canvas::Favorite, null: false
          def resolve(id:)
            ctx[:canvas_api].proxy(
              "REMOVE_COURSE_FROM_FAVORITES",
              {
                "id": id              },
              nil,
            ).parsed_response
          end
        end
      end
    end
  end
end