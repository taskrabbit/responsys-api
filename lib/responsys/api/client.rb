require "responsys/configuration"
require "savon"
require "responsys/helper"
require "responsys/api/all"
require "responsys/api/object/all"
require "singleton"

module Responsys
  module Api
    class Client
      include Singleton
      include Responsys::Api::All

      attr_accessor :credentials, :client, :session_id, :jsession_id, :header

      def initialize
        settings = Responsys.configuration.settings
        @credentials = {
          username: settings[:username],
          password: settings[:password]
        }

        ssl_version = settings[:ssl_version] || :TLSv1

        if settings[:debug]
          @client = Savon.client(wsdl: settings[:wsdl], element_form_default: :qualified, ssl_version: ssl_version, log_level: :debug, log: true, pretty_print_xml: true)
        else
          @client = Savon.client(wsdl: settings[:wsdl], element_form_default: :qualified, ssl_version: ssl_version)
        end

        login
      end

      def api_method(action, message = nil, response_type = :hash)
        begin
          response = run_with_credentials(action, message, jsession_id, header)

          case response_type
          when :result
            Responsys::Helper.format_response_result(response, action)
          when :hash
            Responsys::Helper.format_response_hash(response, action)
          end

        rescue Exception => e
          error_response = Responsys::Helper.format_response_with_errors(e)

          if error_response[:error][:code] == "INVALID_SESSION_ID"
            login
            api_method(action, message, response_type)
          else
            error_response
          end
        end
      end

      def available_operations
        @client.operations
      end

      private

      def run(method, message)
        @client.call(method.to_sym, message: message)
      end

      def run_with_credentials(method, message, cookie, header)
        @client.call(method.to_sym, message: message, cookies: cookie, soap_header: header)
      end
    end
  end
end