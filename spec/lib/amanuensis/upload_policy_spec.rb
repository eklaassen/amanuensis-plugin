# frozen_string_literal: true

require "rails_helper"

RSpec.describe Amanuensis::UploadPolicy do
  describe ".extension_of" do
    it "takes the last segment, lowercased" do
      expect(described_class.extension_of("Talk.MP3")).to eq("mp3")
    end

    it "takes the last segment of a double extension" do
      # `payload.mp3.exe` is an exe. Reading the first extension would allow it.
      expect(described_class.extension_of("payload.mp3.exe")).to eq("exe")
    end

    it "returns empty for a name with no extension" do
      expect(described_class.extension_of("recording")).to eq("")
    end
  end

  describe ".allowed_extension?" do
    it "accepts audio formats" do
      %w[talk.mp3 talk.m4a talk.wav talk.flac talk.ogg].each do |name|
        expect(described_class.allowed_extension?(name)).to eq(true), name
      end
    end

    it "rejects documents, which have no place in a transcription pipeline" do
      %w[notes.pdf notes.docx notes.txt notes.md notes.json].each do |name|
        expect(described_class.allowed_extension?(name)).to eq(false), name
      end
    end

    it "rejects an executable hiding behind a double extension" do
      expect(described_class.allowed_extension?("payload.mp3.exe")).to eq(false)
    end
  end

  describe ".sanitize_filename" do
    it "strips path separators" do
      expect(described_class.sanitize_filename("../../etc/passwd.mp3")).not_to include("/")
    end

    it "strips bidi override characters" do
      # Renders as `annexe3pm.png` in most UIs while ending in .mp3 --
      # the display name and the real extension disagree.
      sanitized = described_class.sanitize_filename("annexe‮gnp.mp3")
      expect(sanitized).to eq("annexegnp.mp3")
    end

    it "caps length" do
      expect(described_class.sanitize_filename("#{"a" * 400}.mp3").length).to be <=
        described_class::MAX_FILENAME_LENGTH
    end
  end

  describe ".validate!" do
    it "passes a valid audio file" do
      expect {
        described_class.validate!(filename: "talk.mp3", size_bytes: 1024)
      }.not_to raise_error
    end

    it "rejects a blank filename" do
      expect { described_class.validate!(filename: "", size_bytes: 1024) }.to raise_error(
        described_class::Rejected,
      )
    end

    it "rejects a disallowed extension" do
      expect { described_class.validate!(filename: "notes.pdf", size_bytes: 1024) }.to raise_error(
        described_class::Rejected,
        /not allowed/,
      )
    end

    it "rejects a zero-byte file" do
      expect { described_class.validate!(filename: "talk.mp3", size_bytes: 0) }.to raise_error(
        described_class::Rejected,
      )
    end

    it "rejects a file over the cap" do
      expect {
        described_class.validate!(filename: "talk.mp3", size_bytes: described_class::MAX_BYTES + 1)
      }.to raise_error(described_class::Rejected, /too large/)
    end

    it "accepts a file exactly at the cap" do
      expect {
        described_class.validate!(filename: "talk.mp3", size_bytes: described_class::MAX_BYTES)
      }.not_to raise_error
    end
  end
end
