defmodule Playwright.LocatorTest do
  use Playwright.TestCase

  alias Playwright.{ElementHandle, Locator, Page}
  alias Playwright.Runner.Channel

  describe "Locator.all_inner_texts/1" do
    test "...", %{page: page} do
      Page.set_content(page, "<div>A</div><div>B</div><div>C</div>")

      texts =
        Page.locator(page, "div")
        |> Locator.all_inner_texts()

      assert {:ok, ["A", "B", "C"]} = texts
    end
  end

  describe "Locator.all_text_contents/1" do
    test "...", %{page: page} do
      Page.set_content(page, "<div>A</div><div>B</div><div>C</div>")

      texts =
        Page.locator(page, "div")
        |> Locator.all_text_contents()

      assert {:ok, ["A", "B", "C"]} = texts
    end
  end

  describe "Locator.bounding_box/2" do
    test "returns position and dimension", %{assets: assets, page: page} do
      locator = Page.locator(page, ".box:nth-of-type(13)")
      page |> Page.set_viewport_size(%{width: 500, height: 500})
      page |> Page.goto(assets.prefix <> "/grid.html")

      {:ok, bounds} = Locator.bounding_box(locator)
      assert bounds == %{x: 100, y: 50, width: 50, height: 50}
    end
  end

  describe "Locator.check/2" do
    setup(%{assets: assets, page: page}) do
      options = %{timeout: 200}

      page |> Page.goto(assets.prefix <> "/empty.html")
      page |> Page.set_content("<input id='checkbox' type='checkbox'/>")

      [options: options]
    end

    test "returns :ok on a successful 'check'", %{options: options, page: page} do
      frame = Page.main_frame(page)

      locator = Locator.new(frame, "input#checkbox")
      assert :ok = Locator.check(locator, options)
    end

    test "returns a timeout error when unable to 'check'", %{options: options, page: page} do
      frame = Page.main_frame(page)

      locator = Locator.new(frame, "input#bogus")
      assert {:error, %Channel.Error{message: "Timeout 200ms exceeded."}} = Locator.check(locator, options)
    end
  end

  describe "Locator.click/2" do
    setup(%{assets: assets, page: page}) do
      options = %{timeout: 200}

      page |> Page.goto(assets.prefix <> "/empty.html")
      page |> Page.set_content("<a id='link' target=_blank rel=noopener href='/one-style.html'>yo</a>")

      [options: options]
    end

    test "returns :ok on a successful click", %{options: options, page: page} do
      frame = Page.main_frame(page)

      locator = Locator.new(frame, "a#link")
      assert :ok = Locator.click(locator, options)
    end

    test "returns a timeout error when unable to click", %{options: options, page: page} do
      frame = Page.main_frame(page)

      locator = Locator.new(frame, "a#bogus")
      assert {:error, %Channel.Error{message: "Timeout 200ms exceeded."}} = Locator.click(locator, options)
    end
  end

  describe "Locator.dispatch_event/4" do
    test "with a 'click' event", %{assets: assets, page: page} do
      locator = Page.locator(page, "button")
      page |> Page.goto(assets.prefix <> "/input/button.html")

      Locator.dispatch_event(locator, :click)
      assert Page.evaluate(page, "result") == "Clicked"
    end
  end

  describe "Locator.element_handle/2" do
    test "passed as `arg` to a nested Locator", %{assets: assets, page: page} do
      page |> Page.goto(assets.prefix <> "/playground.html")

      page
      |> Page.set_content("""
      <html>
      <body>
        <div class="outer">
          <div class="inner">A</div>
        </div>
      </body>
      </html>
      """)

      html = Page.locator(page, "html")
      outer = Locator.locator(html, ".outer")
      inner = Locator.locator(outer, ".inner")

      handle = Locator.element_handle(inner)
      assert Page.evaluate(page, "e => e.textContent", handle) == "A"
    end
  end

  describe "Locator.element_handles/1" do
    test "returns a collection of handles", %{page: page} do
      page
      |> Page.set_content("""
      <html>
      <body>
        <div>A</div>
        <div>B</div>
      </body>
      </html>
      """)

      html = Page.locator(page, "html")
      divs = Locator.locator(html, "div")

      {:ok, handles} = Locator.element_handles(divs)

      assert [
               %ElementHandle{preview: "JSHandle@<div>A</div>"},
               %ElementHandle{preview: "JSHandle@<div>B</div>"}
             ] = handles
    end

    test "returns an empty list when there are no matches", %{page: page} do
      page
      |> Page.set_content("""
      <html>
      <body>
        <div>A</div>
        <div>B</div>
      </body>
      </html>
      """)

      html = Page.locator(page, "html")
      para = Locator.locator(html, "p")

      {:ok, handles} = Locator.element_handles(para)

      assert [] = handles
      assert Enum.empty?(handles)
    end
  end

  describe "Locator.evaluate/4" do
    test "called with expression", %{page: page} do
      element = Locator.new(page, "input")
      Page.set_content(page, "<input type='checkbox' checked><div>Not a checkbox</div>")

      {:ok, checked} = Locator.is_checked(element)
      assert checked

      Locator.evaluate(element, "function (input) { return input.checked = false; }")

      {:ok, checked} = Locator.is_checked(element)
      refute checked
    end

    test "called with expression and an `ElementHandle` arg", %{page: page} do
      selector = "input"
      locator = Locator.new(page, selector)

      Page.set_content(page, "<input type='checkbox' checked><div>Not a checkbox</div>")

      handle = Page.wait_for_selector(page, selector)

      {:ok, checked} = Locator.is_checked(locator)
      assert checked

      Locator.evaluate(locator, "function (input) { return input.checked = false; }", handle)

      {:ok, checked} = Locator.is_checked(locator)
      refute checked
    end

    test "retrieves a matching node", %{page: page} do
      locator = Page.locator(page, ".tweet .like")

      page
      |> Page.set_content("""
        <html>
        <body>
          <div class="tweet">
            <div class="like">100</div>
            <div class="retweets">10</div>
          </div>
        </body>
        </html>
      """)

      case Locator.evaluate(locator, "node => node.innerText") do
        "100" ->
          assert true

        {:error, :timeout} ->
          log_element_handle_error()
      end
    end

    test "accepts `param: arg` for expression evaluation", %{page: page} do
      locator = Page.locator(page, ".counter")

      page
      |> Page.set_content("""
        <html>
        <body>
          <div class="counter">100</div>
        </body>
        </html>
      """)

      assert Locator.evaluate(locator, "(node, number) => parseInt(node.innerText) - number", 58) === 42
    end

    test "accepts `option: timeout` for expression evaluation", %{page: page} do
      locator = Page.locator(page, ".missing")
      options = %{timeout: 500}
      errored = {:error, %Channel.Error{message: "Timeout 500ms exceeded."}}

      page
      |> Page.set_content("""
        <html>
        <body>
          <div class="counter">100</div>
        </body>
        </html>
      """)

      assert ^errored = Locator.evaluate(locator, "(node, arg) => arg", "a", options)
    end

    test "accepts `option: timeout` without a `param: arg`", %{page: page} do
      locator = Page.locator(page, ".missing")
      options = %{timeout: 500}
      errored = {:error, %Channel.Error{message: "Timeout 500ms exceeded."}}

      page
      |> Page.set_content("""
        <html>
        <body>
          <div class="counter">100</div>
        </body>
        </html>
      """)

      assert ^errored = Locator.evaluate(locator, "(node) => node", options)
    end

    test "retrieves content from a subtree match", %{page: page} do
      locator = Page.locator(page, "#myId .a")

      :ok =
        Page.set_content(page, """
          <div class="a">other content</div>
          <div id="myId">
            <div class="a">desired content</div>
          </div>
        """)

      case Locator.evaluate(locator, "node => node.innerText") do
        "desired content" ->
          assert true

        {:error, :timeout} ->
          log_element_handle_error()
      end
    end
  end

  describe "Locator.evaluate_all/3" do
    test "evaluates the expression on all matching elements", %{page: page} do
      locator = Page.locator(page, "#myId .a")

      page
      |> Page.set_content("""
        <div class="a">other content</div>
        <div id="myId">
          <div class="a">one</div>
          <div class="a">two</div>
        </div>
      """)

      assert {:ok, ["one", "two"]} = Locator.evaluate_all(locator, "nodes => nodes.map(n => n.innerText)")
    end

    test "does not throw in case of a selector 'miss'", %{page: page} do
      locator = Page.locator(page, "#myId .a")

      page
      |> Page.set_content("""
        <div class="a">other content</div>
        <div id="myId"></div>
      """)

      assert {:ok, 0} = Locator.evaluate_all(locator, "nodes => nodes.length")
    end
  end

  describe "Locator.evaluate_handle/3" do
    test "returns a JSHandle", %{assets: assets, page: page} do
      Page.goto(page, assets.dom)

      inner = Page.locator(page, "#inner")
      {:ok, text} = Locator.evaluate_handle(inner, "e => e.firstChild")

      assert ElementHandle.string(text) == ~s|JSHandle@#text=Text,↵more text|
    end
  end

  describe "Locator.fill/3" do
    test "filling a textarea element", %{assets: assets, page: page} do
      locator = Page.locator(page, "input")
      page |> Page.goto(assets.prefix <> "/input/textarea.html")

      Locator.fill(locator, "some value")
      assert Page.evaluate(page, "result") == "some value"
    end
  end

  describe "Locator.first/1 and .last/1, with .count/1" do
    test "return nested/scoped Locators", %{page: page} do
      page
      |> Page.set_content("""
      <section>
          <div><p>A</p></div>
          <div><p>A</p><p>A</p></div>
          <div><p>A</p><p>A</p><p>A</p></div>
      </section>
      """)

      assert {:ok, 6} =
               Page.locator(page, "div >> p")
               |> Locator.count()

      assert {:ok, 6} =
               Page.locator(page, "div")
               |> Locator.locator("p")
               |> Locator.count()

      assert {:ok, 1} =
               Page.locator(page, "div")
               |> Locator.first()
               |> Locator.locator("p")
               |> Locator.count()

      assert {:ok, 3} =
               Page.locator(page, "div")
               |> Locator.last()
               |> Locator.locator("p")
               |> Locator.count()
    end
  end

  describe "Locator.focus/2" do
    test "focuses/activates an element", %{assets: assets, page: page} do
      button = Page.locator(page, "button")
      page |> Page.goto(assets.prefix <> "/input/button.html")

      assert Locator.evaluate(button, "(button) => document.activeElement === button") === false
      Locator.focus(button)
      assert Locator.evaluate(button, "(button) => document.activeElement === button") === true
    end
  end

  describe "Locator.get_attribute/3" do
    test "...", %{assets: assets, page: page} do
      locator = Page.locator(page, "#outer")

      Page.goto(page, assets.dom)

      assert {:ok, "value"} = Locator.get_attribute(locator, "name")
      assert {:ok, nil} = Locator.get_attribute(locator, "bogus")
    end
  end

  describe "Locator.hover/2" do
    test "puts the matching element into :hover state", %{assets: assets, page: page} do
      locator = Page.locator(page, "#button-6")
      page |> Page.goto(assets.prefix <> "/input/scrollable.html")

      Locator.hover(locator)
      assert Page.evaluate(page, "document.querySelector('button:hover').id") == "button-6"
    end
  end

  describe "Locator.inner_html/2" do
    test "...", %{assets: assets, page: page} do
      content = ~s|<div id="inner">Text,\nmore text</div>|
      locator = Page.locator(page, "#outer")

      Page.goto(page, assets.dom)
      assert {:ok, ^content} = Locator.inner_html(locator)
    end
  end

  describe "Locator.inner_text/2" do
    test "...", %{assets: assets, page: page} do
      content = "Text, more text"
      locator = Page.locator(page, "#inner")

      Page.goto(page, assets.dom)
      assert {:ok, ^content} = Locator.inner_text(locator)
    end
  end

  describe "Locator.input_value/2" do
    test "...", %{assets: assets, page: page} do
      locator = Page.locator(page, "#input")

      Page.goto(page, assets.dom)
      Page.fill(page, "#input", "input value")

      assert {:ok, "input value"} = Locator.input_value(locator)
    end
  end

  describe "Locator.is_checked/1" do
    test "...", %{page: page} do
      locator = Page.locator(page, "input")

      Page.set_content(page, """
        <input type='checkbox' checked>
        <div>Not a checkbox</div>
      """)

      assert {:ok, true} = Locator.is_checked(locator)

      assert Locator.evaluate(locator, "input => input.checked = false") === false
      assert {:ok, false} = Locator.is_checked(locator)
    end
  end

  describe "Locator.is_editable/1" do
    test "...", %{page: page} do
      Page.set_content(page, """
        <input id=input1 disabled>
        <textarea readonly></textarea>
        <input id=input2>
      """)

      # ??? (why not just the attribute, as above?)
      # Page.eval_on_selector(page, "textarea", "t => t.readOnly = true")

      locator = Page.locator(page, "#input1")
      assert {:ok, false} = Locator.is_editable(locator)

      locator = Page.locator(page, "#input2")
      assert {:ok, true} = Locator.is_editable(locator)

      locator = Page.locator(page, "textarea")
      assert {:ok, false} = Locator.is_editable(locator)
    end
  end

  describe "Locator.is_enabled/1 and is_disabled/1" do
    test "...", %{page: page} do
      Page.set_content(page, """
        <button disabled>button1</button>
        <button>button2</button>
        <div>div</div>
      """)

      locator = Page.locator(page, "div")
      assert {:ok, true} = Locator.is_enabled(locator)
      assert {:ok, false} = Locator.is_disabled(locator)

      locator = Page.locator(page, ":text('button1')")
      assert {:ok, false} = Locator.is_enabled(locator)
      assert {:ok, true} = Locator.is_disabled(locator)

      locator = Page.locator(page, ":text('button2')")
      assert {:ok, true} = Locator.is_enabled(locator)
      assert {:ok, false} = Locator.is_disabled(locator)
    end
  end

  describe "Locator.is_visible/1 and is_hidden/1" do
    test "...", %{page: page} do
      Page.set_content(page, "<div>Hi</div><span></span>")

      locator = Page.locator(page, "div")
      assert {:ok, true} = Locator.is_visible(locator)
      assert {:ok, false} = Locator.is_hidden(locator)

      locator = Page.locator(page, "span")
      assert {:ok, false} = Locator.is_visible(locator)
      assert {:ok, true} = Locator.is_hidden(locator)
    end
  end

  describe "Locator.locator/4" do
    test "returns values with previews", %{assets: assets, page: page} do
      Page.goto(page, assets.dom)

      outer = Page.locator(page, "#outer")
      inner = Locator.locator(outer, "#inner")
      check = Locator.locator(inner, "#check")

      assert Locator.string(outer) == ~s|Locator@#outer|
      assert Locator.string(inner) == ~s|Locator@#outer >> #inner|
      assert Locator.string(check) == ~s|Locator@#outer >> #inner >> #check|
    end
  end

  describe "Locator.nth/2" do
    test "return nested/scoped Locators", %{page: page} do
      page
      |> Page.set_content("""
      <section>
          <div><p>A</p></div>
          <div><p>A</p><p>A</p></div>
          <div><p>A</p><p>A</p><p>A</p></div>
      </section>
      """)

      assert {:ok, 1} =
               Page.locator(page, "div >> p")
               |> Locator.nth(0)
               |> Locator.count()

      assert {:ok, 2} =
               Page.locator(page, "div")
               |> Locator.nth(1)
               |> Locator.locator("p")
               |> Locator.count()

      assert {:ok, 3} =
               Page.locator(page, "div")
               |> Locator.nth(2)
               |> Locator.locator("p")
               |> Locator.count()
    end
  end

  describe "Locator.press/2" do
    test "focuses an element and 'presses' a key within it", %{page: page} do
      locator = Page.locator(page, "input")
      page |> Page.set_content("<input type='text' />")

      Locator.press(locator, "x")
      assert {:ok, %{s: "x"}} = Page.eval_on_selector(page, "input", "(input) => input.value")
    end
  end

  describe "Locator.screenshot/2" do
    test "captures an image of the element", %{assets: assets, page: page} do
      fixture = File.read!("test/support/fixtures/screenshot-element-bounding-box-chromium.png")
      locator = Page.locator(page, ".box:nth-of-type(3)")

      page |> Page.set_viewport_size(%{width: 500, height: 500})
      page |> Page.goto(assets.prefix <> "/grid.html")

      {:ok, data} = Locator.screenshot(locator)
      assert Base.encode64(data) == Base.encode64(fixture)
    end
  end

  describe "Locator.scroll_into_view/2" do
    test "scrolls the element into view, if needed", %{assets: assets, page: page} do
      page |> Page.goto(assets.prefix <> "/offscreenbuttons.html")

      Enum.each(0..10, fn i ->
        locator = Page.locator(page, "#btn#{i}")
        expression = "(btn) => btn.getBoundingClientRect().right - window.innerWidth"

        initial = Locator.evaluate(locator, expression)
        assert initial == 10 * i

        Locator.scroll_into_view(locator)

        updated = Locator.evaluate(locator, expression)
        assert updated <= 0

        Page.evaluate(page, "() => window.scrollTo(0, 0)")
      end)
    end
  end

  describe "Locator.select_option/2" do
    test "single selection matching value", %{assets: assets, page: page} do
      locator = Page.locator(page, "select")
      page |> Page.goto(assets.prefix <> "/input/select.html")

      Locator.select_option(locator, "blue")
      assert Page.evaluate(page, "result.onChange") == ["blue"]
      assert Page.evaluate(page, "result.onInput") == ["blue"]
    end
  end

  describe "Locator.select_text/2" do
    test "within a <textarea> element", %{assets: assets, page: page} do
      locator = Page.locator(page, "textarea")
      page |> Page.goto(assets.prefix <> "/input/textarea.html")

      Locator.evaluate(locator, "(textarea) => textarea.value = 'some value'")
      Locator.select_text(locator)

      assert "some value" = Page.evaluate(page, "window.getSelection().toString()")
    end
  end

  describe "Locator.set_checked/2" do
    test "sets the checked value on a checkbox", %{page: page} do
      locator = Page.locator(page, "input")
      page |> Page.set_content("<input id='checkbox' type='checkbox'></input>")

      Locator.set_checked(locator, true)
      assert Page.evaluate(page, "checkbox.checked") == true

      Locator.set_checked(locator, false)
      assert Page.evaluate(page, "checkbox.checked") == false
    end
  end

  describe "Locator.set_input_files/3" do
    test "file upload", %{assets: assets, page: page} do
      fixture = "test/support/assets_server/assets/file-to-upload.txt"
      locator = Page.locator(page, "input[type=file]")
      page |> Page.goto(assets.prefix <> "/input/fileupload.html")

      Locator.set_input_files(locator, fixture)
      assert Page.evaluate(page, "e => e.files[0].name", Locator.element_handle(locator)) == "file-to-upload.txt"
    end
  end

  describe "Locator.tap/1" do
    @tag exclude: [:page]
    test "registers 'click' events, when touch is enabled", %{browser: browser} do
      context = Playwright.Browser.new_context(browser, %{has_touch: true})
      page = Playwright.BrowserContext.new_page(context)

      locator = Page.locator(page, "button")
      page |> Page.set_content("<button />")
      page |> Page.evaluate("(btn) => btn.onclick = () => btn.textContent = 'clicked'", Page.q(page, "button"))

      Locator.tap(locator)
      assert {:ok, "clicked"} = Page.text_content(page, "button")
    end
  end

  describe "Locator.text_content/2" do
    test "...", %{assets: assets, page: page} do
      locator = Page.locator(page, "#inner")

      Page.goto(page, assets.dom)
      assert {:ok, "Text,\nmore text"} = Locator.text_content(locator)
    end
  end

  describe "Locator.type/3" do
    test "focuses an element and 'types' each key within it", %{page: page} do
      locator = Page.locator(page, "input")
      page |> Page.set_content("<input type='text' />")

      Locator.type(locator, "hello")
      assert {:ok, %{s: "hello"}} = Page.eval_on_selector(page, "input", "(input) => input.value")
    end
  end

  describe "Locator.uncheck/2" do
    setup(%{assets: assets, page: page}) do
      options = %{timeout: 200}

      page |> Page.goto(assets.prefix <> "/empty.html")
      page |> Page.set_content("<input id='checkbox' type='checkbox' checked/>")

      [options: options]
    end

    test "returns :ok on a successful 'uncheck'", %{options: options, page: page} do
      locator = Page.locator(page, "input#checkbox")
      assert {:ok, true} = Locator.is_checked(locator)

      assert :ok = Locator.uncheck(locator, options)
      assert {:ok, false} = Locator.is_checked(locator)
    end

    test "returns a timeout error when unable to 'uncheck'", %{options: options, page: page} do
      locator = Page.locator(page, "input#bogus")
      assert {:error, %Channel.Error{message: "Timeout 200ms exceeded."}} = Locator.uncheck(locator, options)
    end
  end

  describe "Locator.wait_for/2" do
    setup(%{assets: assets, page: page}) do
      options = %{timeout: 200}

      page |> Page.goto(assets.prefix <> "/empty.html")

      [options: options]
    end

    test "waiting for 'attached'", %{options: options, page: page} do
      frame = Page.main_frame(page)

      locator = Locator.new(frame, "a#link")

      task =
        Task.async(fn ->
          assert :ok = Locator.wait_for(locator, Map.put(options, :state, "attached"))
        end)

      page |> Page.set_content("<a id='link' target=_blank rel=noopener href='/one-style.html'>yo</a>")

      Task.await(task)
    end
  end
end
