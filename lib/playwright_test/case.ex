defmodule PlaywrightTest.Case do
  defmacro __using__(_) do
    quote do
      import Playwright

      alias Playwright.ChannelOwner.BrowserContext
      alias Playwright.ChannelOwner.BrowserType
      alias Playwright.ChannelOwner.Page
      alias Playwright.Test.Support.AssetsServer

      setup_all do
        # {connection, browser} = Playwright.connect("ws://localhost:3000/playwright")
        {connection, browser} = launch()
        server = AssetsServer.start(nil, nil)

        [
          connection: connection,
          browser: browser,
          server: server
        ]
      end
    end
  end

  # API
  # ---------------------------------------------------------------------------

  defstruct(connection: nil, parent: nil, type: nil, guid: nil, initializer: nil)

  def playwright do
  end
end
