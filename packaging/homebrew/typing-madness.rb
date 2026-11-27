# Homebrew cask for Typing Madness. It lives in the tomasrasymas/homebrew-tap
# repository as Casks/typing-madness.rb; this copy is the source of truth.
# scripts/release.sh fills in `version` and `sha256` for each release.
cask "typing-madness" do
  version "0.1.0"
  sha256 "26d5918426ee02ee6e946f95009a21fedafc6855526121d186472f08321cb1ca"

  url "https://github.com/tomasrasymas/mac-typing-madness-meter/releases/download/v#{version}/Typing-Madness-#{version}.zip"
  name "Typing Madness"
  desc "Menu-bar app that turns typing in any app into a game"
  homepage "https://github.com/tomasrasymas/mac-typing-madness-meter"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :ventura

  app "Typing Madness.app"

  uninstall quit: "dev.typingmadness.app"

  zap trash: [
    "~/Library/Application Support/TypingMadness",
    "~/Library/Preferences/dev.typingmadness.app.plist",
  ]

  caveats do
    unsigned_accessibility
  end
end
