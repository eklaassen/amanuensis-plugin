# frozen_string_literal: true

require 'socket'

module Amanuensis
  # A real, minimal HTTP server for system specs to point a stubbed
  # `upload_url` at. WebMock patches Ruby's Net::HTTP, which only covers the
  # Rails process's own outgoing calls (the presign/complete requests to
  # `amanuensis.example.com`) -- the actual PUT the browser makes to
  # `upload_url` happens in the browser process and is real, unmockable
  # network traffic. This exists so that PUT lands somewhere and gets a
  # clean 2xx back, deliberately not exercising SigV4 or any signature at
  # all -- that's workstream B's job (amanuensis's real-MinIO integration
  # test), not this one's.
  #
  # response_delay lets a system spec catch the UI mid-upload (busy=true,
  # the onbeforeunload guard armed) before the PUT completes.
  class TrivialPutSink
    def initialize(response_delay: 0)
      @response_delay = response_delay

      # System specs launch Chromium with --host-resolver-rules blocking
      # EVERY hostname except a short excluded list (spec/support/system/
      # driver.rb's "MAP * ~NOTFOUND" catch-all, deliberately preventing
      # system specs from ever reaching the real network) -- "localhost" is
      # excluded, a bare IP literal like 127.0.0.1 is not. In CI, "localhost"
      # is additionally force-mapped to [::1] (IPv6), not 127.0.0.1 -- so
      # this binds both families on the same port rather than guessing which
      # one "localhost" actually resolves to wherever this runs.
      @servers = [TCPServer.new('127.0.0.1', 0)]
      port = @servers.first.addr[1]
      begin
        @servers << TCPServer.new('::1', port)
      rescue Errno::EADDRINUSE, Errno::EADDRNOTAVAIL, SocketError
        nil # No IPv6 loopback on this host at all -- IPv4 alone still covers plain `localhost` resolution
      end

      @threads = @servers.map { |server| Thread.new { serve(server) } }
    end

    def url(path = '/sink')
      "http://localhost:#{@servers.first.addr[1]}#{path}"
    end

    def stop
      @threads.each(&:kill)
      @threads.each(&:join)
      @servers.each(&:close)
    end

    private

    def serve(server)
      loop do
        client = server.accept
        begin
          handle(client)
        ensure
          client.close
        end
      end
    rescue IOError, Errno::EBADF
      # server.close (from #stop, on the main thread) unblocks the pending
      # #accept in here with exactly this -- expected shutdown, not a bug.
      nil
    end

    CORS_HEADERS =
      "Access-Control-Allow-Origin: *\r\n" \
        "Access-Control-Allow-Methods: PUT, OPTIONS\r\n" \
        "Access-Control-Allow-Headers: Content-Type\r\n"

    def handle(client)
      request_line = client.gets
      return unless request_line

      method = request_line.split(' ', 2).first

      headers = {}
      while (line = client.gets) && line != "\r\n"
        key, value = line.split(':', 2)
        headers[key.strip.downcase] = value.strip if key && value
      end

      content_length = headers['content-length'].to_i
      client.read(content_length) if content_length.positive?

      # A cross-origin PUT with a custom Content-Type header (this route
      # deliberately sends one -- see amanuensis-upload-new.js's putFile)
      # isn't a CORS-simple request, so the browser sends an OPTIONS
      # preflight first. Real S3-compatible storage answers that with a
      # CORS policy; this sink has to too, or the browser blocks the actual
      # PUT before it ever leaves -- surfacing as a generic XHR network
      # error with no more specific signal than that.
      if method == 'OPTIONS'
        client.write("HTTP/1.1 204 No Content\r\n#{CORS_HEADERS}Content-Length: 0\r\nConnection: close\r\n\r\n")
        return
      end

      sleep @response_delay if @response_delay.positive?

      client.write("HTTP/1.1 200 OK\r\n#{CORS_HEADERS}Content-Length: 0\r\nConnection: close\r\n\r\n")
    end
  end
end
