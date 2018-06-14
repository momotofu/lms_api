require_relative "../canvas_base_mutation"
require_relative "../../types/canvas/group"
module LMS
  module GraphQL
    module Mutations
      module Canvas
        class CreateGroupGroupCategory < CanvasBaseMutation
          argument :group_category_id, String, required: true
          argument :name, String, required: false
          argument :description, String, required: false
          argument :is_public, Boolean, required: false
          argument :join_level, String, required: false
          argument :storage_quota_mb, Int, required: false
          argument :sis_group_id, String, required: false
          field :group, LMS::GraphQL::Types::Canvas::Group, null: false
          def resolve(group_category_id:, name: nil, description: nil, is_public: nil, join_level: nil, storage_quota_mb: nil, sis_group_id: nil)
            ctx[:canvas_api].proxy(
              "CREATE_GROUP_GROUP_CATEGORIES",
              {
                "group_category_id": group_category_id,
                "name": name,
                "description": description,
                "is_public": is_public,
                "join_level": join_level,
                "storage_quota_mb": storage_quota_mb,
                "sis_group_id": sis_group_id              },
              nil,
            ).parsed_response
          end
        end
      end
    end
  end
end