require_relative "../canvas_base_mutation"
require_relative "../../types/canvas/grading_standard"
module LMS
  module GraphQL
    module Mutations
      module Canvas
        class CreateNewGradingStandardCourse < CanvasBaseMutation
          argument :course_id, ID, required: true
          argument :title, String, required: true
          argument :grading_scheme_entry_name, String, required: true
          argument :grading_scheme_entry_value, Int, required: true
          field :grading_standard, LMS::GraphQL::Types::Canvas::GradingStandard, null: false
          def resolve(course_id:, title:, grading_scheme_entry_name:, grading_scheme_entry_value:)
            ctx[:canvas_api].proxy(
              "CREATE_NEW_GRADING_STANDARD_COURSES",
              {
                "course_id": course_id,
                "title": title,
                "grading_scheme_entry[name]": grading_scheme_entry_name,
                "grading_scheme_entry[value]": grading_scheme_entry_value              },
              nil,
            ).parsed_response
          end
        end
      end
    end
  end
end