require 'sinatra'
require 'controllers/base/base_controller'
require 'cloud_controller/diego/client'
require 'cloud_controller/internal_api'

module VCAP::CloudController
  class StagingCompletionController < RestController::BaseController
    def self.dependencies
      [:stagers]
    end

    # Endpoint does its own (non-standard) auth
    allow_unauthenticated_access

    def initialize(*)
      super
      auth = Rack::Auth::Basic::Request.new(env)
      unless auth.provided? && auth.basic? && auth.credentials == InternalApi.credentials
        raise Errors::ApiError.new_from_details('NotAuthenticated')
      end
    end

    def inject_dependencies(dependencies)
      super
      @stagers = dependencies.fetch(:stagers)
    end

    post '/internal/staging/:staging_guid/completed', :completed

    def completed(staging_guid)
      staging_response = read_body

      app = App.find(guid: Diego::StagingGuid.app_guid(staging_guid))
      raise Errors::ApiError.new_from_details('NotFound') unless app
      raise Errors::ApiError.new_from_details('StagingBackendInvalid') unless app.diego?

      begin
        stagers.stager_for_app(app).staging_complete(staging_guid, staging_response)
      rescue Errors::ApiError => api_err
        raise api_err
      rescue => e
        logger.error('diego.staging.completion-controller-error', error: e)
        raise Errors::ApiError.new_from_details('ServerError')
      end

      [200, '{}']
    end

    private

    attr_reader :stagers

    def read_body
      staging_response = {}
      begin
        payload = body.read
        staging_response = MultiJson.load(payload)
      rescue MultiJson::ParseError => pe
        logger.error('diego.staging.parse-error', payload: payload, error: pe.to_s)
        raise Errors::ApiError.new_from_details('MessageParseError', payload)
      end

      staging_response
    end
  end
end
