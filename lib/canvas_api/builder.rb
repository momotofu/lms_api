require "canvas_api/render"
require "byebug"
module CanvasApi

  class Builder

    #
    # project_root: This is the directory where the canvas_urls.rb file will be written.
    # This file contains all urls and functions for access to the Canvas API from this gem (lms_api).
    # client_app_path: This where all client side Javascript for accessing the Canvas API will be written.
    # server_app_path: This is where all server side Javascript for accessing the Canvas API will be written.
    # Currently, this is generating GraphQL for Javascript
    #
    def self.build(project_root, client_app_path, server_app_path, elixir_app_path)
      endpoint = "https://canvas.instructure.com/doc/api"
      directory = HTTParty.get("#{endpoint}/api-docs.json")

      lms_urls_rb = []
      lms_urls_js = []
      lms_urls_ex = []
      course_ids_required_rb = []
      models = []
      js_graphql_queries = []
      js_graphql_mutations = []

      rb_graphql_fields = []
      rb_graphql_mutations = []

      directory["apis"].each do |api|
        puts "Generating #{api['description']}"
        resource = HTTParty.get("#{endpoint}#{api['path']}")
        constants = []
        resource["apis"].each do |resource_api|
          resource_api["operations"].each do |operation|
            parameters = operation["parameters"]
            constants << CanvasApi::Render.new("./templates/constant.erb", api, resource, resource_api, operation, parameters, nil, nil).render
            lms_urls_rb << CanvasApi::Render.new("./templates/rb_url.erb", api, resource, resource_api, operation, parameters, nil, nil).render
            lms_urls_js << CanvasApi::Render.new("./templates/js_url.erb", api, resource, resource_api, operation, parameters, nil, nil).render
            lms_urls_ex << CanvasApi::Render.new("./templates/ex_url.erb", api, resource, resource_api, operation, parameters, nil, nil).render

            if parameters.detect{ |param| param["name"] == "course_id" && param["paramType"] == "path" }
              course_ids_required_rb << CanvasApi::Render.new("./templates/course_id_required.erb", api, resource, resource_api, operation, parameters, nil, nil).render
            end

            if operation["method"].casecmp("GET") == 0
              js_graphql_queries << CanvasApi::Render.new("./templates/js_graphql_query.erb", api, resource, resource_api, operation, parameters, nil, nil).render

              # One file per Canvas graphql resolver
              canvas_graphql_resolver_renderer = CanvasApi::Render.new("./templates/rb_graphql_resolver.erb", api, resource, resource_api, operation, parameters, nil, nil)
              canvas_graphql_resolver_renderer.save("#{project_root}/lib/lms/graphql/resolvers/canvas/#{canvas_graphql_resolver_renderer.nickname}.rb")
              rb_graphql_fields << CanvasApi::Render.new("./templates/rb_graphql_field.erb", api, resource, resource_api, operation, parameters, nil, nil).render
            else
              js_graphql_mutations << CanvasApi::Render.new("./templates/js_graphql_mutation.erb", api, resource, resource_api, operation, parameters, nil, nil).render

              rb_graphql_mutation_renderer = CanvasApi::Render.new("./templates/rb_graphql_mutation.erb", api, resource, resource_api, operation, parameters, nil, nil)
              rb_graphql_mutation_renderer.save("#{project_root}/lib/lms/graphql/mutations/canvas/#{rb_graphql_mutation_renderer.nickname}.rb")
              rb_graphql_mutations << CanvasApi::Render.new("./templates/rb_graphql_mutation_include.erb", api, resource, resource_api, operation, parameters, nil, nil).render
            end

          end
        end
        resource["models"].map do |_name, model|
          if model["properties"] # Don't generate models without properties
            models << CanvasApi::Render.new("./templates/js_graphql_model.erb", api, resource, nil, nil, nil, nil, model).render
          end

          # Generate one file for each Canvas graphql type
          canvas_graphql_renderer = CanvasApi::Render.new("./templates/rb_graphql_model.erb", api, resource, nil, nil, nil, nil, model)
          canvas_graphql_renderer.save("#{project_root}/lib/lms/graphql/types/canvas/#{model['id'].underscore.singularize}.rb")
        end

        # Generate one file of constants for every LMS API
        constants_renderer = CanvasApi::Render.new("./templates/constants.erb", api, resource, nil, nil, nil, constants, nil)
        constants_renderer.save("#{client_app_path}/#{constants_renderer.name}.js")
      end

      CanvasApi::Render.new("./templates/rb_urls.erb", nil, nil, nil, nil, nil, lms_urls_rb, nil).save("#{project_root}/lib/lms/canvas_urls.rb")
      CanvasApi::Render.new("./templates/js_urls.erb", nil, nil, nil, nil, nil, lms_urls_js, nil).save("#{server_app_path}/lib/canvas/urls.js")
      CanvasApi::Render.new("./templates/ex_urls.erb", nil, nil, nil, nil, nil, lms_urls_ex, nil).save("#{elixir_app_path}/lib/canvas/actions.ex")
      CanvasApi::Render.new("./templates/course_ids_required.erb", nil, nil, nil, nil, nil, course_ids_required_rb, nil).save("#{project_root}/lib/lms/course_ids_required.rb")

      # GraphQL Javascript - still not complete
      CanvasApi::Render.new("./templates/js_graphql_types.erb", nil, nil, nil, nil, nil, models.compact, nil).save("#{server_app_path}/lib/canvas/graphql_types.js")
      CanvasApi::Render.new("./templates/js_graphql_queries.erb", nil, nil, nil, nil, nil, js_graphql_queries, nil).save("#{server_app_path}/lib/canvas/graphql_queries.js")
      CanvasApi::Render.new("./templates/js_graphql_mutations.erb", nil, nil, nil, nil, nil, js_graphql_mutations, nil).save("#{server_app_path}/lib/canvas/graphql_mutations.js")

      # GraphQL Ruby
      CanvasApi::Render.new("./templates/rb_graphql_root_query.erb", nil, nil, nil, nil, nil, rb_graphql_fields, nil).save("#{project_root}/lib/lms/graphql/types/canvas/query_type.rb")
      CanvasApi::Render.new("./templates/rb_graphql_mutations.erb", nil, nil, nil, nil, nil, rb_graphql_mutations, nil).save("#{project_root}/lib/lms/graphql/mutations/canvas/mutations.rb")
    end

  end

end
