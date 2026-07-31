# frozen_string_literal: true

module Amanuensis
  # The pipeline's stage order and vocabulary. Duplicated by hand from
  # STAGE_ORDER in the amanuensis API repo's src/workers/pipeline.ts --
  # there's no shared package between the two repos/languages, so keep this
  # in sync if the pipeline's stages ever change there.
  module PipelineStages
    ORDER = %w[pending downloading transcribing summarizing vaulting archiving analyzing].freeze

    # The subset with a dedicated history page (StagesController). The other
    # four (pending/downloading/vaulting/archiving) are plumbing -- nobody
    # audits "we copied a file to S3" -- and their evidence in stage_runs
    # carries no useful timestamp anyway. The API still accepts any ORDER
    # value for /v1/plugin/stages/:stage/runs; this is a nav/UI restriction,
    # not a server-side one.
    OBSERVABLE = %w[transcribing summarizing analyzing].freeze
  end
end
