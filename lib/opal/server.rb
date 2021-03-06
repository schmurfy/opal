require 'erb'

module Opal
  class Environment < ::Sprockets::Environment
    def initialize *args
      super
      Opal.paths.each { |p| append_path p }
    end
  end

  class Server

    attr_accessor :debug, :index_path, :main, :public_dir, :sprockets

    def initialize debug = true
      @public_dir = '.'
      @sprockets  = Environment.new
      @debug      = debug

      yield self if block_given?
      create_app
    end

    def append_path path
      @sprockets.append_path path
    end

    def create_app
      server, sprockets = self, @sprockets

      @app = Rack::Builder.app do
        map('/assets') { run sprockets }
        use Index, server
        run Rack::Directory.new(server.public_dir)
      end
    end

    def call(env)
      @app.call env
    end

    class Index

      def initialize(app, server)
        @app = app
        @server = server
        @index_path = server.index_path
      end

      def call(env)
        if %w[/ /index.html].include? env['PATH_INFO']
          [200, { 'Content-Type' => 'text/html' }, [html]]
        else
          @app.call env
        end
      end

      # Returns the html content for the root path. Supports ERB
      def html
        source = if @index_path
          raise "index does not exist: #{@index_path}" unless File.exist?(@index_path)
          File.read @index_path
        elsif File.exist? 'index.html'
          File.read 'index.html'
        elsif File.exist? 'index.html.erb'
          File.read 'index.html.erb'
        else
          SOURCE
        end

        ::ERB.new(source).result binding
      end

      def javascript_include_tag source
        if @server.debug
          assets = @server.sprockets[source].to_a

          raise "Cannot find asset: #{source}" if assets.empty?

          scripts = assets.map do |a|
            %Q{<script src="/assets/#{ a.logical_path }?body=1"></script>}
          end

          scripts.join "\n"
        else
          "<script src=\"/assets/#{source}.js\"></script>"
        end
      end

      SOURCE = <<-HTML
  <!DOCTYPE html>
  <html>
  <head>
    <title>Opal Server</title>
  </head>
  <body>
    <%= javascript_include_tag @server.main %>
  </body>
  </html>
      HTML
    end
  end
end
