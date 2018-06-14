require_relative "../canvas_base_mutation"

module LMS
  module GraphQL
    module Mutations
      module Canvas
        class MarkTopicAsUnreadCourse < CanvasBaseMutation
          argument :course_id, ID, required: true
          argument :topic_id, ID, required: true
          field :return_value, Boolean, null: false
          def resolve(course_id:, topic_id:)
            ctx[:canvas_api].proxy(
              "MARK_TOPIC_AS_UNREAD_COURSES",
              {
                "course_id": course_id,
                "topic_id": topic_id              },
              nil,
            ).parsed_response
          end
        end
      end
    end
  end
end