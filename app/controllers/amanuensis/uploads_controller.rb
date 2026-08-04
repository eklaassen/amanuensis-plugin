# frozen_string_literal: true

module Amanuensis
  # The upload page itself. Writers only -- the JSON endpoints in
  # UploadsApiController enforce the same gate independently, since this page
  # rendering is not what authorizes anything.
  class UploadsController < ApplicationController
    before_action :ensure_writer

    def new
      @max_bytes = UploadPolicy::MAX_BYTES
      @allowed_extensions = UploadPolicy::ALLOWED_EXTENSIONS
      render layout: 'amanuensis'
    end
  end
end
