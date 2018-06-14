require_relative "../canvas_base_resolver"
require_relative "../../types/canvas/external_feed"
module LMS
  module GraphQL
    module Resolvers
      module Canvas
        class ListExternalFeedsCourse < CanvasBaseResolver
          type [LMS::GraphQL::Types::Canvas::ExternalFeed], null: false
          argument :course_id, String, required: true
          def resolve(course_id:)
            context[:canvas_api].proxy(
              "LIST_EXTERNAL_FEEDS_COURSES",
              {
                "course_id": course_id              },
              nil,
            ).parsed_response
          end
        end
      end
    end
  end
end