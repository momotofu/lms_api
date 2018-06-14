require_relative "../canvas_base_mutation"

module LMS
  module GraphQL
    module Mutations
      module Canvas
        class MarkEntryAsReadGroup < CanvasBaseMutation
          argument :group_id, String, required: true
          argument :topic_id, String, required: true
          argument :entry_id, String, required: true
          argument :forced_read_state, Boolean, required: false
          field :return_value, Boolean, null: false
          def resolve(group_id:, topic_id:, entry_id:, forced_read_state: nil)
            ctx[:canvas_api].proxy(
              "MARK_ENTRY_AS_READ_GROUPS",
              {
                "group_id": group_id,
                "topic_id": topic_id,
                "entry_id": entry_id,
                "forced_read_state": forced_read_state              },
              nil,
            ).parsed_response
          end
        end
      end
    end
  end
end