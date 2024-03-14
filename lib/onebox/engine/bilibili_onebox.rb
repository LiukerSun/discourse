# frozen_string_literal: true

module Onebox
  module Engine
    class BilibiliOnebox
      include Engine
      include StandardEmbed

      matches_regexp(%r{^https?:\/\/((?:m|www)\.)?bilibili\.com\/video\/\w+\/?})
      requires_iframe_origins "https://player.bilibili.com"
      always_https

      def placeholder_html
        to_html
      end

      def to_html
        <<-HTML
          <iframe
            class="tiktok-onebox"
            src="https://player.bilibili.com/player.html?aid=#{aid}&bvid=#{bvid}&cid=#{cid}&autoplay=0"
            sandbox="allow-popups allow-popups-to-escape-sandbox allow-scripts allow-top-navigation allow-same-origin"
            frameborder="0"
            seamless="seamless"
            scrolling="no"
            style="
              min-width: 323px;
              border: 4px solid #fff;
              border-top: 3px solid #fff;
              background-color: #fff;
              border-radius: 9px;
              "
          ></iframe>
        HTML
      end

      private

      def oembed_data
        @oembed_data = get_oembed
      end

      def aid
        view_url = "https://api.bilibili.com/x/web-interface/view?cid=#{cid}&bvid=#{bvid}"
        @embed_aid_doc ||= Onebox::Oembed.new(Onebox::Helpers.fetch_response(view_url))
        @embed_aid_doc.data[:data][:aid] if @embed_aid_doc.data[:data].present?
      end

      def first_frame
        oembed_data.data[:data][0][:first_frame] if oembed_data.data[:data].present?
      end

      def part
        oembed_data.data[:data][0][:part] if oembed_data.data[:data].present?
      end

      def cid
        oembed_data.data[:data][0][:cid] if oembed_data.data[:data].present?
      end

      def bvid
        args = @url.match(/\/video\/(\w+)/)
        args[1] if args.present? && args.size >= 2
      end

      def get_oembed_url
        return {} if bvid.nil?
        "https://api.bilibili.com/x/player/pagelist?bvid=#{bvid}"
      end
    end
  end
end
