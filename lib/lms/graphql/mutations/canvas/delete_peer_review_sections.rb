require_relative "../canvas_base_mutation"
require_relative "../../types/canvas/peer_review"
module LMS
  module GraphQL
    module Mutations
      module Canvas
        class DeletePeerReviewSection < CanvasBaseMutation
          argument :section_id, ID, required: true
          argument :assignment_id, ID, required: true
          argument :submission_id, ID, required: true
          argument :user_id, ID, required: true
          field :peer_review, LMS::GraphQL::Types::Canvas::PeerReview, null: false
          def resolve(section_id:, assignment_id:, submission_id:, user_id:)
            ctx[:canvas_api].proxy(
              "DELETE_PEER_REVIEW_SECTIONS",
              {
                "section_id": section_id,
                "assignment_id": assignment_id,
                "submission_id": submission_id,
                "user_id": user_id              },
              nil,
            ).parsed_response
          end
        end
      end
    end
  end
end