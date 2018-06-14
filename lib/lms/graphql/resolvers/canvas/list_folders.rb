require_relative "../canvas_base_resolver"
require_relative "../../types/canvas/folder"
module LMS
  module GraphQL
    module Resolvers
      module Canvas
        class ListFolder < CanvasBaseResolver
          type [LMS::GraphQL::Types::Canvas::Folder], null: false
          argument :id, ID, required: true
          def resolve(id:)
            context[:canvas_api].proxy(
              "LIST_FOLDERS",
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