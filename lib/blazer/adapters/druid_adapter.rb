module Blazer
  module Adapters
    class DruidAdapter < BaseAdapter
      def run_statement(statement, comment)
        columns = []
        rows = []
        error = nil

        header = {"Content-Type" => "application/json", "Accept" => "application/json"}
        context = {}
        if data_source.timeout
          context = data_source.timeout.to_i * 1000
        end
        data = {
          query: statement,
          context: context
        }

        uri = URI.parse("#{settings["url"]}/druid/v2/sql/")
        http = Net::HTTP.new(uri.host, uri.port)

        begin
          response = JSON.parse(http.post(uri.request_uri, data.to_json, header).body)
          if response.is_a?(Hash)
            error = response["errorMessage"]
            if error.include?("timed out")
              error = Blazer::TIMEOUT_MESSAGE
            end
          else
            columns = response.first.keys || []
            rows = response.map { |r| r.values }
          end
         rescue => e
           error = e.message
         end

        [columns, rows, error]
      end

      def tables
        result = data_source.run_statement("SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA NOT IN ('INFORMATION_SCHEMA') ORDER BY TABLE_NAME")
        result.rows.map(&:first)
      end

      def schema
        result = data_source.run_statement("SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, DATA_TYPE, ORDINAL_POSITION FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA NOT IN ('INFORMATION_SCHEMA') ORDER BY 1, 2")
        result.rows.group_by { |r| [r[0], r[1]] }.map { |k, vs| {schema: k[0], table: k[1], columns: vs.sort_by { |v| v[2] }.map { |v| {name: v[2], data_type: v[3]} }} }
      end

      def preview_statement
        "SELECT * FROM {table} LIMIT 10"
      end
    end
  end
end