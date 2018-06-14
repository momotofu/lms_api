require_relative "../canvas_base_mutation"
require_relative "../../types/canvas/content_export"
module LMS
  module GraphQL
    module Mutations
      module Canvas
        class ExportContentGroup < CanvasBaseMutation
          argument :group_id, String, required: true
          argument :export_type, String, required: true
          argument :skip_notifications, Boolean, required: false
          argument :select, String, required: false
          field :content_export, LMS::GraphQL::Types::Canvas::ContentExport, null: false
          def resolve(group_id:, export_type:, skip_notifications: nil, select: nil)
            ctx[:canvas_api].proxy(
              "EXPORT_CONTENT_GROUPS",
              {
                "group_id": group_id,
                "export_type": export_type,
                "skip_notifications": skip_notifications,
                "select": select              },
              nil,
            ).parsed_response
          end
        end
      end
    end
  end
end